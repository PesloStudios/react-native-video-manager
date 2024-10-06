import Foundation
import AVFoundation

/**
 This code is nspired by and refined from https://stackoverflow.com/questions/68558373/how-to-combine-hstack-multiple-videos-side-by-side-with-avmutablevideocomposit
 to best support displaying in a grid + some of the later AVFoundation techniques.
 */

internal struct GridExportProgressEvent {
    let progress: Float

    func asDictionary() -> [AnyHashable: Any] {
        [
            "progress": NSNumber(value: progress)
        ]
    }
}

internal struct GridExportResult {
    let path: String

    func asDictionary() -> [AnyHashable: Any] {
        [
            "uri": "file://\(path)",
        ]
    }
}

internal enum GridExportError: LocalizedError {
    case invalidGridExportOptions
    case couldNotAddVideoTrack
    case missingVideo(fileName: String)
    case couldNotBuildGenerator
    case exportVideoCancelled
    case exportFailed(error: Error?)
    case unknownError

    var errorDescription: String? {
        switch self {
        case .invalidGridExportOptions:
            return "Options were provided to merge(...), but an option did not match expected types / availability"
        case .couldNotAddVideoTrack:
            return "A video track could not be added to the composition"
        case .missingVideo(let fileName):
            return "Video with name \(fileName) is missing a video track"
        case .couldNotBuildGenerator:
            return "The video generator could not be built"
        case .exportVideoCancelled:
            return "The export operation was cancelled"
        case .exportFailed(let error):
            return "The export operation failed due to: \(error?.localizedDescription ?? "unknown error") \(error.debugDescription)"
        default:
            return "An unexpected error has occurred"
        }
    }
}

internal enum GridExportOutputResolutionOption: String, Codable {
    case res720p = "720p"
    case res1080p = "1080p"
    case res4K = "4K"
    case resDoubleLargest = "doubleLargest"

    var desiredSize: CGSize? {
        switch self {
        case .res720p:
            CGSize(width: 1280, height: 720)
        case .res1080p:
            CGSize(width: 1920, height: 1080)
        case .res4K:
            CGSize(width: 3840, height: 2160)
        default:
            nil
        }
    }
}


internal struct GridExportOptions: Codable {
    var writeDirectory: String = VideoManagerUtils.applicationDocumentsDirectory()
    var fileName: String = "grid_export"
    var duration: Double = 0
    var resolution: GridExportOutputResolutionOption = .resDoubleLargest

    /// Initialises a config object, with the given dictionary payload.
    /// - Parameter rawValue: A dictionary options payload, provided by the JS layer.
    /// - Throws: An error if the options aren't provided, or if typing of the payload is incorrect.
    init(rawValue: [AnyHashable: Any]?) throws {
        guard let data = rawValue else {
            return
        }

        do {
            let decodeableData = try JSONSerialization.data(withJSONObject: data)
            self = try JSONDecoder().decode(GridExportOptions.self, from: decodeableData)
        } catch {
            throw GridExportError.invalidGridExportOptions
        }
    }
}

typealias GridExportSuccess = (GridExportResult) -> Void
typealias GridExportFailure = (GridExportError) -> Void
typealias GridExportProgressEventCallback = ((String, [AnyHashable: Any]) -> Void)

internal struct AssetInfo {
    let asset: AVURLAsset
    let assetTrack: AVAssetTrack
    let compTrack: AVMutableCompositionTrack
}

internal class GridExportGenerator {

    var sendEventCallback: GridExportProgressEventCallback?
    var hasListeners = false
    private var exportTimer: Timer?

    private static let timerInvalidationStatuses: [AVAssetExportSession.Status] = [.cancelled, .failed, .completed]

    // 2 * width & height of HD footage
    static let EXPORT_SIZE = CGSize(width: 2560, height: 1920)

    private func resolutionSizeFor(_ asset: AVAssetTrack) -> CGSize {
        let size = asset.naturalSize.applying(asset.preferredTransform)
        return CGSize(width: abs(size.width), height: abs(size.height))
    }

    private func getAssetInfoFrom(
        _ filePath: String,
        composition: AVMutableComposition
    ) throws -> AssetInfo {
        let asset = AVURLAsset(url: URL(fileURLWithPath: filePath))
        guard let track = composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw GridExportError.couldNotAddVideoTrack
        }

        guard let videoAssetTrack = asset.tracks(withMediaType: .video).first else {
            throw GridExportError.missingVideo(fileName: filePath)
        }

        try track.insertTimeRange(CMTimeRangeMake(start: videoAssetTrack.timeRange.start, duration: videoAssetTrack.timeRange.duration), of: videoAssetTrack, at: videoAssetTrack.timeRange.start)

