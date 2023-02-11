import Foundation
import AVFoundation

internal struct GetTotalDuration: Codable {
    let duration: Double

    func asDictionary() -> [AnyHashable: Any] {
        [
            "duration": duration
        ]
    }
}

internal enum VideoManagerError: LocalizedError {
    case invalidMergeOptions
    case missingVideo(fileName: String)
    case missingAudio(fileName: String)
    case mergeVideoError(error: String?)
    case mergeVideoCancelled
    case selfNotAvailable
}

internal struct MergeVideoOptions: Codable {
    // TODO: Add support for optional values within options
    var writeDirectory: String = MergeVideoOptions.applicationDocumentsDirectory()
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
            self = try JSONDecoder().decode(MergeVideoOptions.self, from: decodeableData)
        } catch {
            throw VideoManagerError.invalidMergeOptions
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

@objc(RNVideoManager)
class RNVideoManager: RCTEventEmitter {
    var hasListeners: Bool = false

    override class func requiresMainQueueSetup() -> Bool {
        true
    }

    override func supportedEvents() -> [String]! {
        ["VideoManager-MergeProgress"]
    }

    override func startObserving() {
        hasListeners = true
    }

    override func stopObserving() {
        hasListeners = false
    }

    @objc(getTotalDurationFor:resolver:rejecter:)
    func getTotalDurationFor(
        fileName: String,
        resolve: RCTPromiseResolveBlock,
        reject: RCTPromiseRejectBlock
    ) {
        let asset = AVAsset(url: URL(fileURLWithPath: fileName))
        let duration = CMTimeGetSeconds(asset.duration)

        let response = GetTotalDuration(duration: duration)
        resolve(response.asDictionary())
    }

    @objc(merge:options:resolver:rejecter:)
    func merge(
        fileNames: [String],
        options: [AnyHashable: Any]?,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            let mergeOptions: MergeVideoOptions = try MergeVideoOptions(rawValue: options)

            var totalDuration: CGFloat = 0

            let mixComposition = AVMutableComposition()

            let videoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)

            var audioTrack: AVMutableCompositionTrack?

            if (!mergeOptions.ignoreSound) {
                audioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            }

            var insertTime: CMTime = CMTime.zero
            var originalTransform = CGAffineTransform()

            try fileNames.forEach { fileName in
                let asset = AVAsset(url: URL(fileURLWithPath: fileName))
                let timeRange = CMTimeRangeMake(start: .zero, duration: asset.duration)

                guard let video = asset.tracks(withMediaType: .video).first else {
                    throw VideoManagerError.missingVideo(fileName: fileName)
                }

                try videoTrack?.insertTimeRange(timeRange, of: video, at: insertTime)

                if (!mergeOptions.ignoreSound) {
                    guard let audio = asset.tracks(withMediaType: .audio).first else {
                        throw VideoManagerError.missingAudio(fileName: fileName)
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
                throw VideoManagerError.mergeVideoError(error: "Could not build exporter instance")
            }

            exporter.outputURL = writeURL
            exporter.outputFileType = .mp4

            exporter.exportAsynchronously { [weak self] in
                guard let self = self else {
                    reject("event_failure", "an error unknown occurred", nil)
                    return
                }

                self.handleUpdate(in: exporter, options: mergeOptions, path: docPath, duration: totalDuration, resolve: resolve, reject: reject)
            }
        } catch let error as VideoManagerError {
            reject("event_failure", "an error occurred - \(error.localizedDescription)", nil)
        } catch {
            reject("event_failure", "an error unknown occurred", nil)
        }
    }

    private func handleUpdate(
        in exporter: AVAssetExportSession,
        options: MergeVideoOptions,
        path: String,
        duration: CGFloat,
        resolve: RCTPromiseResolveBlock,
        reject: RCTPromiseRejectBlock
    ) {
        do {
            switch exporter.status {
            case .failed:
                throw VideoManagerError.mergeVideoError(error: exporter.error?.localizedDescription)
            case .cancelled:
                throw VideoManagerError.mergeVideoCancelled
            case .exporting:
                if (self.hasListeners) {
                    let results: [AnyHashable: Any] = [
                        "key": options.actionKey,
                        "progress": NSNumber(value: exporter.progress)
                    ]

                    self.sendEvent(withName: "VideoManager-MergeProgress", body: results)
                }
                break
            case .completed:
                let results: [String: AnyHashable] = [
                    "uri": "file://\(path)",
                    "duration": NSNumber(value: duration)
                ]
                NSLog("Completed a video merge \(path)")
                resolve(results)
                break;
            default:
                break;
            }
        } catch let error as VideoManagerError {
            reject("event_failure", "an error occurred - \(error.localizedDescription)", nil)
        } catch {
            reject("event_failure", "an error unknown occurred", nil)
        }
    }
}
