import Foundation
import AVFoundation

extension AVAssetTrack {

    var resolutionSize: CGSize {
        let size = self.naturalSize.applying(self.preferredTransform)
        return CGSize(width: abs(size.width), height: abs(size.height))
    }
    
}