        return AssetInfo(asset: asset, assetTrack: videoAssetTrack, compTrack: track)
    }

    private func getInstructionFrom(
        _ assetInfo: AssetInfo,
        targetResolution: CGSize,
        activeIndex: Int,
        totalCount: Int
    ) -> AVMutableVideoCompositionLayerInstruction {
        let lInst = AVMutableVideoCompositionLayerInstruction(assetTrack: assetInfo.compTrack)
        let resolution = assetInfo.assetTrack.resolution
        let fittingResolution = resolution.boundsThatFit(parent: targetResolution)

        let width: CGFloat = targetResolution.width
        let height: CGFloat = targetResolution.height

        let scale = fittingResolution.1

        let transform = CGAffineTransform(scaleX: scale, y: scale)

        if (activeIndex < 2) {
            let t2 = transform.concatenating(CGAffineTransform(translationX: (activeIndex == 0 ? targetResolution.width - fittingResolution.0.width : 0) + (CGFloat(activeIndex)*width), y: targetResolution.height - fittingResolution.0.height))
            lInst.setTransform(t2, at: CMTime.zero)
        } else {
            let t2 = transform.concatenating(CGAffineTransform(translationX: (activeIndex == 2 ? targetResolution.width - fittingResolution.0.width : 0) + (CGFloat(activeIndex - 2)*width), y: height))
            lInst.setTransform(t2, at: CMTime.zero)
        }

        return lInst
    }

    internal func exportAsGrid(
        _ filePaths: [String],
        options: [AnyHashable: Any]?,
        onSuccess: @escaping GridExportSuccess,
        onFailure: @escaping GridExportFailure
    ) {
        do {
            let exportOptions = try GridExportOptions(rawValue: options)
            let composition = AVMutableComposition()

            let assetInfos: [AssetInfo] = try filePaths.map {
                try getAssetInfoFrom($0, composition: composition)
            }

            var targetResolution = exportOptions.resolution.desiredSize ?? GridExportGenerator.EXPORT_SIZE

            if (exportOptions.resolution == .resDoubleLargest) {
                targetResolution = assetInfos.sorted { (a: AssetInfo, b: AssetInfo) in
                    let resolutionA = a.assetTrack.resolution
                    let resolutionB = b.assetTrack.resolution
                    return (resolutionA.width * resolutionA.height) > (resolutionB.width * resolutionB.height)
                }.first?.assetTrack.resolution.doubled ?? GridExportGenerator.EXPORT_SIZE
            }

            let stackComposition = AVMutableVideoComposition()
            stackComposition.renderSize = CGSize(
                width: targetResolution.width,
                height: targetResolution.height
            )

            stackComposition.renderScale = 1.0
            stackComposition.frameDuration = CMTime(
                seconds: 1/30,
                preferredTimescale: 600
            )

            var i = 0
            let instructions: [AVMutableVideoCompositionLayerInstruction] = assetInfos.map {
                let instruction = getInstructionFrom($0, targetResolution: targetResolution.halfed, activeIndex: i, totalCount: assetInfos.count)
                i += 1
                return instruction
            }

            let inst = AVMutableVideoCompositionInstruction()
            inst.timeRange = CMTimeRange(start: CMTime.zero, duration: CMTime(seconds: exportOptions.duration * 600, preferredTimescale: 600))
            inst.layerInstructions = instructions

            stackComposition.instructions = [inst]

            let docPath = exportOptions.writeDirectory.appending("/\(exportOptions.fileName).mp4")
            let writeURL = URL(fileURLWithPath: docPath)

            if FileManager.default.fileExists(atPath: docPath) {
                try FileManager.default.removeItem(atPath: docPath)
            }

            guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
                throw GridExportError.couldNotBuildGenerator
            }

            exporter.outputURL = writeURL
            exporter.videoComposition = stackComposition
            exporter.outputFileType = .mp4

            DispatchQueue.main.async { [weak self] in
               let exportProgressBarTimer = Timer.scheduledTimer(
                withTimeInterval: 1,
                repeats: true
               ) { [weak self] timer in
                   self?.onTimerFiredFor(timer, exporter: exporter)
               }

               RunLoop.current.add(exportProgressBarTimer, forMode: .common)
               self?.exportTimer = exportProgressBarTimer
           }

            exporter.exportAsynchronously { [weak self] in
                self?.handleUpdate(
                    in: exporter,
                    options: exportOptions,
                    path: docPath,
                    onSuccess: onSuccess,
                    onFailure: onFailure
                )
            }
        } catch let error as GridExportError {
            onFailure(error)
        } catch {
            onFailure(.unknownError)
        }
    }

    private func onTimerFiredFor(
        _ timer: Timer,
        exporter: AVAssetExportSession
    ) {
        guard !GridExportGenerator.timerInvalidationStatuses.contains(exporter.status) else {
            exportTimer?.invalidate()
            exportTimer = nil
            return
        }

        let progress = exporter.progress

        guard progress != 0 else {
            return
        }

        guard progress < 0.99 else {
            exportTimer?.invalidate()
            exportTimer = nil
            return
        }

        if (hasListeners) {
            let results = GridExportProgressEvent(progress: progress)
            self.sendEventCallback?(
                EventKeys.GridExportProgressKey,
                results.asDictionary()
            )
        }
    }

    private func handleUpdate(
        in exporter: AVAssetExportSession,
        options: GridExportOptions,
        path: String,
        onSuccess: GridExportSuccess,
        onFailure: GridExportFailure
    ) {
        do {
            switch exporter.status {
            case .failed:
                throw GridExportError.exportFailed(error: exporter.error)
            case .cancelled:
                throw GridExportError.exportVideoCancelled
            case .completed:
                onSuccess(
                    GridExportResult(
                        path: path
                    )
                )
                break;
            default:
                break;
            }
        } catch let error as GridExportError {
            onFailure(error)
        } catch {
            onFailure(.unknownError)
        }
    }
}
