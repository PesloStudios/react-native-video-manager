import Foundation
import AVFoundation

public enum ThumbnailGeneratorError: LocalizedError {
    case invalidThumbnailOptions
    case thumbnailGenerationFailed
    case thumbnailMissingPNGData
    case imageNotWritten
    case unknownError

    public var errorDescription: String? {
        switch self {
        case .invalidThumbnailOptions:
            return "Options were provided to generateThumbnailFor(...), but an option did not match expected types / availability"
        case .thumbnailGenerationFailed:
            return "The thumbnail could not be generated"
        case .thumbnailMissingPNGData:
            return "The thumbnail was generated, but PNG data could not be found"
        case .imageNotWritten:
            return "The thumbnail was not written to disk"
        default:
            return "An unexpected error has occurred"
        }
    }
}

internal struct GetThumbnailOptions: Codable {
    var writeDirectory: String = GetThumbnailOptions.cacheDirectory()
    var fileName: String = "thumbnail"
    var timestamp: Double = 0

    var filePath: String {
        get {
            "\(writeDirectory)/\(fileName).jpg"
        }
    }

    var generatorTimestamp: [NSValue] {
        [NSValue(time: CMTimeMake(value: Int64(timestamp), timescale: 1))]
    }

    static func cacheDirectory() -> String {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory.absoluteString
    }

    /// Initialises a config object, with the given dictionary payload.
    /// - Parameter rawValue: A dictionary options payload, provided by the JS layer.
    /// - Throws: An error if the options aren't provided, or if typing of the payload is incorrect.
    init(rawValue: [AnyHashable: Any]?) throws {
        guard let data = rawValue else {
            return
        }

        do {
            let decodeableData = try JSONSerialization.data(withJSONObject: data)
            self = try JSONDecoder().decode(GetThumbnailOptions.self, from: decodeableData)
        } catch {
            throw ThumbnailGeneratorError.invalidThumbnailOptions
        }
    }
}

public typealias ThumbnailGeneratorSuccess = () -> Void
public typealias ThumbnailGeneratorFailure = (ThumbnailGeneratorError) -> Void

public struct ThumbnailGenerator {
    public func generateThumbnail(
        of fileName: String,
        options: [AnyHashable: Any]?,
        onSuccess: @escaping ThumbnailGeneratorSuccess,
        onFailure: @escaping ThumbnailGeneratorFailure
    ) {
        autoreleasepool {
            do {
                let thumbnailOptions = try GetThumbnailOptions(rawValue: options)

                let asset = AVAsset(url: URL(fileURLWithPath: fileName))

                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true

                generator.generateCGImagesAsynchronously(
                    forTimes: thumbnailOptions.generatorTimestamp
                ) { timeRequested, image, timeActual, result, error in
                    autoreleasepool {
                        guard result == .succeeded else {
                            onFailure(.thumbnailGenerationFailed)
                            return
                        }

                        writeImage(image, to: thumbnailOptions.filePath, onSuccess: onSuccess, onFailure: onFailure)
                    }
                }
            } catch let error as ThumbnailGeneratorError {
                onFailure(error)
            } catch {
                onFailure(.unknownError)
            }
        }
    }

    private func writeImage(
        _ image: CGImage?,
        to filePath: String,
        onSuccess: ThumbnailGeneratorSuccess,
        onFailure: ThumbnailGeneratorFailure
    ) {
        autoreleasepool {
            guard let image = image else {
                onFailure(.thumbnailGenerationFailed)
                return
            }

            guard let data = UIImage(cgImage: image).jpegData(compressionQuality: 0.4) else {
                onFailure(.thumbnailMissingPNGData)
                return
            }

            let fileManager = FileManager.default
            guard fileManager.createFile(atPath: filePath, contents: data) else {
                onFailure(.imageNotWritten)
                return
            }

            onSuccess()
        }
    }
}

