import Foundation
import AVFoundation

internal struct MergedVideoProgress {
    let key: String
    let progress: Float

    func asDictionary() -> [AnyHashable: Any] {
        [
            "key": key,
            "progress": NSNumber(value: progress)
        ]
    }
}

internal struct MergedVideoResults {
    let path: String
    let duration: CGFloat

    func asDictionary() -> [AnyHashable: Any] {
        [
            "uri": "file://\(path)",
            "duration": NSNumber(value: duration)
        ]
    }
}

internal enum MergedVideoError: LocalizedError {
    case invalidMergeOptions
    case missingVideo(fileName: String)
    case missingAudio(fileName: String)
    case couldNotBuildGenerator
    case mergeVideoCancelled
    case mergedFailed(error: Error?)
    case unknownError

    var errorDescription: String? {
        switch self {
        case .invalidMergeOptions:
            return "Options were provided to merge(...), but an option did not match expected types / availability"
        case .missingVideo(let fileName):
            return "Video with name \(fileName) is missing a video track"
        case .missingAudio(let fileName):
            return "Video with name \(fileName) is missing an audio track"
        case .couldNotBuildGenerator:
            return "The video generator could not be built"
        case .mergeVideoCancelled:
            return "The merge operation was cancelled"
        case .mergedFailed(let error):
            return "The merge operation failed due to: \(error?.localizedDescription ?? "unknown error")"
        default:
            return "An unexpected error has occurred"
        }
    }
}

internal struct MergedVideoOptions: Codable {
    // TODO: Add support for optional values within options
    var writeDirectory: String = MergedVideoOptions.applicationDocumentsDirectory()
    var fileName: String = "merged_video"
    var actionKey: String = "video_merge"
    var ignoreSound: Bool = false

    /// Initialises a config object, with the given dictionary payload.
    /// - Parameter rawValue: A dictionary options payload, provided by the JS layer.
    /// - Throws: An error if the options aren't provided, or if typing of the payload is incorrect.
    init(rawValue: [AnyHashable: Any]?) throws {
        guard let data = rawValue else {
            return
        }

        do {
            let decodeableData = try JSONSerialization.data(withJSONObject: data)
            self = try JSONDecoder().decode(MergedVideoOptions.self, from: decodeableData)
        } catch {
            throw MergedVideoError.invalidMergeOptions
        }
    }

    func getWriteDirectory() -> URL {
        return URL(fileURLWithPath: writeDirectory)
    }

    static func applicationDocumentsDirectory() -> String {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory.absoluteString
    }
}

typealias MergedVideosSuccess = (MergedVideoResults) -> Void
typealias MergedVideosFailure = (MergedVideoError) -> Void

internal class MergedVideoGenerator {

    var sendEventCallback: ((String, [AnyHashable: Any]) -> Void)?

    var hasListeners: Bool = false
    private var timers = [String: Timer]()

    private static let timerInvalidationStatuses: [AVAssetExportSession.Status] = [.cancelled, .failed, .completed]

    internal func merge(
        _ fileNames: [String],
        options: [AnyHashable: Any]?,
        onSuccess: @escaping MergedVideosSuccess,
        onFailure: @escaping MergedVideosFailure
    ) {
        do {
            let mergeOptions = try MergedVideoOptions(rawValue: options)

            let mixComposition = AVMutableComposition()

            let videoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)

            var audioTrack: AVMutableCompositionTrack?

            if (!mergeOptions.ignoreSound) {
                audioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            }

            var insertTime: CMTime = CMTime.zero
            var originalTransform = CGAffineTransform()
            var totalDuration: CGFloat = 0

            try fileNames.forEach { fileName in
                let asset = AVAsset(url: URL(fileURLWithPath: fileName))
                let timeRange = CMTimeRangeMake(start: .zero, duration: asset.duration)

                guard let video = asset.tracks(withMediaType: .video).first else {
                    throw MergedVideoError.missingVideo(fileName: fileName)
                }

                try videoTrack?.insertTimeRange(timeRange, of: video, at: insertTime)

                if (!mergeOptions.ignoreSound) {
                    guard let audio = asset.tracks(withMediaType: .audio).first else {
                        throw MergedVideoError.missingAudio(fileName: fileName)
                    }

                    try audioTrack?.insertTimeRange(timeRange, of: audio, at: insertTime)
                }

                insertTime = CMTimeAdd(insertTime, asset.duration)
                totalDuration += CMTimeGetSeconds(asset.duration)

                if let track = asset.tracks.first {
                    originalTransform = track.preferredTransform
                }
            }

            if originalTransform.a > 0 || originalTransform.b > 0 || originalTransform.c > 0 || originalTransform.d > 0 {
                videoTrack?.preferredTransform = originalTransform
            }

            let docPath = mergeOptions.writeDirectory.appending("/\(mergeOptions.fileName).mp4")
            let writeURL = URL(fileURLWithPath: docPath)

            if FileManager.default.fileExists(atPath: docPath) {
                try FileManager.default.removeItem(atPath: docPath)
            }

            guard let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else {
                throw MergedVideoError.couldNotBuildGenerator
            }

            exporter.outputURL = writeURL
            exporter.outputFileType = .mp4

            DispatchQueue.main.async { [weak self] in
                let exportProgressBarTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
                    self?.onTimerFiredFor(timer, exporter: exporter, actionKey: mergeOptions.actionKey)
                }

                RunLoop.current.add(exportProgressBarTimer, forMode: .common)
                self?.timers[mergeOptions.actionKey] = exportProgressBarTimer
            }

            exporter.exportAsynchronously { [weak self] in
                self?.handleUpdate(in: exporter, options: mergeOptions, path: docPath, duration: totalDuration, onSuccess: onSuccess, onFailure: onFailure)
            }
        } catch let error as MergedVideoError {
            onFailure(error)
        } catch {
            onFailure(.unknownError)
        }
    }

    private func handleUpdate(
        in exporter: AVAssetExportSession,
        options: MergedVideoOptions,
        path: String,
        duration: CGFloat,
        onSuccess: MergedVideosSuccess,
        onFailure: MergedVideosFailure
    ) {
        do {
            switch exporter.status {
            case .failed:
                throw MergedVideoError.mergedFailed(error: exporter.error)
            case .cancelled:
                throw MergedVideoError.mergeVideoCancelled
            case .completed:
                onSuccess(
                    MergedVideoResults(
                        path: path,
                        duration: duration
                    )
                )
                break;
            default:
                break;
            }
        } catch let error as MergedVideoError {
            onFailure(error)
        } catch {
            onFailure(.unknownError)
        }
    }

    private func onTimerFiredFor(_ timer: Timer, exporter: AVAssetExportSession, actionKey: String) {
        guard !MergedVideoGenerator.timerInvalidationStatuses.contains(exporter.status) else {
            timer.invalidate()
            timers[actionKey] = nil
            return
        }

        let progress = exporter.progress

        guard progress != 0 else {
            return
        }

        guard progress < 0.99 else {
            timer.invalidate()
            timers[actionKey] = nil
            return
        }

        if (hasListeners) {
            let results = MergedVideoProgress(key: actionKey, progress: progress)
            self.sendEventCallback?(
                "VideoManager-MergeProgress",
                results.asDictionary()
            )
        }
    }
}
