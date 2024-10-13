import Foundation
import AVFoundation

@objc(RNVideoManager)
class RNVideoManager: RCTEventEmitter {
    private let durationGenerator = DurationGenerator()
    private let thumbnailGenerator = ThumbnailGenerator()
    private var mergedVideoGenerator = MergedVideoGenerator()
    private var gridExportGenerator = GridExportGenerator()

    @objc
    override static func requiresMainQueueSetup() -> Bool {
        true
    }

    override func supportedEvents() -> [String]! {
        [EventKeys.GridExportProgressKey]
    }

    override func startObserving() {
        gridExportGenerator.hasListeners = true
    }

    override func stopObserving() {
        gridExportGenerator.hasListeners = false
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
        DeviceSleepBlock.stopSleep()
        mergedVideoGenerator.merge(fileNames, options: options) { results in
            DeviceSleepBlock.allowSleep()
            resolve(results.asDictionary())
        } onFailure: { error in
            DeviceSleepBlock.allowSleep()
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
        gridExportGenerator.sendEventCallback = { [weak self] name, payload in
            self?.sendEvent(withName: name, body: payload)
        }

        DeviceSleepBlock.stopSleep()
        gridExportGenerator.exportAsGrid(fileNames, options: options) { results in
            DeviceSleepBlock.allowSleep()
            resolve(results.asDictionary())
        } onFailure: { error in
            DeviceSleepBlock.allowSleep()
            reject("event_failure", error.errorDescription, nil)
        }
    }
}
