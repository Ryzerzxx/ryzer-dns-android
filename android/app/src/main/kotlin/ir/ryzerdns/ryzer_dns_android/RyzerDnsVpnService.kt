package ir.ryzerdns.ryzer_dns_android

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket
import java.security.SecureRandom
import java.security.cert.X509Certificate
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLSocket
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager

class RyzerDnsVpnService : VpnService() {

    private var vpnInterface: ParcelFileDescriptor? = null
    private var dohWorkerThread: Thread? = null
    private val isDohRunning = AtomicBoolean(false)
    private val threadPool = Executors.newFixedThreadPool(8)
    private val encryptedDnsClient = EncryptedDnsClient()

    private val targetServerIp = byteArrayOf(87.toByte(), 248.toByte(), 145.toByte(), 40.toByte())

    private val trustAllCerts = object : X509TrustManager {
        override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
        override fun checkClientTrusted(certs: Array<X509Certificate>, authType: String) {}
        override fun checkServerTrusted(certs: Array<X509Certificate>, authType: String) {}
    }

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
                val secondaryDns = intent.getStringExtra("secondary_dns") ?: "143.20.60.94"
                val enableDoh = intent.getBooleanExtra("enable_doh", false)
                startDns(primaryDns, secondaryDns, enableDoh)
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

