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
import java.util.concurrent.ConcurrentHashMap

class RyzerDnsVpnService : VpnService() {

    private var vpnInterface: ParcelFileDescriptor? = null
    @Volatile
    private var isRunning = false
    private var tunReaderThread: Thread? = null
    private var udpReceiverThread: Thread? = null
    private var dnsSocket: DatagramSocket? = null

    // Map DNS Transaction ID -> Client Source Port to route replies accurately
    private val pendingQueries = ConcurrentHashMap<Int, Int>()

    companion object {
        const val ACTION_START = "ir.ryzerdns.START_VPN"
        const val ACTION_STOP = "ir.ryzerdns.STOP_VPN"
        const val CHANNEL_ID = "ryzer_dns_service"
        private const val TAG = "RyzerDnsVpnService"
        const val VIRTUAL_DNS_IP = "10.254.1.1"
        const val LOCAL_CLIENT_IP = "10.254.1.2"
        const val VIRTUAL_DNS_IPV6 = "fd00::1"
        const val LOCAL_CLIENT_IPV6 = "fd00::2"
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
                .setSession("RyzerDNS")
                .addAddress(LOCAL_CLIENT_IP, 24)
                .addDnsServer(VIRTUAL_DNS_IP)
                .addRoute(VIRTUAL_DNS_IP, 32)
                .setMtu(1500)
                .setBlocking(true)

            // Prevent IPv6 DNS leaks: assign virtual IPv6 DNS so system doesn't query carrier IPv6 resolvers
            try {
                builder.addAddress(LOCAL_CLIENT_IPV6, 120)
                builder.addDnsServer(VIRTUAL_DNS_IPV6)
                builder.addRoute(VIRTUAL_DNS_IPV6, 128)
            } catch (e: Throwable) {
                Log.w(TAG, "IPv6 setup skipped: ${e.message}")
            }

            // CRITICAL: allowBypass() allows all non-DNS system apps & games to directly reach the internet!
            builder.allowBypass()

            // Allow standard IP families
            try {
                builder.allowFamily(android.system.OsConstants.AF_INET)
                builder.allowFamily(android.system.OsConstants.AF_INET6)
            } catch (_: Throwable) {}

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                try { builder.setMetered(false) } catch (_: Throwable) {}
            }

            vpnInterface = builder.establish()
            isRunning = true

