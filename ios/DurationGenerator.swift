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

internal struct DurationGenerator {
    internal func getDuration(for fileName: String) -> GetDurationResult {
        let asset = AVAsset(url: URL(fileURLWithPath: fileName))
        let duration = CMTimeGetSeconds(asset.duration)        
        let isPlayable = asset.isPlayable
        
        return GetDurationResult(duration: duration, playable: isPlayable)
    }
}
