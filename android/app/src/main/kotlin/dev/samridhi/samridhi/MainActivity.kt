package dev.samridhi.samridhi

import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// FlutterFragmentActivity: the local_auth biometric prompt needs a
// FragmentActivity.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.samridhi/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // FLAG_SECURE blocks screenshots, screen recording and the
                    // recents thumbnail. User-toggled; off by default.
                    "setSecure" -> {
                        val on = call.arguments as? Boolean ?: false
                        if (on) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    "rootHints" -> result.success(rootHints())
                    else -> result.notImplemented()
                }
            }
    }

    // Best-effort and trivially bypassable: informational only, never a gate.
    private fun rootHints(): List<String> {
        val hints = mutableListOf<String>()
        val dirs = System.getenv("PATH")?.split(":") ?: emptyList()
        if ((dirs + listOf("/system/bin", "/system/xbin", "/sbin")).distinct()
                .any { File(it, "su").exists() }) hints.add("su binary present")
        if (Build.TAGS?.contains("test-keys") == true) hints.add("test-keys build")
        listOf("/system/app/Superuser.apk", "/data/adb/magisk").forEach {
            if (File(it).exists()) hints.add("root manager files present")
        }
        return hints.distinct()
    }
}
