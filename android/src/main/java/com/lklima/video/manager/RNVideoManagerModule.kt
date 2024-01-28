package com.lklima.video.manager

import android.util.Log
import com.facebook.react.bridge.NativeMap
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableNativeMap
import com.facebook.react.module.annotations.ReactModule
import com.lklima.video.manager.merger.MergedVideoResults
import com.lklima.video.manager.merger.MergedVideoResultsMapFactory
import com.lklima.video.manager.merger.UriSanitizer
import com.lklima.video.manager.merger.VideoMerger
import com.lklima.video.manager.merger.ffmpeg.VideoMergerFfmpeg
import com.lklima.video.manager.merger.options.MergedVideoOptionsFactory
import com.lklima.video.manager.metadata.VideoMetadataExtractor
import com.lklima.video.manager.thumbnail.VideoThumbnailGenerator
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@ReactModule(name = "RNVideoManager")
class RNVideoManagerModule(
    private val reactContext: ReactApplicationContext
) : ReactContextBaseJavaModule(reactContext) {

    private val scope = MainScope()

    private val mergedVideoOptionsFactory by lazy {
        MergedVideoOptionsFactory(reactContext)
    }

    private val mergedVideoResultsMapFactory by lazy {
        MergedVideoResultsMapFactory()
    }

    @ReactMethod
    fun getVideoMetadataFor(fileNames: ReadableArray, promise: Promise) {
        scope.launch(Dispatchers.Main) {
            val files = buildList {
                for (i in 0 until fileNames.size()) {
                    add(fileNames.getString(i))
                }
            }
            VideoMetadataExtractor(reactContext).getVideoMetadataFor(
                files = files,
            ).onSuccess { map: Map<String, Long> ->
                Log.v(TAG, "get video metadata success $map")
                val metadata = WritableNativeMap()
                map.forEach { (fileName: String, durationSecs: Long) ->
                    WritableNativeMap().apply {
                        putInt("duration", durationSecs.toInt())
                        putBoolean("playable", true)
                    }.let {
                        metadata.putMap(fileName, it)
                    }
                }
                Log.v(TAG, "get video metadata success $metadata")
                promise.resolve(metadata)
            }.onFailure { error ->
                Log.e(TAG, "get video metadata failure", error)
                promise.reject("failed to get video metadata ${error.message}", error)
            }
        }
    }

    @ReactMethod
    fun generateThumbnailFor(video: String, options: ReadableMap, promise: Promise) {
        scope.launch(Dispatchers.Main) {
            VideoThumbnailGenerator(reactContext).generateThumbnail(
                video = video,
                writeDirectory = requireNotNull(options.getString("writeDirectory")) {
                    "no write directory provided in options map"
                },
                fileName = requireNotNull(options.getString("fileName")) {
                    "no filename provided in options map"
                },
                timestamp = options.getDouble("timestamp").toLong()
            ).onSuccess { success ->
                Log.v(TAG, "generate thumbnail success? $success")
                promise.resolve(success)
            }.onFailure { error ->
                Log.e(TAG, "generate thumbnail failure", error)
                promise.reject("failed to generate thumbnail: ${error.message}", error)
            }
        }
    }

    @ReactMethod
    fun merge(videoFiles: ReadableArray, options: ReadableMap, promise: Promise) {
        scope.launch(Dispatchers.IO) {
            runCatching {
                val files = buildList {
                    for (index in 0 until videoFiles.size()) {
                        add(videoFiles.getString(index))
                    }
                }
                val uriSanitizer = UriSanitizer()
                files.map(uriSanitizer::sanitize)
            }.mapCatching { uris ->
                val videoMerger: VideoMerger = VideoMergerFfmpeg(reactContext)
                videoMerger.mergeVideos(
                    videoFiles = uris,
                    options = mergedVideoOptionsFactory.newInstance(options)
                ).getOrThrow()
            }.mapCatching { output: MergedVideoResults ->
                mergedVideoResultsMapFactory.newInstance(output)
            }.onSuccess { nativeMap: NativeMap ->
                Log.v(TAG, "merge success $nativeMap")
                withContext(Dispatchers.Main) {
                    promise.resolve(nativeMap)
                }
            }.onFailure { error ->
                Log.e(TAG, "merge failed", error)
                withContext(Dispatchers.Main) {
                    promise.reject(error)
                }
            }
        }
    }

    override fun getName(): String = "RNVideoManager"

    private companion object {
        const val TAG = "RNVideoManagerModule"
    }
}