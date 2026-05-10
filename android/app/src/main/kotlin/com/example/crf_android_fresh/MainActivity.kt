package com.example.crf_android_fresh

import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val orientationChannel = "app.crf/orientation"
    private var desiredOrientation: Int = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
    private var allowInternal: Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enforce()
    }

    override fun onResume() {
        super.onResume()
        enforce()
    }

    override fun onStart() {
        super.onStart()
        enforce()
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        enforce()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) enforce()
    }

    override fun setRequestedOrientation(requestedOrientation: Int) {
        if (allowInternal) {
            super.setRequestedOrientation(requestedOrientation)
        } else {
            super.setRequestedOrientation(desiredOrientation)
        }
    }

    private fun enforce() {
        allowInternal = true
        try {
            super.setRequestedOrientation(desiredOrientation)
        } finally {
            allowInternal = false
        }
    }

    private fun applyOrientation(target: Int) {
        desiredOrientation = target
        runOnUiThread { enforce() }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, orientationChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "lockLandscape" -> {
                        applyOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE)
                        result.success(true)
                    }
                    "lockSensorLandscape" -> {
                        applyOrientation(ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE)
                        result.success(true)
                    }
                    "lockPortrait" -> {
                        applyOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT)
                        result.success(true)
                    }
                    "unlock" -> {
                        applyOrientation(ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
