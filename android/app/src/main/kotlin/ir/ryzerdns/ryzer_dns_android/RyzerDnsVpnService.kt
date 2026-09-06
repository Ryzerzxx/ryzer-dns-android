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
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.nio.ByteBuffer

class RyzerDnsVpnService : VpnService() {

    private var vpnInterface: ParcelFileDescriptor? = null
    private var isRunning = false
    private var workerThread: Thread? = null

    companion object {
        const val ACTION_START = "ir.ryzerdns.START_VPN"
        const val ACTION_STOP = "ir.ryzerdns.STOP_VPN"
        const val CHANNEL_ID = "ryzer_dns_service"
        private const val TAG = "RyzerDnsVpnService"
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val primaryDns = intent.getStringExtra("primary_dns") ?: "87.248.145.40"
                val secondaryDns = intent.getStringExtra("secondary_dns") ?: "46.8.102.223"
                startDnsVpn(primaryDns, secondaryDns)
            }
            ACTION_STOP -> {
                stopDnsVpn()
            }
        }
        return START_NOT_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "RyzerDNS Protection",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun startDnsVpn(primaryDns: String, secondaryDns: String) {
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
                .setContentText("مسیرهای شبکه و دسترسی به بازی‌ها بهینه‌سازی شد")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentIntent(pendingIntent)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("RyzerDNS فعال است")
                .setContentText("مسیرهای شبکه و دسترسی به بازی‌ها بهینه‌سازی شد")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentIntent(pendingIntent)
                .build()
        }

        startForeground(1001, notification)

        try {
            val builder = Builder()
                .setSession("RyzerDNS")
                .addAddress("10.254.1.1", 32)
                .addDnsServer(primaryDns)
                .addDnsServer(secondaryDns)
                // ⚡ Only intercept DNS port 53 / DNS IPs! Zero game traffic intercept!
                .addRoute(primaryDns, 32)
                .addRoute(secondaryDns, 32)
                .setMtu(1500)
                .setBlocking(false)

            vpnInterface = builder.establish()
            isRunning = true
            startDnsForwardLoop(primaryDns)
            Log.i(TAG, "RyzerDNS local TUN interface established.")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to establish VPN: ${e.message}")
            stopSelf()
        }
    }

    private fun startDnsForwardLoop(dnsServer: String) {
        workerThread = Thread {
            val pfd = vpnInterface ?: return@Thread
            val `in` = FileInputStream(pfd.fileDescriptor)
            val out = FileOutputStream(pfd.fileDescriptor)
            val packet = ByteBuffer.allocate(32768)

            var socket: DatagramSocket? = null
            try {
                socket = DatagramSocket()
                protect(socket) // Ensure upstream socket bypasses local VPN loop!
                socket.soTimeout = 2000
                val targetAddr = InetAddress.getByName(dnsServer)

                while (isRunning) {
                    packet.clear()
                    val length = `in`.read(packet.array())
                    if (length > 0) {
                        packet.limit(length)
                        // Extract UDP payload if destination port is 53
                        val ipHeaderLen = (packet.get(0).toInt() and 0x0F) * 4
                        val protocol = packet.get(9).toInt()

                        if (protocol == 17 && length > ipHeaderLen + 8) { // UDP
                            val dstPort = (packet.getShort(ipHeaderLen + 2).toInt() and 0xFFFF)
                            if (dstPort == 53) {
                                val udpPayloadLen = (packet.getShort(ipHeaderLen + 4).toInt() and 0xFFFF) - 8
                                val dnsData = ByteArray(udpPayloadLen)
                                System.arraycopy(packet.array(), ipHeaderLen + 8, dnsData, 0, udpPayloadLen)

                                val outPacket = DatagramPacket(dnsData, dnsData.size, targetAddr, 53)
                                socket.send(outPacket)

                                val inPacket = DatagramPacket(ByteArray(4096), 4096)
                                try {
                                    socket.receive(inPacket)
                                    // Reconstruct reply packet
                                    val replyPacket = buildReplyUdpPacket(packet.array(), inPacket.data, inPacket.length)
                                    out.write(replyPacket)
                                } catch (_: Exception) {}
                            }
                        }
                    } else {
                        Thread.sleep(10)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "DNS Loop error: ${e.message}")
            } finally {
                socket?.close()
            }
        }.apply { start() }
    }

    private fun buildReplyUdpPacket(original: ByteArray, dnsPayload: ByteArray, payloadLen: Int): ByteArray {
        val ipLen = (original[0].toInt() and 0x0F) * 4
        val totalLen = ipLen + 8 + payloadLen
        val reply = ByteArray(totalLen)

        // Copy original IP header
        System.arraycopy(original, 0, reply, 0, ipLen)

        // Swap src and dst IP
        System.arraycopy(original, 16, reply, 12, 4) // Dst becomes Src
        System.arraycopy(original, 12, reply, 16, 4) // Src becomes Dst

        // Total Length
        reply[2] = ((totalLen shr 8) and 0xFF).toByte()
        reply[3] = (totalLen and 0xFF).toByte()
        reply[10] = 0 // Checksum reset
        reply[11] = 0

        // UDP Header
        // Swap ports
        reply[ipLen] = original[ipLen + 2]
        reply[ipLen + 1] = original[ipLen + 3]
        reply[ipLen + 2] = original[ipLen]
        reply[ipLen + 3] = original[ipLen + 1]

        val udpLen = 8 + payloadLen
        reply[ipLen + 4] = ((udpLen shr 8) and 0xFF).toByte()
        reply[ipLen + 5] = (udpLen and 0xFF).toByte()
        reply[ipLen + 6] = 0
        reply[ipLen + 7] = 0

        // Payload
        System.arraycopy(dnsPayload, 0, reply, ipLen + 8, payloadLen)
        return reply
    }

    private fun stopDnsVpn() {
        isRunning = false
        workerThread?.interrupt()
        try {
            vpnInterface?.close()
            vpnInterface = null
        } catch (_: Exception) {}
        stopForeground(true)
        stopSelf()
        Log.i(TAG, "RyzerDNS VPN Stopped.")
    }

    override fun onDestroy() {
        stopDnsVpn()
        super.onDestroy()
    }
}
