import Foundation
import AVFoundation

@objc(RNVideoManager)
class RNVideoManager: NSObject {
    private let durationGenerator = DurationGenerator()
    private let thumbnailGenerator = ThumbnailGenerator()
    private var mergedVideoGenerator = MergedVideoGenerator()
    private var gridExportGenerator = GridExportGenerator()

    @objc
    static func requiresMainQueueSetup() -> Bool {
        true
    }

    @objc(getDurationFor:resolver:rejecter:)
    func getDurationFor(
        fileName: String,
        resolve: RCTPromiseResolveBlock,
        reject: RCTPromiseRejectBlock
    ) {
        let response = durationGenerator.getDuration(for: fileName)
        resolve(response.asDictionary())
    }

    @objc(getVideoMetadataFor:resolver:rejecter:)
    func getVideoMetadataFor(
        fileNames: [String],
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        durationGenerator.getMetadata(for: fileNames, resolve: resolve, reject: reject)
    }

    @objc(generateThumbnailFor:options:resolver:rejecter:)
    func generateThumbnailFor(
        fileName: String,
        options: [AnyHashable: Any]?,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        thumbnailGenerator.generateThumbnail(
            of: fileName,
            options: options) {
                resolve(true)
            } onFailure: { error in
                reject("event_failure", error.errorDescription, nil)
            }
    }

    @objc(merge:options:resolver:rejecter:)
    func merge(
        fileNames: [String],
        options: [AnyHashable: Any]?,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        mergedVideoGenerator.merge(fileNames, options: options) { results in
            resolve(results.asDictionary())
        } onFailure: { error in
            reject("event_failure", error.errorDescription, nil)
        }
    }

    @objc(exportAsGrid:options:resolver:rejecter:)
    func exportAsGrid(
        fileNames: [String],
        options: [AnyHashable: Any]?,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        gridExportGenerator.exportAsGrid(fileNames, options: options) { results in
            resolve(results.asDictionary())
        } onFailure: { error in
            reject("event_failure", error.errorDescription, nil)
        }
    }
}
