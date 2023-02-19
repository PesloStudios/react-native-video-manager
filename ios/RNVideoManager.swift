import Foundation
import AVFoundation

@objc(RNVideoManager)
class RNVideoManager: RCTEventEmitter {
    private let durationGenerator = DurationGenerator()
    private let thumbnailGenerator = ThumbnailGenerator()
    private var mergedVideoGenerator = MergedVideoGenerator()

    override class func requiresMainQueueSetup() -> Bool {
        true
    }

    override func supportedEvents() -> [String]! {
        ["VideoManager-MergeProgress"]
    }

    override func startObserving() {
        mergedVideoGenerator.hasListeners = true
    }

    override func stopObserving() {
        mergedVideoGenerator.hasListeners = false
    }

    @objc(getDurationOf:resolver:rejecter:)
    func getDurationOf(
        fileName: String,
        resolve: RCTPromiseResolveBlock,
        reject: RCTPromiseRejectBlock
    ) {
        let response = durationGenerator.getDuration(for: fileName)
        resolve(response.asDictionary())
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
        mergedVideoGenerator.sendEventCallback = { [weak self] name, payload in
            self?.sendEvent(withName: name, body: payload)
        }

        mergedVideoGenerator.merge(fileNames, options: options) { results in
            resolve(results.asDictionary())
        } onFailure: { error in
            reject("event_failure", error.errorDescription, nil)
        }
    }
}
