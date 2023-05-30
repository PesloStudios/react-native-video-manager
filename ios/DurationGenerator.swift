import Foundation
import AVFoundation

internal struct GetDurationResult {
    let duration: Double
    let playable: Bool

    func asDictionary() -> [AnyHashable: Any] {
        [
            "duration": duration,
            "playable": playable
        ]
    }
}

internal struct VideoMetadata {
    let duration: Double
    let playable: Bool

    func asDictionary() -> [AnyHashable: Any] {
        [
            "duration": duration,
            "playable": playable
        ]
    }
}

internal struct GetMetadataResult {
    let result: [String: VideoMetadata]

    func asDictionary() -> [AnyHashable: Any] {
        var mappedResult: [AnyHashable: Any] = [:]

        result.keys.forEach({ key in
            mappedResult[key] = result[key]?.asDictionary()
        })

        return mappedResult
    }
}

internal struct DurationGenerator {
    internal func getDuration(for fileName: String) -> GetDurationResult {
        let asset = AVAsset(url: URL(fileURLWithPath: fileName))
        let duration = CMTimeGetSeconds(asset.duration)        
        let isPlayable = asset.isPlayable
        
        return GetDurationResult(duration: duration, playable: isPlayable)
    }

    internal func getMetadata(for fileNames: [String]) -> GetMetadataResult {
        var videoMetadata: [String: VideoMetadata] = [:]

        fileNames.forEach({ fileName in
            let asset = AVAsset(url: URL(fileURLWithPath: fileName))
            let duration = CMTimeGetSeconds(asset.duration)

            videoMetadata[fileName] = VideoMetadata(
                duration: duration,
                playable: asset.isPlayable
            )
        })

        return GetMetadataResult(result: videoMetadata)
    }
}
