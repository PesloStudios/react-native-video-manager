import Foundation
import AVFoundation

internal struct GetDurationResult {
    let duration: Double

    func asDictionary() -> [AnyHashable: Any] {
        [
            "duration": duration
        ]
    }
}

internal struct DurationGenerator {
    internal func getDuration(for fileName: String) -> GetDurationResult {
        let asset = AVAsset(url: URL(fileURLWithPath: fileName))
        let duration = CMTimeGetSeconds(asset.duration)

        return GetDurationResult(duration: duration)
    }
}
