package com.lklima.video.manager.merger

import android.net.Uri

interface VideoMerger {
    suspend fun mergeVideos(videoFiles: List<Uri>, options: MergeOptions): Result<Uri>
}