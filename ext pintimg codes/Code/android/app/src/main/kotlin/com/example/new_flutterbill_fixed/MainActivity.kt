package com.example.flutterbill

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "rawbt.intent.channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "sendToRawBT") {
                val text = call.argument<String>("text") ?: ""
                val type = call.argument<String>("type") ?: "text/plain"

                val intent = Intent(Intent.ACTION_SEND).apply {
                    setType(type)
                    putExtra(Intent.EXTRA_TEXT, text)
                    setPackage("ru.a402d.rawbtprinter")
                }

                if (intent.resolveActivity(packageManager) != null) {
                    startActivity(intent)
                    result.success("Sent to RawBT")
                } else {
                    result.error("UNAVAILABLE", "RawBT app not found", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
