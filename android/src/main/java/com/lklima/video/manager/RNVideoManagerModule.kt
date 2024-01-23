package com.lklima.video.manager

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableMap
import com.facebook.react.bridge.WritableNativeMap
import com.facebook.react.module.annotations.ReactModule
import com.lklima.video.manager.merger.MergedVideoResults
import com.lklima.video.manager.merger.MergedVideoResultsMapFactory
import com.lklima.video.manager.merger.UriSanitizer
import com.lklima.video.manager.merger.VideoMerger
import com.lklima.video.manager.merger.mp4parser.VideoMergerMp4Parser
import com.lklima.video.manager.merger.options.MergedVideoOptionsFactory
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.FileOutputStream
import java.io.IOException
import java.util.concurrent.BlockingQueue
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit

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

    companion object {
        private val NUMBER_OF_CORES = Runtime.getRuntime().availableProcessors()

        // Instantiates the queue of Runnables as a LinkedBlockingQueue
        private val workQueue: BlockingQueue<Runnable> = LinkedBlockingQueue()

        // Sets the amount of time an idle thread waits before terminating
        private val KEEP_ALIVE_TIME = 1

        // Sets the Time Unit to seconds
        private val KEEP_ALIVE_TIME_UNIT: TimeUnit = TimeUnit.SECONDS

        // Creates a thread pool manager
        private val threadPoolExecutor = ThreadPoolExecutor(
            NUMBER_OF_CORES,  // Initial pool size
            NUMBER_OF_CORES,  // Max pool size
            KEEP_ALIVE_TIME.toLong(),
            KEEP_ALIVE_TIME_UNIT,
            workQueue
        )
    }

    @ReactMethod
    fun getVideoMetadataFor(fileNames: ReadableArray, promise: Promise) {
        threadPoolExecutor.execute(Runnable {
            try {
                val metadata: WritableMap = WritableNativeMap()
                for (i in 0 until fileNames.size()) {
                    val fileName = fileNames.getString(i)
                    val retriever = MediaMetadataRetriever()
                    retriever.setDataSource(
                        reactContext.applicationContext,
                        Uri.parse(fileName.replaceFirst("file://".toRegex(), ""))
                    )
                    var time =
                        retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                    if (time == null) {
                        time = "-1000"
                    }
                    val seconds = (time.toLong() / 1000).toInt()
                    val fileMetadata: WritableMap = WritableNativeMap()
                    fileMetadata.putInt("duration", seconds)
                    fileMetadata.putBoolean("playable", true)
                    metadata.putMap(fileName, fileMetadata)
                }
                promise.resolve(metadata)
            } catch (exception: Exception) {
                exception.printStackTrace()
                promise.reject(exception.message)
            } catch (e: Error) {
                e.printStackTrace()
                promise.reject(e.message)
            }
        })
    }

    @ReactMethod
    fun generateThumbnailFor(video: String, options: ReadableMap, promise: Promise) {
        val writeDirectory = options.getString("writeDirectory")
        val fileName = options.getString("fileName")
        val timestamp = options.getDouble("timestamp").toLong()
        val filePath = String.format("%s/%s.png", writeDirectory, fileName)
        try {
            val retriever = MediaMetadataRetriever()
            var thumbnailBitmap: Bitmap? = null
            retriever.setDataSource(
                reactContext.applicationContext,
                Uri.parse(video.replaceFirst("file://".toRegex(), ""))
            )
            thumbnailBitmap = retriever.getFrameAtTime(
                timestamp * 1000000,
                MediaMetadataRetriever.OPTION_CLOSEST_SYNC
            )
            try {
                FileOutputStream(filePath).use { out ->
                    thumbnailBitmap!!.compress(
                        Bitmap.CompressFormat.PNG,
                        100,
                        out
                    )
                }
            } catch (e: IOException) {
                e.printStackTrace()
            }
            promise.resolve(true)
        } catch (exception: Exception) {
            exception.printStackTrace()
            promise.reject(exception.message)
        } catch (e: Error) {
            e.printStackTrace()
            promise.reject(e.message)
        }
    }

    @ReactMethod
    fun merge(videoFiles: ReadableArray, options: ReadableMap, promise: Promise) {
        scope.launch(Dispatchers.IO) {
            val files = buildList<String> {
                for (index in 0 until videoFiles.size()) {
                    add(videoFiles.getString(index))
                }
            }
            val uriSanitizer = UriSanitizer()
            val uris = files.map(uriSanitizer::sanitize)
            val videoMerger: VideoMerger = VideoMergerMp4Parser(reactContext)
            videoMerger.mergeVideos(
                videoFiles = uris,
                options = mergedVideoOptionsFactory.newInstance(options)
            ).onSuccess { output: MergedVideoResults ->
                withContext(Dispatchers.Main) {
                    promise.resolve(mergedVideoResultsMapFactory.newInstance(output))
                }
            }.onFailure { error ->
                withContext(Dispatchers.Main) {
                    promise.reject(error)
                }
            }
        }
    }

    override fun getName(): String = "RNVideoManager"
}