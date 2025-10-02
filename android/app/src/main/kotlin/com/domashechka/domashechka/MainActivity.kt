package com.domashechka.domashechka

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "schelper/timezone")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getTimeZone" -> {
                        try {
                            val tz: String = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                                java.time.ZoneId.systemDefault().id
                            else
                                TimeZone.getDefault().id
                            result.success(tz)
                        } catch (e: Throwable) {
                            result.error("error", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