    private fun startDns(primaryDns: String, secondaryDns: String, enableDoh: Boolean) {
        if (isRunning) {
            stopDns()
        }

        createNotificationChannel()
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        val title = if (enableDoh) "اتصال فوق‌العاده RyzerDNS فعال است" else "RyzerDNS فعال است"
        val subtitle = if (enableDoh) "پروتکل رمزنگاری‌شده DoH / DoT فعال شد" else "مسیرهای شبکه و بازی‌ها بهینه‌سازی شد"

        val notification: Notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle(title)
                .setContentText(subtitle)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentIntent(pendingIntent)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle(title)
                .setContentText(subtitle)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentIntent(pendingIntent)
                .build()
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                if (Build.VERSION.SDK_INT >= 34) { // Android 14+
                    startForeground(1001, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED)
                } else {
                    startForeground(1001, notification)
                }
            } catch (e: Exception) {
                Log.w(TAG, "Fallback startForeground: ${e.message}")
                startForeground(1001, notification)
            }
        } else {
            startForeground(1001, notification)
        }

        try {
            val builder = Builder()
            builder.setSession(if (enableDoh) "RyzerDNS-Ultra" else "RyzerDNS")
            builder.setMtu(1500)

            if (enableDoh) {
                // Intercept DNS on virtual remote address 10.111.222.2 (subnet /30)
                // Interface address: 10.111.222.1
                builder.addAddress("10.111.222.1", 30)
                builder.addDnsServer("10.111.222.2")
                builder.addRoute("10.111.222.2", 32)
                Log.i(TAG, "Configuring Ultra Connection (Virtual DNS: 10.111.222.2 -> DoT/DoH)")
            } else {
                builder.addAddress("10.0.0.2", 24)
                builder.addDnsServer(primaryDns)
                builder.addDnsServer(secondaryDns)
                Log.d(TAG, "Configuring Standard DNS: [$primaryDns, $secondaryDns]")
            }

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
            val pfd = builder.establish()
            vpnInterface = pfd
            isRunning = true

            if (enableDoh && pfd != null) {
                startDohWorker(pfd)
            }

            Log.i(TAG, "RyzerDNS Engine successfully established (enableDoh=$enableDoh)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to establish VPN: ${e.message}")
            stopDns()
        }
    }

    private fun startDohWorker(pfd: ParcelFileDescriptor) {
        isDohRunning.set(true)
        val inStream = FileInputStream(pfd.fileDescriptor)
        val outStream = FileOutputStream(pfd.fileDescriptor)

        dohWorkerThread = Thread {
            val packet = ByteArray(32768)
            Log.i(TAG, "DoH TUN Reader thread started")

            while (isDohRunning.get()) {
                try {
                    val length = inStream.read(packet)
                    if (length <= 0) break

                    // IPv4 verification
                    val version = (packet[0].toInt() shr 4) and 0x0F
                    if (version != 4) continue

                    val ihl = (packet[0].toInt() and 0x0F) * 4
                    if (length < ihl + 8) continue

                    val protocol = packet[9].toInt() and 0xFF
                    if (protocol != 17) continue // UDP only

                    val srcPort = ((packet[ihl].toInt() and 0xFF) shl 8) or (packet[ihl + 1].toInt() and 0xFF)
                    val dstPort = ((packet[ihl + 2].toInt() and 0xFF) shl 8) or (packet[ihl + 3].toInt() and 0xFF)
                    if (dstPort != 53) continue

                    val udpLen = ((packet[ihl + 4].toInt() and 0xFF) shl 8) or (packet[ihl + 5].toInt() and 0xFF)
                    val dnsPayloadLen = udpLen - 8
                    if (dnsPayloadLen <= 0 || ihl + 8 + dnsPayloadLen > length) continue

                    // Extract IPs & Ports into dedicated byte arrays
                    val clientIp = ByteArray(4)
                    System.arraycopy(packet, 12, clientIp, 0, 4)
                    val dnsServerIp = ByteArray(4)
                    System.arraycopy(packet, 16, dnsServerIp, 0, 4)

                    val dnsQuery = ByteArray(dnsPayloadLen)
                    System.arraycopy(packet, ihl + 8, dnsQuery, 0, dnsPayloadLen)

                    // Process DNS asynchronously in threadPool
                    threadPool.execute {
                        try {
                            val dnsResp = encryptedDnsClient.query(dnsQuery)
                            if (dnsResp != null && dnsResp.isNotEmpty()) {
                                // In the reply packet:
                                // srcIp is dnsServerIp (10.111.222.2), srcPort is 53
                                // dstIp is clientIp (10.111.222.1), dstPort is srcPort (client's port)
                                val replyPacket = buildIpv4UdpPacket(dnsServerIp, clientIp, 53, srcPort, dnsResp)
                                synchronized(outStream) {
                                    outStream.write(replyPacket)
                                    outStream.flush()
                                }
                            }
                        } catch (e: Exception) {
                            Log.w(TAG, "Error handling DNS query: ${e.message}")
                        }
                    }
                } catch (e: Exception) {
                    if (!isDohRunning.get()) break
                    Log.w(TAG, "TUN read error: ${e.message}")
                }
            }
            Log.i(TAG, "DoH TUN Reader thread stopped")
        }.apply {
            name = "RyzerDnsDoHWorker"
            isDaemon = true
            start()
        }
    }

    inner class EncryptedDnsClient {
        private var currentSocket: SSLSocket? = null
        private val lock = Any()

        private fun getOrCreateSocket(): SSLSocket? {
            synchronized(lock) {
                if (currentSocket != null && currentSocket?.isConnected == true && currentSocket?.isClosed == false) {
                    return currentSocket
                }
                try {
                    currentSocket?.close()
                } catch (_: Exception) {}
                currentSocket = null

                try {
                    val serverAddr = InetAddress.getByAddress(targetServerIp)
                    val sslContext = SSLContext.getInstance("TLS")
                    sslContext.init(null, arrayOf<TrustManager>(trustAllCerts), SecureRandom())

                    // 1. Create standard plain socket and protect it
                    val plainSocket = Socket()
                    val protectedSuccess = protect(plainSocket)
                    Log.d(TAG, "Plain socket protect result: $protectedSuccess")

                    plainSocket.tcpNoDelay = true
                    plainSocket.soTimeout = 4000
                    plainSocket.connect(InetSocketAddress(serverAddr, 853), 2500)

                    // 2. Wrap connected socket with TLS
                    val sslSocket = sslContext.socketFactory.createSocket(
                        plainSocket,
                        "dns.ryzerdns.ir",
                        853,
                        true
                    ) as SSLSocket
                    sslSocket.soTimeout = 4000
                    sslSocket.startHandshake()

                    currentSocket = sslSocket
                    Log.i(TAG, "Encrypted DoT tunnel established successfully!")
                    return sslSocket
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to establish DoT tunnel: ${e.message}")
                    currentSocket = null
                    return null
                }
            }
        }

        fun query(dnsQuery: ByteArray): ByteArray? {
            // 1. Try over persistent DoT connection (port 853)
            for (attempt in 1..2) {
                val sock = getOrCreateSocket()
                if (sock != null) {
                    try {
                        synchronized(sock) {
                            val out = sock.outputStream
                            val inp = sock.inputStream

                            out.write((dnsQuery.size shr 8) and 0xFF)
                            out.write(dnsQuery.size and 0xFF)
                            out.write(dnsQuery)
                            out.flush()

                            val b1 = inp.read()
                            val b2 = inp.read()
                            if (b1 != -1 && b2 != -1) {
                                val respLen = (b1 shl 8) or b2
                                val respData = ByteArray(respLen)
                                var totalRead = 0
                                while (totalRead < respLen) {
                                    val r = inp.read(respData, totalRead, respLen - totalRead)
                                    if (r == -1) break
                                    totalRead += r
                                }
                                if (totalRead == respLen) {
                                    return respData
                                }
                            }
                        }
                    } catch (e: Exception) {
                        Log.d(TAG, "DoT query attempt $attempt failed: ${e.message}")
                        synchronized(lock) {
                            try { sock.close() } catch (_: Exception) {}
                            if (currentSocket == sock) currentSocket = null
                        }
                    }
                }
            }

            // 2. Fallback to HTTPS DoH (POST /dns-query on port 8445 with Host: ryzerdns.ir)
            try {
                val serverAddr = InetAddress.getByAddress(targetServerIp)
                val sslContext = SSLContext.getInstance("TLS")
                sslContext.init(null, arrayOf<TrustManager>(trustAllCerts), SecureRandom())

                val plainSocket = Socket()
                protect(plainSocket)
                plainSocket.tcpNoDelay = true
                plainSocket.soTimeout = 3000
                plainSocket.connect(InetSocketAddress(serverAddr, 8445), 2500)

                val sslSocket = sslContext.socketFactory.createSocket(
                    plainSocket,
                    "ryzerdns.ir",
                    8445,
                    true
                ) as SSLSocket
                sslSocket.soTimeout = 3000
                sslSocket.startHandshake()

                val out = sslSocket.outputStream
                val inp = sslSocket.inputStream

                val httpHeader = ("POST /dns-query HTTP/1.1\r\n" +
                    "Host: ryzerdns.ir\r\n" +
                    "Content-Type: application/dns-message\r\n" +
                    "Accept: application/dns-message\r\n" +
                    "Content-Length: ${dnsQuery.size}\r\n" +
                    "Connection: close\r\n\r\n").toByteArray(Charsets.US_ASCII)

                out.write(httpHeader)
                out.write(dnsQuery)
                out.flush()

                // Read until end of headers
                val headerBuf = ByteArray(2048)
                var hLen = 0
                var bodyFound = false
                while (hLen < headerBuf.size) {
                    val b = inp.read()
                    if (b == -1) break
                    headerBuf[hLen++] = b.toByte()
                    if (hLen >= 4 &&
                        headerBuf[hLen - 4] == 0x0D.toByte() && headerBuf[hLen - 3] == 0x0A.toByte() &&
                        headerBuf[hLen - 2] == 0x0D.toByte() && headerBuf[hLen - 1] == 0x0A.toByte()) {
                        bodyFound = true
                        break
                    }
                }

                if (bodyFound) {
                    val respBytes = inp.readBytes()
                    sslSocket.close()
                    if (respBytes.isNotEmpty()) {
                        return respBytes
                    }
                }
                sslSocket.close()
            } catch (e: Exception) {
                Log.d(TAG, "DoH fallback failed: ${e.message}")
            }

            return null
        }

        fun close() {
            synchronized(lock) {
                try {
                    currentSocket?.close()
                } catch (_: Exception) {}
                currentSocket = null
            }
        }
    }

    private fun buildIpv4UdpPacket(
        srcIp: ByteArray,
        dstIp: ByteArray,
        srcPort: Int,
        dstPort: Int,
        payload: ByteArray
    ): ByteArray {
        val totalLen = 20 + 8 + payload.size
        val packet = ByteArray(totalLen)

        // IPv4 Header (20 bytes)
        packet[0] = 0x45.toByte() // IPv4, IHL 5
        packet[1] = 0x00.toByte() // DSCP/ECN
        packet[2] = ((totalLen shr 8) and 0xFF).toByte()
        packet[3] = (totalLen and 0xFF).toByte()
        packet[4] = 0x12.toByte() // Identification
        packet[5] = 0x34.toByte()
        packet[6] = 0x40.toByte() // Don't fragment
        packet[7] = 0x00.toByte()
        packet[8] = 64.toByte()   // TTL
        packet[9] = 17.toByte()   // Protocol UDP = 17
        packet[10] = 0.toByte()   // Checksum placeholder
        packet[11] = 0.toByte()
        System.arraycopy(srcIp, 0, packet, 12, 4)
        System.arraycopy(dstIp, 0, packet, 16, 4)

        // Compute IP Header Checksum
        val ipChecksum = computeChecksum(packet, 0, 20)
        packet[10] = ((ipChecksum shr 8) and 0xFF).toByte()
        packet[11] = (ipChecksum and 0xFF).toByte()

        // UDP Header (8 bytes)
        packet[20] = ((srcPort shr 8) and 0xFF).toByte()
        packet[21] = (srcPort and 0xFF).toByte()
        packet[22] = ((dstPort shr 8) and 0xFF).toByte()
        packet[23] = (dstPort and 0xFF).toByte()
        val udpLen = 8 + payload.size
        packet[24] = ((udpLen shr 8) and 0xFF).toByte()
        packet[25] = (udpLen and 0xFF).toByte()
        packet[26] = 0.toByte()
        packet[27] = 0.toByte()

        // Payload
        System.arraycopy(payload, 0, packet, 28, payload.size)

        // Compute UDP Checksum (RFC 768)
        val udpChecksum = computeUdpChecksum(srcIp, dstIp, srcPort, dstPort, payload)
        packet[26] = ((udpChecksum shr 8) and 0xFF).toByte()
        packet[27] = (udpChecksum and 0xFF).toByte()

        return packet
    }

    private fun computeChecksum(data: ByteArray, offset: Int, length: Int): Int {
        var sum = 0
        var i = offset
        while (i < offset + length - 1) {
            val word = ((data[i].toInt() and 0xFF) shl 8) or (data[i + 1].toInt() and 0xFF)
            sum += word
            i += 2
        }
        if (i < offset + length) {
            sum += (data[i].toInt() and 0xFF) shl 8
        }
        while (sum shr 16 > 0) {
            sum = (sum and 0xFFFF) + (sum shr 16)
        }
        return (sum.inv() and 0xFFFF)
    }

    private fun computeUdpChecksum(
        srcIp: ByteArray,
        dstIp: ByteArray,
        srcPort: Int,
        dstPort: Int,
        payload: ByteArray
    ): Int {
        var sum = 0
        // Pseudo header: Src IP (4 bytes)
        sum += ((srcIp[0].toInt() and 0xFF) shl 8) or (srcIp[1].toInt() and 0xFF)
        sum += ((srcIp[2].toInt() and 0xFF) shl 8) or (srcIp[3].toInt() and 0xFF)
        // Pseudo header: Dst IP (4 bytes)
        sum += ((dstIp[0].toInt() and 0xFF) shl 8) or (dstIp[1].toInt() and 0xFF)
        sum += ((dstIp[2].toInt() and 0xFF) shl 8) or (dstIp[3].toInt() and 0xFF)
        // Pseudo header: Zero + Protocol (17 = 0x0011)
        sum += 17
        // Pseudo header: UDP Length
        val udpLen = 8 + payload.size
        sum += udpLen

        // UDP Header: Ports & Length
        sum += srcPort
        sum += dstPort
        sum += udpLen

        // Payload words
        var i = 0
        while (i < payload.size - 1) {
            val word = ((payload[i].toInt() and 0xFF) shl 8) or (payload[i + 1].toInt() and 0xFF)
            sum += word
            i += 2
        }
        if (i < payload.size) {
            sum += (payload[i].toInt() and 0xFF) shl 8
        }

        while (sum shr 16 > 0) {
            sum = (sum and 0xFFFF) + (sum shr 16)
        }
        var ck = sum.inv() and 0xFFFF
        if (ck == 0) ck = 0xFFFF
        return ck
    }

    private fun stopDns() {
        isDohRunning.set(false)
        encryptedDnsClient.close()
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
