
import Foundation
import AVFoundation

internal struct MetadataUtils {

    /// Formats the lat/lon as ISO 6709 without altitude
    private static func formatISO6709(lat: String, lon: String) -> String? {
        guard let latitude = Double(lat), let longitude = Double(lon) else {
            print("Invalid latitude or longitude values")
            return nil
        }

        return String(format: "%+.6f%+.6f/", latitude, longitude)
    }

    private static func buildTimestampItem(from timestamp: String?) -> AVMutableMetadataItem? {
        guard let timestamp = timestamp else {
            return nil
        }

        let item = AVMutableMetadataItem()
        item.key = AVMetadataKey.commonKeyCreationDate as (NSCopying & NSObjectProtocol)
        item.keySpace = .common
        item.value = timestamp as (NSCopying & NSObjectProtocol)

        return item
    }

    // NOTE FOR FUTURE DEVS:
    // This only adds the location data to the 'QuickTime' metadata, not the EXIF metadata.
    private static func buildLocationItem(from latitude: String?, longitude: String?) -> AVMutableMetadataItem? {
        guard let latitude = latitude,
              let longitude = longitude,
              let iso6709Coords = MetadataUtils.formatISO6709(lat: latitude, lon: longitude) else {
            return nil
        }

        let quicktimeItem = AVMutableMetadataItem()
        quicktimeItem.key = AVMetadataKey.quickTimeMetadataKeyLocationISO6709 as (NSCopying & NSObjectProtocol)
        quicktimeItem.keySpace = .quickTimeMetadata
        quicktimeItem.value = iso6709Coords as (NSCopying & NSObjectProtocol)

        return quicktimeItem
    }

    // Adds the timestamp and GPS coordinates to the QuickTime file metadata.
    // NOTE: This does not add the exif metadata, that is impossible via the
    // Apple APIs - ffmpeg may do it but it hasn't been shown to work on Android...
    internal static func buildMetadata(timestamp: String?, latitude: String?, longitude: String?) -> [AVMutableMetadataItem] {
        var items: [AVMutableMetadataItem] = []

        if let item = MetadataUtils.buildTimestampItem(from: timestamp) {
            items.append(item)
        }

        if let item = MetadataUtils.buildLocationItem(from: latitude, longitude: longitude) {
            items.append(item)
        }

        return items
    }
}
