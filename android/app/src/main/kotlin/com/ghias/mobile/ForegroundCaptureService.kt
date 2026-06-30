package com.ghias.mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.util.DisplayMetrics
import android.util.Log
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import java.io.ByteArrayOutputStream

class ForegroundCaptureService : Service() {

    companion object {
        private const val CHANNEL_ID = "kairo_capture_channel"
        private const val NOTIFICATION_ID = 2026
        private const val TAG = "ForegroundCaptureServ"
        var instance: ForegroundCaptureService? = null
            private set
    }

    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var screenWidth = 1080
    private var screenHeight = 2400
    private var screenDensity = 400

    inner class LocalBinder : Binder() {
        fun getService(): ForegroundCaptureService = this@ForegroundCaptureService
    }

    private val binder = LocalBinder()

    override fun onBind(intent: Intent?): IBinder {
        return binder
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        setupScreenMetrics()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_NOT_STICKY

        val resultCode = intent.getIntExtra("resultCode", 0)
        val resultData = intent.getParcelableExtra<Intent>("resultData")

        if (resultCode != 0 && resultData != null) {
            startForegroundNotification()
            startProjection(resultCode, resultData)
        } else {
            Log.e(TAG, "Invalid projection start parameters.")
            stopSelf()
        }

        return START_NOT_STICKY
    }

    private fun setupScreenMetrics() {
        val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = windowManager.currentWindowMetrics.bounds
            screenWidth = bounds.width()
            screenHeight = bounds.height()
        } else {
            val display = windowManager.defaultDisplay
            val metrics = DisplayMetrics()
            display.getRealMetrics(metrics)
            screenWidth = metrics.widthPixels
            screenHeight = metrics.heightPixels
        }
        screenDensity = resources.displayMetrics.densityDpi
    }

    private fun startForegroundNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Kairo Screen Capture",
                NotificationManager.IMPORTANCE_LOW
            )
            manager.createNotificationChannel(channel)
        }

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Kairo Eyes Active")
            .setContentText("Continuous screen understanding is running.")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun startProjection(resultCode: Int, resultData: Intent) {
        val mpManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        mediaProjection = mpManager.getMediaProjection(resultCode, resultData)

        imageReader = ImageReader.newInstance(
            screenWidth,
            screenHeight,
            PixelFormat.RGBA_8888,
            2
        )

        virtualDisplay = mediaProjection?.createVirtualDisplay(
            "kairo-display",
            screenWidth,
            screenHeight,
            screenDensity,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader?.surface,
            null,
            null
        )

        Log.d(TAG, "MediaProjection screenshot capture pipeline running: ${screenWidth}x${screenHeight}")
    }

    fun captureLatestFrame(): ByteArray? {
        val reader = imageReader ?: return null
        val image = reader.acquireLatestImage() ?: return null

        try {
            val planes = image.planes
            val buffer = planes[0].buffer
            val pixelStride = planes[0].pixelStride
            val rowStride = planes[0].rowStride
            val rowPadding = rowStride - pixelStride * screenWidth

            // Allocate a bitmap to reconstruct the RGBA_8888 buffer
            val bitmap = Bitmap.createBitmap(
                screenWidth + rowPadding / pixelStride,
                screenHeight,
                Bitmap.Config.ARGB_8888
            )
            bitmap.copyPixelsFromBuffer(buffer)

            // Crop out stride padding to match exact screen dimensions
            val cleanBitmap = Bitmap.createBitmap(bitmap, 0, 0, screenWidth, screenHeight)
            val stream = ByteArrayOutputStream()
            cleanBitmap.compress(Bitmap.CompressFormat.JPEG, 85, stream)
            
            bitmap.recycle()
            cleanBitmap.recycle()

            return stream.toByteArray()
        } catch (e: Exception) {
            Log.e(TAG, "Frame extraction error", e)
            return null
        } finally {
            image.close()
        }
    }

    override fun onDestroy() {
        virtualDisplay?.release()
        mediaProjection?.stop()
        imageReader?.close()
        instance = null
        super.onDestroy()
    }
}
