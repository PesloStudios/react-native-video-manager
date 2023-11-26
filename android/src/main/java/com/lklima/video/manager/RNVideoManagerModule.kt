package com.lklima.video.manager

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.util.Log
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableMap
import com.facebook.react.bridge.WritableNativeMap
import com.facebook.react.module.annotations.ReactModule
import com.googlecode.mp4parser.authoring.Movie
import com.googlecode.mp4parser.authoring.Track
import com.googlecode.mp4parser.authoring.builder.DefaultMp4Builder
import com.googlecode.mp4parser.authoring.container.mp4.MovieCreator
import com.googlecode.mp4parser.authoring.tracks.AppendTrack
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.io.IOException
import java.io.RandomAccessFile
import java.nio.channels.FileChannel
import java.util.LinkedList
import java.util.concurrent.BlockingQueue
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit

@ReactModule(name = "RNVideoManager")
class RNVideoManagerModule(private val reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {
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
                    var time = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
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
        } catch (e: Error) {
            e.printStackTrace()
            promise.reject(e.message)
        }
    }

    @ReactMethod
    fun merge(videoFiles: ReadableArray, promise: Promise) {
        val inMovies: MutableList<Movie> = ArrayList()
        for (i in 0 until videoFiles.size()) {
            val videoUrl = videoFiles.getString(i).replaceFirst("file://".toRegex(), "")
            try {
                inMovies.add(MovieCreator.build(videoUrl))
            } catch (e: IOException) {
                promise.reject(e.message)
                e.printStackTrace()
            }
        }
        val videoTracks: MutableList<Track> = LinkedList()
        val audioTracks: MutableList<Track> = LinkedList()
        for (m in inMovies) {
            for (t in m.tracks) {
                if (t.handler == "soun") {
                    audioTracks.add(t)
                }
                if (t.handler == "vide") {
                    videoTracks.add(t)
                }
            }
        }
        val result = Movie()
        if (!audioTracks.isEmpty()) {
            try {
                result.addTrack(AppendTrack(*audioTracks.toTypedArray()))
            } catch (e: IOException) {
                promise.reject(e.message)
                e.printStackTrace()
            }
        }
        if (!videoTracks.isEmpty()) {
            try {
                result.addTrack(AppendTrack(*videoTracks.toTypedArray()))
            } catch (e: IOException) {
                promise.reject(e.message)
                e.printStackTrace()
            }
        }
        val out = DefaultMp4Builder().build(result)
        var fc: FileChannel? = null
        try {
            val tsLong = System.currentTimeMillis() / 1000
            val ts = tsLong.toString()
            val outputVideo =
                reactContext.applicationContext.cacheDir.absolutePath + "output_" + ts + ".mp4"
            fc = RandomAccessFile(String.format(outputVideo), "rw").channel
            Log.d("VIDEO", fc.toString())
            out.writeContainer(fc)
            fc.close()
            promise.resolve(outputVideo)
        } catch (e: FileNotFoundException) {
            e.printStackTrace()
            promise.reject(e.message)
        } catch (e: IOException) {
            e.printStackTrace()
            promise.reject(e.message)
        }
    }

    override fun getName(): String {
        return "RNVideoManager"
    }
}