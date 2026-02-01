package io.seenn.seenn_flutter

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * SeennFlutterPlugin
 *
 * Flutter plugin for Seenn SDK with iOS Live Activity and Android Ongoing Notification support.
 */
class SeennFlutterPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var notificationManager: NotificationManager? = null

    // Track active notifications
    private val activeNotifications = mutableMapOf<String, Int>()
    private var notificationIdCounter = 1000

    companion object {
        private const val CHANNEL_ID = "seenn_job_progress"
        private const val CHANNEL_NAME = "Job Progress"
        private const val CHANNEL_DESCRIPTION = "Shows progress for background jobs"
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "io.seenn/flutter_plugin")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${Build.VERSION.RELEASE}")
            }
            "isOngoingNotificationSupported" -> {
                result.success(true)
            }
            "areNotificationsEnabled" -> {
                result.success(NotificationManagerCompat.from(context).areNotificationsEnabled())
            }
            "startOngoingNotification" -> {
                handleStartNotification(call, result)
            }
            "updateOngoingNotification" -> {
                handleUpdateNotification(call, result)
            }
            "endOngoingNotification" -> {
                handleEndNotification(call, result)
            }
            "cancelOngoingNotification" -> {
                handleCancelNotification(call, result)
            }
            "isNotificationActive" -> {
                handleIsNotificationActive(call, result)
            }
            "getActiveNotificationIds" -> {
                result.success(activeNotifications.keys.toList())
            }
            "cancelAllNotifications" -> {
                handleCancelAllNotifications(result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, importance).apply {
                description = CHANNEL_DESCRIPTION
                setShowBadge(false)
            }
            notificationManager?.createNotificationChannel(channel)
        }
    }

    private fun handleStartNotification(call: MethodCall, result: Result) {
        try {
            val jobId = call.argument<String>("jobId")
            val title = call.argument<String>("title")
            val jobType = call.argument<String>("jobType")
            val initialProgress = call.argument<Int>("initialProgress") ?: 0
            val initialMessage = call.argument<String>("initialMessage")

            if (jobId == null || title == null) {
                result.error("INVALID_ARGS", "Missing required arguments: jobId, title", null)
                return
            }

            // Cancel existing notification for this job if any
            activeNotifications[jobId]?.let { existingId ->
                notificationManager?.cancel(existingId)
            }

            val notificationId = notificationIdCounter++
            activeNotifications[jobId] = notificationId

            val notification = buildProgressNotification(
                title = title,
                message = initialMessage ?: "Starting...",
                progress = initialProgress,
                isOngoing = true
            )

            notificationManager?.notify(notificationId, notification.build())

            result.success(mapOf(
                "notificationId" to notificationId,
                "jobId" to jobId
            ))
        } catch (e: Exception) {
            result.error("START_FAILED", e.message, null)
        }
    }

    private fun handleUpdateNotification(call: MethodCall, result: Result) {
        try {
            val jobId = call.argument<String>("jobId")
            val progress = call.argument<Int>("progress")
            val status = call.argument<String>("status")
            val message = call.argument<String>("message")
            val stageName = call.argument<String>("stageName")
            val stageIndex = call.argument<Int>("stageIndex")
            val stageTotal = call.argument<Int>("stageTotal")
            val estimatedEndTime = call.argument<Long>("estimatedEndTime")

            if (jobId == null || progress == null || status == null) {
                result.error("INVALID_ARGS", "Missing required arguments: jobId, progress, status", null)
                return
            }

            val notificationId = activeNotifications[jobId]
            if (notificationId == null) {
                result.success(false)
                return
            }

            // Build message with stage info
            val displayMessage = buildDisplayMessage(message, stageName, stageIndex, stageTotal, estimatedEndTime)

            val notification = buildProgressNotification(
                title = stageName ?: "Processing",
                message = displayMessage,
                progress = progress,
                isOngoing = status == "running" || status == "pending"
            )

            notificationManager?.notify(notificationId, notification.build())
            result.success(true)
        } catch (e: Exception) {
            result.error("UPDATE_FAILED", e.message, null)
        }
    }

    private fun handleEndNotification(call: MethodCall, result: Result) {
        try {
            val jobId = call.argument<String>("jobId")
            val finalProgress = call.argument<Int>("finalProgress") ?: 100
            val finalStatus = call.argument<String>("finalStatus") ?: "completed"
            val message = call.argument<String>("message")
            val resultUrl = call.argument<String>("resultUrl")
            val errorMessage = call.argument<String>("errorMessage")
            val dismissAfter = call.argument<Long>("dismissAfter") ?: 5000L

            if (jobId == null) {
                result.error("INVALID_ARGS", "Missing jobId argument", null)
                return
            }

            val notificationId = activeNotifications[jobId]
            if (notificationId == null) {
                result.success(false)
                return
            }

            // Build final notification
            val displayMessage = when (finalStatus) {
                "completed" -> message ?: "Completed successfully"
                "failed" -> errorMessage ?: message ?: "Failed"
                "cancelled" -> "Cancelled"
                else -> message ?: "Done"
            }

            val notification = buildFinalNotification(
                title = when (finalStatus) {
                    "completed" -> "Complete"
                    "failed" -> "Failed"
                    "cancelled" -> "Cancelled"
                    else -> "Done"
                },
                message = displayMessage,
                isSuccess = finalStatus == "completed"
            )

            notificationManager?.notify(notificationId, notification.build())

            // Schedule auto-dismiss
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                notificationManager?.cancel(notificationId)
                activeNotifications.remove(jobId)
            }, dismissAfter)

            result.success(true)
        } catch (e: Exception) {
            result.error("END_FAILED", e.message, null)
        }
    }

    private fun handleCancelNotification(call: MethodCall, result: Result) {
        try {
            val jobId = call.argument<String>("jobId")
            if (jobId == null) {
                result.error("INVALID_ARGS", "Missing jobId argument", null)
                return
            }

            val notificationId = activeNotifications[jobId]
            if (notificationId != null) {
                notificationManager?.cancel(notificationId)
                activeNotifications.remove(jobId)
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("CANCEL_FAILED", e.message, null)
        }
    }

    private fun handleIsNotificationActive(call: MethodCall, result: Result) {
        val jobId = call.argument<String>("jobId")
        if (jobId == null) {
            result.error("INVALID_ARGS", "Missing jobId argument", null)
            return
        }
        result.success(activeNotifications.containsKey(jobId))
    }

    private fun handleCancelAllNotifications(result: Result) {
        try {
            activeNotifications.values.forEach { notificationId ->
                notificationManager?.cancel(notificationId)
            }
            activeNotifications.clear()
            result.success(true)
        } catch (e: Exception) {
            result.error("CANCEL_ALL_FAILED", e.message, null)
        }
    }

    private fun buildProgressNotification(
        title: String,
        message: String,
        progress: Int,
        isOngoing: Boolean
    ): NotificationCompat.Builder {
        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_popup_sync)
            .setContentTitle(title)
            .setContentText(message)
            .setProgress(100, progress, false)
            .setOngoing(isOngoing)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setAutoCancel(!isOngoing)
    }

    private fun buildFinalNotification(
        title: String,
        message: String,
        isSuccess: Boolean
    ): NotificationCompat.Builder {
        val iconRes = if (isSuccess) {
            android.R.drawable.ic_dialog_info
        } else {
            android.R.drawable.ic_dialog_alert
        }

        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(iconRes)
            .setContentTitle(title)
            .setContentText(message)
            .setOngoing(false)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
    }

    private fun buildDisplayMessage(
        message: String?,
        stageName: String?,
        stageIndex: Int?,
        stageTotal: Int?,
        estimatedEndTime: Long?
    ): String {
        val parts = mutableListOf<String>()

        // Add stage info if available
        if (stageName != null && stageIndex != null && stageTotal != null) {
            parts.add("$stageName ($stageIndex/$stageTotal)")
        } else if (message != null) {
            parts.add(message)
        }

        // Add ETA if available
        if (estimatedEndTime != null) {
            val now = System.currentTimeMillis() / 1000
            val remaining = estimatedEndTime - now
            if (remaining > 0) {
                val minutes = remaining / 60
                val seconds = remaining % 60
                if (minutes > 0) {
                    parts.add("~${minutes}m ${seconds}s remaining")
                } else {
                    parts.add("~${seconds}s remaining")
                }
            }
        }

        return parts.joinToString(" - ").ifEmpty { "Processing..." }
    }
}
