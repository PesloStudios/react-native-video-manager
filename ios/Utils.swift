
import Foundation

internal struct VideoManagerUtils {
    static func applicationDocumentsDirectory() -> String {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory.absoluteString
    }
}