            startAsynchronousDnsRelay(primaryDns, secondaryDns)
            Log.i(TAG, "RyzerDNS asynchronous TUN relay established on $VIRTUAL_DNS_IP")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to establish VPN: ${e.message}")
            stopSelf()
        }
    }

    private fun startAsynchronousDnsRelay(primaryDns: String, secondaryDns: String) {
        val pfd = vpnInterface ?: return
        val inputStream = FileInputStream(pfd.fileDescriptor)
        val outputStream = FileOutputStream(pfd.fileDescriptor)

        try {
            val socket = DatagramSocket()
            protect(socket)
            socket.soTimeout = 0 // Never timeout the receiver thread!
            dnsSocket = socket

            val primaryAddr = InetAddress.getByName(primaryDns)
            val secondaryAddr = InetAddress.getByName(secondaryDns)

            // Thread 1: Read TUN queries from Android OS -> Forward to Upstream
            tunReaderThread = Thread {
                val packet = ByteArray(32768)
                while (isRunning) {
                    try {
                        val length = inputStream.read(packet)
                        if (length <= 0) {
                            Thread.sleep(2)
                            continue
                        }

                        val version = (packet[0].toInt() shr 4) and 0x0F
                        if (version != 4 && version != 6) continue

                        if (version == 6) {
                            // If Android OS sends IPv6 DNS query to fd00::1, consume & ignore to force instant IPv4 fallback
                            continue
                        }

                        val ipHeaderLen = (packet[0].toInt() and 0x0F) * 4
                        val protocol = packet[9].toInt() and 0xFF

                        // UDP packet check
                        if (protocol == 17 && length >= ipHeaderLen + 8) {
                            val srcPort = ((packet[ipHeaderLen].toInt() and 0xFF) shl 8) or (packet[ipHeaderLen + 1].toInt() and 0xFF)
                            val dstPort = ((packet[ipHeaderLen + 2].toInt() and 0xFF) shl 8) or (packet[ipHeaderLen + 3].toInt() and 0xFF)

                            if (dstPort == 53) {
                                val udpLen = ((packet[ipHeaderLen + 4].toInt() and 0xFF) shl 8) or (packet[ipHeaderLen + 5].toInt() and 0xFF)
                                val dnsLen = udpLen - 8
                                if (dnsLen >= 12 && ipHeaderLen + 8 + dnsLen <= length) {
                                    val dnsPayload = ByteArray(dnsLen)
                                    System.arraycopy(packet, ipHeaderLen + 8, dnsPayload, 0, dnsLen)

                                    // Extract 16-bit DNS Transaction ID
                                    val txId = ((dnsPayload[0].toInt() and 0xFF) shl 8) or (dnsPayload[1].toInt() and 0xFF)
                                    pendingQueries[txId] = srcPort

                                    // Send out to Primary Upstream Server
                                    val outPacket = DatagramPacket(dnsPayload, dnsPayload.size, primaryAddr, 53)
                                    try {
                                        socket.send(outPacket)
                                    } catch (_: Exception) {
                                        try {
                                            outPacket.address = secondaryAddr
                                            socket.send(outPacket)
                                        } catch (_: Exception) {}
                                    }
                                }
                            }
                        }
                    } catch (e: Exception) {
                        if (!isRunning) break
                    }
                }
            }.apply { start() }

            // Thread 2: Receive upstream DNS replies -> Inject back into TUN
            udpReceiverThread = Thread {
                val recvBuffer = ByteArray(4096)
                while (isRunning) {
                    try {
                        val inPacket = DatagramPacket(recvBuffer, recvBuffer.size)
                        socket.receive(inPacket)

                        val payloadLen = inPacket.length
                        if (payloadLen >= 12) {
                            val data = inPacket.data
                            val txId = ((data[0].toInt() and 0xFF) shl 8) or (data[1].toInt() and 0xFF)
                            val clientPort = pendingQueries.remove(txId) ?: 53

                            val replyPacket = buildReplyUdpPacket(data, payloadLen, clientPort)
                            synchronized(outputStream) {
                                outputStream.write(replyPacket)
                            }
                        }
                    } catch (e: Exception) {
                        if (!isRunning) break
                    }
                }
            }.apply { start() }

        } catch (e: Exception) {
            Log.e(TAG, "Relay setup failed: ${e.message}")
        }
    }

    private fun buildReplyUdpPacket(dnsPayload: ByteArray, dnsPayloadLen: Int, clientPort: Int): ByteArray {
        val ipHeaderLen = 20
        val udpHeaderLen = 8
        val totalLen = ipHeaderLen + udpHeaderLen + dnsPayloadLen
        val packet = ByteArray(totalLen)

        // 1. IPv4 Header
        packet[0] = 0x45.toByte() // Version 4, IHL 5 (20 bytes)
        packet[1] = 0x00.toByte() // DSCP/ECN
        packet[2] = ((totalLen shr 8) and 0xFF).toByte()
        packet[3] = (totalLen and 0xFF).toByte()
        packet[4] = 0x00.toByte() // Identification
        packet[5] = 0x00.toByte()
        packet[6] = 0x40.toByte() // Don't fragment
        packet[7] = 0x00.toByte()
        packet[8] = 64.toByte()   // TTL
        packet[9] = 17.toByte()   // Protocol: UDP (17)
        packet[10] = 0x00.toByte() // Checksum placeholder
        packet[11] = 0x00.toByte()

        // Source IP: 10.254.1.1 (Virtual DNS)
        packet[12] = 10.toByte()
        packet[13] = 254.toByte()
        packet[14] = 1.toByte()
        packet[15] = 1.toByte()

        // Destination IP: 10.254.1.2 (Client TUN)
        packet[16] = 10.toByte()
        packet[17] = 254.toByte()
        packet[18] = 1.toByte()
        packet[19] = 2.toByte()

        // IPv4 Header Checksum
        val ipChecksum = computeIpChecksum(packet, ipHeaderLen)
        packet[10] = ((ipChecksum shr 8) and 0xFF).toByte()
        packet[11] = (ipChecksum and 0xFF).toByte()

        // 2. UDP Header
        // Source Port: 53
        packet[20] = 0x00.toByte()
        packet[21] = 53.toByte()

        // Destination Port: clientPort
        packet[22] = ((clientPort shr 8) and 0xFF).toByte()
        packet[23] = (clientPort and 0xFF).toByte()

        // UDP Length
        val udpLen = udpHeaderLen + dnsPayloadLen
        packet[24] = ((udpLen shr 8) and 0xFF).toByte()
        packet[25] = (udpLen and 0xFF).toByte()

        // 3. DNS Payload
        System.arraycopy(dnsPayload, 0, packet, ipHeaderLen + udpHeaderLen, dnsPayloadLen)

        // Compute valid UDP Checksum with IPv4 Pseudo Header
        val udpChecksum = computeUdpChecksum(packet, ipHeaderLen, udpHeaderLen, dnsPayloadLen)
        packet[26] = ((udpChecksum shr 8) and 0xFF).toByte()
        packet[27] = (udpChecksum and 0xFF).toByte()

        return packet
    }

    private fun computeUdpChecksum(packet: ByteArray, ipHeaderLen: Int, udpHeaderLen: Int, payloadLen: Int): Int {
        val udpLen = udpHeaderLen + payloadLen
        var sum = 0

        // Pseudo Header: Source IP (12..15)
        sum += ((packet[12].toInt() and 0xFF) shl 8) or (packet[13].toInt() and 0xFF)
        sum += ((packet[14].toInt() and 0xFF) shl 8) or (packet[15].toInt() and 0xFF)

        // Pseudo Header: Destination IP (16..19)
        sum += ((packet[16].toInt() and 0xFF) shl 8) or (packet[17].toInt() and 0xFF)
        sum += ((packet[18].toInt() and 0xFF) shl 8) or (packet[19].toInt() and 0xFF)

        // Protocol (17) + UDP Length
        sum += 17
        sum += udpLen

        // UDP Header: Ports + Length
        sum += ((packet[20].toInt() and 0xFF) shl 8) or (packet[21].toInt() and 0xFF)
        sum += ((packet[22].toInt() and 0xFF) shl 8) or (packet[23].toInt() and 0xFF)
        sum += udpLen

        // DNS Payload 16-bit words
        val payloadStart = ipHeaderLen + udpHeaderLen
        var i = 0
        while (i < payloadLen) {
            val high = packet[payloadStart + i].toInt() and 0xFF
            val low = if (i + 1 < payloadLen) packet[payloadStart + i + 1].toInt() and 0xFF else 0
            sum += (high shl 8) or low
            i += 2
        }

        while ((sum shr 16) > 0) {
            sum = (sum and 0xFFFF) + (sum shr 16)
        }

        val res = (sum.inv()) and 0xFFFF
        return if (res == 0) 0xFFFF else res
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
        tunReaderThread?.interrupt()
        udpReceiverThread?.interrupt()
        try {
            dnsSocket?.close()
            dnsSocket = null
        } catch (_: Exception) {}
        try {
            vpnInterface?.close()
            vpnInterface = null
        } catch (_: Exception) {}
        pendingQueries.clear()
        stopForeground(true)
        stopSelf()
        Log.i(TAG, "RyzerDNS VPN Stopped.")
    }

    override fun onDestroy() {
        stopDnsVpn()
        super.onDestroy()
    }
}
