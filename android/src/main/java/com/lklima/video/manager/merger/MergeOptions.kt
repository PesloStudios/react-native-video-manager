package com.lklima.video.manager.merger

data class MergeOptions(
    val fileName: String,
    val outputPath: String,
    val noAudio: Boolean,
    val timestamp: String,
    val latitude: String,
    val longitude: String
)