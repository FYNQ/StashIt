package com.fynq.stashr

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        @JvmStatic var lastSenderPackage: String? = null
        @JvmStatic var lastSenderLabel: String? = null
    }

    private fun captureSender(intent: Intent?) {
        var pkg: String? = null

        // Best-effort referrer detection
        val ref: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            this.referrer ?: intent?.getParcelableExtra(Intent.EXTRA_REFERRER)
        } else {
            @Suppress("DEPRECATION")
            intent?.getParcelableExtra(Intent.EXTRA_REFERRER)
        }

        if (ref != null) {
            // Typically: android-app://<package>
            if ("android-app".equals(ref.scheme, ignoreCase = true)) {
                pkg = ref.host
            } else {
                // Some devices might pass a string referrer
                val s = ref.toString()
                if (s.startsWith("android-app://")) {
                    pkg = s.removePrefix("android-app://")
                }
            }
        }

        if (pkg.isNullOrBlank()) {
            // Fallback
            val s = intent?.getStringExtra(Intent.EXTRA_REFERRER_NAME)
            if (!s.isNullOrBlank()) {
                pkg = s.removePrefix("android-app://")
            }
        }

        var label: String? = null
        if (!pkg.isNullOrBlank()) {
            try {
                val ai = packageManager.getApplicationInfo(pkg, 0)
                label = packageManager.getApplicationLabel(ai)?.toString()
            } catch (_: Exception) {
                // ignore
            }
        }

        lastSenderPackage = pkg
        lastSenderLabel = label
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureSender(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        captureSender(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "stashr/share_meta",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getLastSenderInfo" -> {
                    val map = hashMapOf<String, Any?>(
                        "package" to lastSenderPackage,
                        "label" to lastSenderLabel
                    )
                    result.success(map)
                }
                else -> result.notImplemented()
            }
        }
    }
}
