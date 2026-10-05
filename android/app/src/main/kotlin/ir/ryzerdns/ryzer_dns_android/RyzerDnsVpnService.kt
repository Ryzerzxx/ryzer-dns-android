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
import java.security.cert.X509Certificate
import java.util.concurrent.ConcurrentHashMap
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
    private val localDnsCache = ConcurrentHashMap<String, Pair<Long, ByteArray>>()

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
        val subtitle = if (enableDoh) "پروتکل رمزنگاری‌شده DoH فعال شد" else "مسیرهای شبکه و بازی‌ها بهینه‌سازی شد"

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
                // Virtual DNS resolver endpoint on 10.111.222.2
                // Local interface address 10.111.222.1/30
                builder.addAddress("10.111.222.1", 30)
                builder.addDnsServer("10.111.222.2")
                builder.addRoute("10.111.222.2", 32)
                Log.i(TAG, "Configuring Ultra Connection with Virtual DNS 10.111.222.2")
            } else {
                builder.addAddress("10.0.0.2", 24)
                builder.addDnsServer(primaryDns)
                builder.addDnsServer(secondaryDns)
                Log.d(TAG, "Configuring Standard DNS: [$primaryDns, $secondaryDns]")
            }

            // Disallow our own app to prevent loops and exempt our traffic from VPN
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
            Log.i(TAG, "DoH TUN Worker thread started")

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

                    // 1. Handle ICMP Echo Request (Ping) for 10.111.222.2
                    if (protocol == 1) {
                        val icmpType = packet[ihl].toInt() and 0xFF
                        if (icmpType == 8) { // Echo Request
                            val replyPacket = ByteArray(length)
                            System.arraycopy(packet, 0, replyPacket, 0, length)
                            // Swap Source and Destination IPs
                            System.arraycopy(packet, 16, replyPacket, 12, 4)
                            System.arraycopy(packet, 12, replyPacket, 16, 4)
                            // Change Type to 0 (Echo Reply)
                            replyPacket[ihl] = 0.toByte()
                            // Recompute ICMP Checksum
                            replyPacket[ihl + 2] = 0.toByte()
                            replyPacket[ihl + 3] = 0.toByte()
                            val icmpLen = length - ihl
                            val icmpCk = computeChecksum(replyPacket, ihl, icmpLen)
                            replyPacket[ihl + 2] = ((icmpCk shr 8) and 0xFF).toByte()
                            replyPacket[ihl + 3] = (icmpCk and 0xFF).toByte()
                            // Recompute IP Checksum
                            replyPacket[10] = 0.toByte()
                            replyPacket[11] = 0.toByte()
                            val ipCk = computeChecksum(replyPacket, 0, ihl)
                            replyPacket[10] = ((ipCk shr 8) and 0xFF).toByte()
                            replyPacket[11] = (ipCk and 0xFF).toByte()

                            synchronized(outStream) {
                                outStream.write(replyPacket)
                                outStream.flush()
                            }
                            continue
                        }
                    }

                    // 2. Handle UDP Port 53 DNS Queries
                    if (protocol != 17) continue // UDP only

                    val srcPort = ((packet[ihl].toInt() and 0xFF) shl 8) or (packet[ihl + 1].toInt() and 0xFF)
                    val dstPort = ((packet[ihl + 2].toInt() and 0xFF) shl 8) or (packet[ihl + 3].toInt() and 0xFF)
                    if (dstPort != 53) continue

                    val udpLen = ((packet[ihl + 4].toInt() and 0xFF) shl 8) or (packet[ihl + 5].toInt() and 0xFF)
                    val dnsPayloadLen = udpLen - 8
                    if (dnsPayloadLen <= 0 || ihl + 8 + dnsPayloadLen > length) continue

                    val clientIp = ByteArray(4)
                    System.arraycopy(packet, 12, clientIp, 0, 4)
                    val dnsServerIp = ByteArray(4)
                    System.arraycopy(packet, 16, dnsServerIp, 0, 4)

                    val dnsQuery = ByteArray(dnsPayloadLen)
                    System.arraycopy(packet, ihl + 8, dnsQuery, 0, dnsPayloadLen)

                    // Process DNS asynchronously
                    threadPool.execute {
                        try {
                            val dnsResp = queryDohWithCache(dnsQuery)
                            if (dnsResp != null && dnsResp.isNotEmpty()) {
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
            Log.i(TAG, "DoH TUN Worker thread stopped")
        }.apply {
            name = "RyzerDnsDoHWorker"
            isDaemon = true
            start()
        }
    }

    private fun queryDohWithCache(dnsQuery: ByteArray): ByteArray? {
        val cacheKey = getDnsQuestionKey(dnsQuery)
        val now = System.currentTimeMillis()

        // 1. Check in-memory fast cache
        if (cacheKey != null) {
            val cached = localDnsCache[cacheKey]
            if (cached != null && now < cached.first) {
                val cachedResp = cached.second.copyOf()
                // Patch Transaction ID to match current query
                if (dnsQuery.size >= 2 && cachedResp.size >= 2) {
                    cachedResp[0] = dnsQuery[0]
                    cachedResp[1] = dnsQuery[1]
                }
                return cachedResp
            }
        }

        // 2. Query DoH Server via direct HTTPS POST
        val dnsResp = executeDoHPost(dnsQuery)
        if (dnsResp != null && dnsResp.size >= 12 && cacheKey != null) {
            // Cache valid responses for 60 seconds
            localDnsCache[cacheKey] = Pair(now + 60_000L, dnsResp)
        }
        return dnsResp
    }

    private fun executeDoHPost(dnsQuery: ByteArray): ByteArray? {
        // Direct IPs to bypass DNS recursive lookups completely:
        // Primary: Iran Edge (87.248.145.40:8445)
        // Fallback: Germany Main Server (143.20.60.94:443)
        val endpoints = listOf(
            Pair("87.248.145.40", 8445),
            Pair("143.20.60.94", 443)
        )

        for ((hostIp, port) in endpoints) {
            try {
                val serverAddr = InetAddress.getByName(hostIp)
                val sslContext = SSLContext.getInstance("TLS")
                sslContext.init(null, arrayOf<TrustManager>(trustAllCerts), null)

                val plainSocket = Socket()
                protect(plainSocket)
                plainSocket.tcpNoDelay = true
                plainSocket.soTimeout = 2500
                plainSocket.connect(InetSocketAddress(serverAddr, port), 1200)

                val sslSocket = sslContext.socketFactory.createSocket(
                    plainSocket,
                    "ryzerdns.ir",
                    port,
                    true
                ) as SSLSocket
                sslSocket.soTimeout = 2500
                sslSocket.startHandshake()

                val out = sslSocket.outputStream
                val inp = sslSocket.inputStream

                val requestHeader = ("POST /dns-query HTTP/1.1\r\n" +
                    "Host: ryzerdns.ir\r\n" +
                    "Content-Type: application/dns-message\r\n" +
                    "Accept: application/dns-message\r\n" +
                    "Content-Length: ${dnsQuery.size}\r\n" +
                    "Connection: close\r\n\r\n").toByteArray(Charsets.US_ASCII)

                out.write(requestHeader)
                out.write(dnsQuery)
                out.flush()

                // Read HTTP response header and exact Content-Length body
                val buffer = ByteArray(4096)
                var totalBytesRead = 0
                var bodyStartIndex = -1
                var contentLength = -1

                while (totalBytesRead < buffer.size) {
                    val count = inp.read(buffer, totalBytesRead, buffer.size - totalBytesRead)
                    if (count <= 0) break
                    totalBytesRead += count

                    // Find end of HTTP headers (\r\n\r\n)
                    if (bodyStartIndex == -1) {
                        for (i in 0 until totalBytesRead - 3) {
                            if (buffer[i] == 0x0D.toByte() && buffer[i+1] == 0x0A.toByte() &&
                                buffer[i+2] == 0x0D.toByte() && buffer[i+3] == 0x0A.toByte()) {
                                bodyStartIndex = i + 4
                                val headerStr = String(buffer, 0, i, Charsets.US_ASCII)
                                val clPrefix = "content-length:"
                                for (line in headerStr.lines()) {
                                    if (line.lowercase().startsWith(clPrefix)) {
                                        contentLength = line.substring(clPrefix.length).trim().toIntOrNull() ?: -1
                                    }
                                }
                                break
                            }
                        }
                    }

                    if (bodyStartIndex != -1) {
                        val bodyBytesReceived = totalBytesRead - bodyStartIndex
                        if (contentLength != -1 && bodyBytesReceived >= contentLength) {
                            val dnsPayload = ByteArray(contentLength)
                            System.arraycopy(buffer, bodyStartIndex, dnsPayload, 0, contentLength)
                            sslSocket.close()
                            return dnsPayload
                        }
                    }
                }

                sslSocket.close()
                if (bodyStartIndex != -1 && totalBytesRead > bodyStartIndex) {
                    val bodyLen = if (contentLength > 0) contentLength else (totalBytesRead - bodyStartIndex)
                    val dnsPayload = ByteArray(bodyLen)
                    System.arraycopy(buffer, bodyStartIndex, dnsPayload, 0, bodyLen)
                    return dnsPayload
                }
            } catch (e: Exception) {
                Log.d(TAG, "DoH query to $hostIp:$port failed: ${e.message}")
            }
        }
        return null
    }

    private fun getDnsQuestionKey(query: ByteArray): String? {
        if (query.size < 12) return null
        var idx = 12
        val sb = StringBuilder()
        while (idx < query.size) {
            val len = query[idx].toInt() and 0xFF
            if (len == 0) { idx++; break }
            if (len > 63 || idx + 1 + len > query.size) return null
            if (sb.isNotEmpty()) sb.append('.')
            sb.append(String(query, idx + 1, len, Charsets.US_ASCII).lowercase())
            idx += 1 + len
        }
        if (idx + 4 <= query.size) {
            val qtype = ((query[idx].toInt() and 0xFF) shl 8) or (query[idx + 1].toInt() and 0xFF)
            val qclass = ((query[idx + 2].toInt() and 0xFF) shl 8) or (query[idx + 3].toInt() and 0xFF)
            return "$sb:$qtype:$qclass"
        }
        return null
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
        localDnsCache.clear()
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
