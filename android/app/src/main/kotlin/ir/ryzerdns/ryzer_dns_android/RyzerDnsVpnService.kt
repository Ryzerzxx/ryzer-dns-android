package ir.ryzerdns.ryzer_dns_android

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log

class RyzerDnsVpnService : VpnService() {

    private var vpnInterface: ParcelFileDescriptor? = null

    companion object {
        const val ACTION_START = "ir.ryzerdns.START_VPN"
        const val ACTION_STOP = "ir.ryzerdns.STOP_VPN"
        const val CHANNEL_ID = "ryzer_dns_service"
        private const val TAG = "RyzerDnsVpnService"
        var isRunning = false
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val primaryDns = intent.getStringExtra("primary_dns") ?: "87.248.145.40"
                val secondaryDns = intent.getStringExtra("secondary_dns") ?: "46.8.102.223"
                startDns(primaryDns, secondaryDns)
            }
            ACTION_STOP -> {
                stopDns()
            }
        }
        return START_NOT_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "RyzerDNS Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun startDns(primaryDns: String, secondaryDns: String) {
        if (isRunning) return

        createNotificationChannel()
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        val notification: Notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("RyzerDNS فعال است")
                .setContentText("مسیرهای شبکه و بازی‌ها بهینه‌سازی شد")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentIntent(pendingIntent)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("RyzerDNS فعال است")
                .setContentText("مسیرهای شبکه و بازی‌ها بهینه‌سازی شد")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentIntent(pendingIntent)
                .build()
        }

        startForeground(1001, notification)

        try {
            val builder = Builder()
            builder.setSession("RyzerDNS")
                .addAddress("10.0.0.2", 24)

            // Set Primary DNS
            builder.addDnsServer(primaryDns)
            Log.d(TAG, "Primary DNS set to: $primaryDns")

            // Set Secondary DNS
            builder.addDnsServer(secondaryDns)
            Log.d(TAG, "Secondary DNS set to: $secondaryDns")

            // Disallow our own app to prevent loops
            try {
                builder.addDisallowedApplication(packageName)
            } catch (e: Exception) {
                Log.w(TAG, "Could not add disallowed application: ${e.message}")
            }

            // Allow apps to access internet directly
            builder.allowBypass()

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                try {
                    builder.setMetered(false)
                } catch (_: Throwable) {}
            }

            vpnInterface?.close()
            vpnInterface = builder.establish()
            isRunning = true

            Log.i(TAG, "RyzerDNS Native Android DNS Engine successfully established with [$primaryDns, $secondaryDns]")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to establish Native DNS: ${e.message}")
            stopDns()
        }
    }

    private fun stopDns() {
        try {
            vpnInterface?.close()
            vpnInterface = null
        } catch (_: Exception) {}
        isRunning = false
        stopForeground(true)
        stopSelf()
        Log.i(TAG, "RyzerDNS Service Stopped.")
    }

    override fun onDestroy() {
        stopDns()
        super.onDestroy()
    }
}
