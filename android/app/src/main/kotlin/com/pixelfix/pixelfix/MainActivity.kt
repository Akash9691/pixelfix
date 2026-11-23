package com.pixelfix.pixelfix

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/** Native JPG / WebP encoding (dart:ui can only write PNG). Runs off the main thread. */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pixelfix/codec")
            .setMethodCallHandler { call, result ->
                if (call.method != "encode") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val png = call.argument<ByteArray>("png")!!
                val format = call.argument<String>("format")!!
                val quality = call.argument<Int>("quality") ?: 90
                Thread {
                    try {
                        var bmp = BitmapFactory.decodeByteArray(png, 0, png.size)
                        if (format == "jpg" && bmp.hasAlpha()) {
                            // JPEG has no alpha: flatten transparency onto white, not black.
                            val flat = Bitmap.createBitmap(bmp.width, bmp.height, Bitmap.Config.ARGB_8888)
                            val canvas = android.graphics.Canvas(flat)
                            canvas.drawColor(android.graphics.Color.WHITE)
                            canvas.drawBitmap(bmp, 0f, 0f, null)
                            bmp.recycle()
                            bmp = flat
                        }
                        val out = ByteArrayOutputStream()
                        val fmt = when (format) {
                            "jpg" -> Bitmap.CompressFormat.JPEG
                            else -> if (Build.VERSION.SDK_INT >= 30) Bitmap.CompressFormat.WEBP_LOSSY
                                    else @Suppress("DEPRECATION") Bitmap.CompressFormat.WEBP
                        }
                        bmp.compress(fmt, quality, out)
                        bmp.recycle()
                        val bytes = out.toByteArray()
                        runOnUiThread { result.success(bytes) }
                    } catch (e: Throwable) {
                        runOnUiThread { result.error("encode", e.message, null) }
                    }
                }.start()
            }
    }
}
