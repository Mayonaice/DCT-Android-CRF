package com.example.crf_android_fresh

import android.content.pm.ActivityInfo
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val orientationChannel = "app.crf/orientation"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, orientationChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "lockLandscape" -> {
                        runOnUiThread {
                            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
                        }
                        result.success(true)
                    }
                    "lockPortrait" -> {
                        runOnUiThread {
                            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
                        }
                        result.success(true)
                    }
                    "unlock" -> {
                        runOnUiThread {
                            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
