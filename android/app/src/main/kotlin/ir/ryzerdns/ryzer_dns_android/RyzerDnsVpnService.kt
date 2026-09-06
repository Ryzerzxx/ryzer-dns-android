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
                "RyzerDNS Service",
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
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentIntent(pendingIntent)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("RyzerDNS فعال است")
                .setContentText("مسیرهای شبکه و دسترسی به بازی‌ها بهینه‌سازی شد")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentIntent(pendingIntent)
                .build()
        }

        startForeground(1001, notification)

        try {
            val builder = Builder()
                .setSession("RyzerDNS")
                .addAddress("10.254.1.2", 30)
                .addDnsServer(primaryDns)
                .addDnsServer(secondaryDns)
                // Route specific DNS IP destinations only (Zero game/download traffic touched!)
                .addRoute(primaryDns, 32)
                .addRoute(secondaryDns, 32)
                .addRoute("1.1.1.1", 32)
                .addRoute("8.8.8.8", 32)
                .setMtu(1500)
                .setBlocking(true)

            vpnInterface = builder.establish()
            isRunning = true
            startDnsForwardLoop(primaryDns, secondaryDns)
            Log.i(TAG, "RyzerDNS local TUN interface established.")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to establish VPN: ${e.message}")
            stopSelf()
        }
    }

    private fun startDnsForwardLoop(primaryDns: String, secondaryDns: String) {
        workerThread = Thread {
            val pfd = vpnInterface ?: return@Thread
            val inputStream = FileInputStream(pfd.fileDescriptor)
            val outputStream = FileOutputStream(pfd.fileDescriptor)
            val packet = ByteArray(32768)

            var socket: DatagramSocket? = null
            try {
                socket = DatagramSocket()
                protect(socket)
                socket.soTimeout = 2500
                val primaryAddr = InetAddress.getByName(primaryDns)
                val secondaryAddr = InetAddress.getByName(secondaryDns)

                while (isRunning) {
                    val length = inputStream.read(packet)
                    if (length <= 0) {
                        Thread.sleep(5)
                        continue
                    }

                    // Check if IPv4 (version 4)
                    val version = (packet[0].toInt() shr 4) and 0x0F
                    if (version != 4) continue

                    val ipHeaderLen = (packet[0].toInt() and 0x0F) * 4
                    val protocol = packet[9].toInt() and 0xFF

                    if (protocol == 17 && length >= ipHeaderLen + 8) { // UDP
                        val dstPort = ((packet[ipHeaderLen + 2].toInt() and 0xFF) shl 8) or (packet[ipHeaderLen + 3].toInt() and 0xFF)
                        if (dstPort == 53) {
                            val udpLen = ((packet[ipHeaderLen + 4].toInt() and 0xFF) shl 8) or (packet[ipHeaderLen + 5].toInt() and 0xFF)
                            val dnsLen = udpLen - 8
                            if (dnsLen > 0 && ipHeaderLen + 8 + dnsLen <= length) {
                                val dnsPayload = ByteArray(dnsLen)
                                System.arraycopy(packet, ipHeaderLen + 8, dnsPayload, 0, dnsLen)

                                // Forward to RyzerDNS primary (fallback secondary)
                                val outPacket = DatagramPacket(dnsPayload, dnsPayload.size, primaryAddr, 53)
                                try {
                                    socket.send(outPacket)
                                } catch (e: Exception) {
                                    try {
                                        outPacket.address = secondaryAddr
                                        socket.send(outPacket)
                                    } catch (_: Exception) {}
                                }

                                val recvBuffer = ByteArray(4096)
                                val inPacket = DatagramPacket(recvBuffer, recvBuffer.size)
                                try {
                                    socket.receive(inPacket)
                                    val replyPacket = buildReplyUdpPacket(packet, ipHeaderLen, inPacket.data, inPacket.length)
                                    outputStream.write(replyPacket)
                                } catch (_: Exception) {}
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "DNS Loop exception: ${e.message}")
            } finally {
                socket?.close()
            }
        }.apply { start() }
    }

    private fun buildReplyUdpPacket(original: ByteArray, ipHeaderLen: Int, dnsPayload: ByteArray, dnsPayloadLen: Int): ByteArray {
        val totalLen = ipHeaderLen + 8 + dnsPayloadLen
        val reply = ByteArray(totalLen)

        // Copy IP Header
        System.arraycopy(original, 0, reply, 0, ipHeaderLen)

        // Swap IP source and destination (Original: Src 12..15, Dst 16..19)
        System.arraycopy(original, 16, reply, 12, 4)
        System.arraycopy(original, 12, reply, 16, 4)

        // Set Total Length in IPv4 Header
        reply[2] = ((totalLen shr 8) and 0xFF).toByte()
        reply[3] = (totalLen and 0xFF).toByte()

        // Reset TTL
        reply[8] = 64

        // Clear checksum before computing
        reply[10] = 0
        reply[11] = 0

        // Compute valid IPv4 Header Checksum!
        val ipChecksum = computeIpChecksum(reply, ipHeaderLen)
        reply[10] = ((ipChecksum shr 8) and 0xFF).toByte()
        reply[11] = (ipChecksum and 0xFF).toByte()

        // UDP Header: Swap ports
        reply[ipHeaderLen] = original[ipHeaderLen + 2]
        reply[ipHeaderLen + 1] = original[ipHeaderLen + 3]
        reply[ipHeaderLen + 2] = original[ipHeaderLen]
        reply[ipHeaderLen + 3] = original[ipHeaderLen + 1]

        val udpLen = 8 + dnsPayloadLen
        reply[ipHeaderLen + 4] = ((udpLen shr 8) and 0xFF).toByte()
        reply[ipHeaderLen + 5] = (udpLen and 0xFF).toByte()
        reply[ipHeaderLen + 6] = 0 // UDP checksum optional in IPv4
        reply[ipHeaderLen + 7] = 0

        // Copy DNS Answer Payload
        System.arraycopy(dnsPayload, 0, reply, ipHeaderLen + 8, dnsPayloadLen)
        return reply
    }

    private fun computeIpChecksum(header: ByteArray, length: Int): Int {
        var sum = 0
        var i = 0
        while (i < length) {
            val high = header[i].toInt() and 0xFF
            val low = if (i + 1 < length) header[i + 1].toInt() and 0xFF else 0
            sum += (high shl 8) or low
            i += 2
        }
        while ((sum shr 16) > 0) {
            sum = (sum and 0xFFFF) + (sum shr 16)
        }
        return (sum.inv()) and 0xFFFF
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
