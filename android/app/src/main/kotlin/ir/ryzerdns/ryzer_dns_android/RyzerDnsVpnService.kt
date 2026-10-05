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
import java.io.InputStream
import java.io.OutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
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

    private val targetServerIpBytes = byteArrayOf(87.toByte(), 248.toByte(), 145.toByte(), 40.toByte())
    private val targetServerHost = "dns.ryzerdns.ir"

    private val trustAllCerts = object : X509TrustManager {
        override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
        override fun checkClientTrusted(certs: Array<X509Certificate>, authType: String) {}
        override fun checkServerTrusted(certs: Array<X509Certificate>, authType: String) {}
    }

    // Pending query structure for DoT pipelining
    data class PendingQuery(
        val clientIp: ByteArray,
        val clientPort: Int,
        val timestamp: Long
    )

    private val pendingQueries = ConcurrentHashMap<Int, PendingQuery>()
    private val dotClient = DotClient()

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

        val title = if (enableDoh) "اتصال فوق‌العاده RyzerDNS (DoT) فعال است" else "RyzerDNS فعال است"
        val subtitle = if (enableDoh) "پروتکل رمزنگاری‌شده DoT فعال شد" else "مسیرهای شبکه و بازی‌ها بهینه‌سازی شد"

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
                Log.i(TAG, "Configuring Ultra Connection with Virtual DNS 10.111.222.2 (DoT)")
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

        // Initialize and warm up the persistent DoT socket
        dotClient.init(outStream)

        dohWorkerThread = Thread {
            val packet = ByteArray(32768)
            Log.i(TAG, "DoT TUN Worker thread started")

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

                    // 2. Reject TCP on Port 53 / 853 with TCP RST so Android does not hang
                    if (protocol == 6) {
                        val dstPort = ((packet[ihl + 2].toInt() and 0xFF) shl 8) or (packet[ihl + 3].toInt() and 0xFF)
                        if (dstPort == 53 || dstPort == 853) {
                            val srcPort = ((packet[ihl].toInt() and 0xFF) shl 8) or (packet[ihl + 1].toInt() and 0xFF)
                            val clientIp = ByteArray(4)
                            System.arraycopy(packet, 12, clientIp, 0, 4)
                            val dnsServerIp = ByteArray(4)
                            System.arraycopy(packet, 16, dnsServerIp, 0, 4)
                            val rstPacket = buildTcpRstPacket(dnsServerIp, clientIp, dstPort, srcPort)
                            synchronized(outStream) {
                                outStream.write(rstPacket)
                                outStream.flush()
                            }
                            continue
                        }
                    }

                    // 3. Handle UDP Port 53 DNS Queries
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

                    val txId = ((dnsQuery[0].toInt() and 0xFF) shl 8) or (dnsQuery[1].toInt() and 0xFF)

                    // 4. Check Fast In-Memory Cache first
                    val cacheKey = getDnsQuestionKey(dnsQuery)
                    val now = System.currentTimeMillis()
                    if (cacheKey != null) {
                        val cached = localDnsCache[cacheKey]
                        if (cached != null && now < cached.first) {
                            val cachedResp = cached.second.copyOf()
                            cachedResp[0] = dnsQuery[0]
                            cachedResp[1] = dnsQuery[1]
                            val replyPacket = buildIpv4UdpPacket(dnsServerIp, clientIp, 53, srcPort, cachedResp)
                            synchronized(outStream) {
                                outStream.write(replyPacket)
                                outStream.flush()
                            }
                            continue
                        }
                    }

                    // 5. Forward via Pipelined DoT Client
                    threadPool.execute {
                        dotClient.forwardQuery(txId, clientIp, srcPort, dnsServerIp, dnsQuery, cacheKey)
                    }
                } catch (e: Exception) {
                    if (!isDohRunning.get()) break
                    Log.w(TAG, "TUN read error: ${e.message}")
                }
            }
            Log.i(TAG, "DoT TUN Worker thread stopped")
        }.apply {
            name = "RyzerDnsDoTWorker"
            isDaemon = true
            start()
        }
    }

    inner class DotClient {
        private var socket: SSLSocket? = null
        private var outStream: OutputStream? = null
        private var tunOutStream: FileOutputStream? = null
        private var readerThread: Thread? = null
        private val lock = Any()

        fun init(tunOut: FileOutputStream) {
            this.tunOutStream = tunOut
            ensureConnected()
        }

        private fun ensureConnected(): Boolean {
            synchronized(lock) {
                if (socket != null && socket?.isConnected == true && socket?.isClosed == false) {
                    return true
                }
                closeSocket()

                try {
                    val serverAddr = InetAddress.getByAddress(targetServerIpBytes)
                    val sslContext = SSLContext.getInstance("TLS")
                    sslContext.init(null, arrayOf<TrustManager>(trustAllCerts), null)

                    val plainSocket = Socket()
                    protect(plainSocket)
                    plainSocket.tcpNoDelay = true
                    plainSocket.soTimeout = 0 // Infinite read timeout for long-lived multiplexed receiver
                    plainSocket.connect(InetSocketAddress(serverAddr, 853), 2000)

                    val sslSocket = sslContext.socketFactory.createSocket(
                        plainSocket,
                        targetServerHost,
                        853,
                        true
                    ) as SSLSocket
                    sslSocket.soTimeout = 0
                    sslSocket.startHandshake()

                    socket = sslSocket
                    outStream = sslSocket.outputStream
                    startReader(sslSocket.inputStream)
                    Log.i(TAG, "Pipelined DoT Connection established to $targetServerHost:853")
                    return true
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to connect DoT socket: ${e.message}")
                    closeSocket()
                    return false
                }
            }
        }

        private fun startReader(inp: InputStream) {
            readerThread?.interrupt()
            readerThread = Thread {
                val lenBuf = ByteArray(2)
                while (isDohRunning.get()) {
                    try {
                        var r = 0
                        while (r < 2) {
                            val count = inp.read(lenBuf, r, 2 - r)
                            if (count <= 0) break
                            r += count
                        }
                        if (r < 2) break

                        val msgLen = ((lenBuf[0].toInt() and 0xFF) shl 8) or (lenBuf[1].toInt() and 0xFF)
                        if (msgLen <= 0 || msgLen > 4096) continue

                        val respBuf = ByteArray(msgLen)
                        var totalRead = 0
                        while (totalRead < msgLen) {
                            val count = inp.read(respBuf, totalRead, msgLen - totalRead)
                            if (count <= 0) break
                            totalRead += count
                        }
                        if (totalRead != msgLen) break

                        // Extract Transaction ID
                        val txId = ((respBuf[0].toInt() and 0xFF) shl 8) or (respBuf[1].toInt() and 0xFF)
                        val pending = pendingQueries.remove(txId)

                        if (pending != null && tunOutStream != null) {
                            val replyPacket = buildIpv4UdpPacket(
                                byteArrayOf(10.toByte(), 111.toByte(), 222.toByte(), 2.toByte()),
                                pending.clientIp,
                                53,
                                pending.clientPort,
                                respBuf
                            )
                            synchronized(tunOutStream!!) {
                                tunOutStream!!.write(replyPacket)
                                tunOutStream!!.flush()
                            }

                            // Save to cache for 60 seconds
                            val cacheKey = getDnsQuestionKey(respBuf)
                            if (cacheKey != null) {
                                localDnsCache[cacheKey] = Pair(System.currentTimeMillis() + 60_000L, respBuf)
                            }
                        }
                    } catch (e: Exception) {
                        break
                    }
                }
                synchronized(lock) {
                    closeSocket()
                }
            }.apply {
                name = "DoT-ResponseReader"
                isDaemon = true
                start()
            }
        }

        fun forwardQuery(
            txId: Int,
            clientIp: ByteArray,
            clientPort: Int,
            dnsServerIp: ByteArray,
            dnsQuery: ByteArray,
            cacheKey: String?
        ) {
            pendingQueries[txId] = PendingQuery(clientIp, clientPort, System.currentTimeMillis())

            var sent = false
            if (ensureConnected()) {
                synchronized(lock) {
                    try {
                        val out = outStream
                        if (out != null) {
                            val len = dnsQuery.size
                            out.write((len shr 8) and 0xFF)
                            out.write(len and 0xFF)
                            out.write(dnsQuery)
                            out.flush()
                            sent = true
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "Error writing to DoT socket: ${e.message}")
                        closeSocket()
                    }
                }
            }

            // Fallback: If DoT write failed, send via protected direct UDP query to 87.248.145.40:53
            if (!sent) {
                pendingQueries.remove(txId)
                executeUdpFallback(clientIp, clientPort, dnsServerIp, dnsQuery)
            }
        }

        private fun executeUdpFallback(
            clientIp: ByteArray,
            clientPort: Int,
            dnsServerIp: ByteArray,
            dnsQuery: ByteArray
        ) {
            try {
                DatagramSocket().use { socket ->
                    protect(socket)
                    socket.soTimeout = 2000
                    val sendPacket = DatagramPacket(
                        dnsQuery,
                        dnsQuery.size,
                        InetAddress.getByAddress(targetServerIpBytes),
                        53
                    )
                    socket.send(sendPacket)

                    val recvBuf = ByteArray(4096)
                    val recvPacket = DatagramPacket(recvBuf, recvBuf.size)
                    socket.receive(recvPacket)

                    val resp = ByteArray(recvPacket.length)
                    System.arraycopy(recvPacket.data, recvPacket.offset, resp, 0, recvPacket.length)

                    if (tunOutStream != null) {
                        val replyPacket = buildIpv4UdpPacket(dnsServerIp, clientIp, 53, clientPort, resp)
                        synchronized(tunOutStream!!) {
                            tunOutStream!!.write(replyPacket)
                            tunOutStream!!.flush()
                        }
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "UDP fallback failed: ${e.message}")
            }
        }

        fun closeSocket() {
            try { socket?.close() } catch (_: Exception) {}
            socket = null
            outStream = null
        }
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

    private fun buildTcpRstPacket(
        srcIp: ByteArray,
        dstIp: ByteArray,
        srcPort: Int,
        dstPort: Int
    ): ByteArray {
        val packet = ByteArray(40)
        packet[0] = 0x45.toByte() // IPv4, IHL 5
        packet[1] = 0x00.toByte()
        packet[2] = 0.toByte()
        packet[3] = 40.toByte() // Total length 40
        packet[4] = 0x12.toByte()
        packet[5] = 0x34.toByte()
        packet[6] = 0x40.toByte() // Don't fragment
        packet[7] = 0x00.toByte()
        packet[8] = 64.toByte()   // TTL
        packet[9] = 6.toByte()    // Protocol TCP = 6
        System.arraycopy(srcIp, 0, packet, 12, 4)
        System.arraycopy(dstIp, 0, packet, 16, 4)

        // Compute IP Checksum
        val ipChecksum = computeChecksum(packet, 0, 20)
        packet[10] = ((ipChecksum shr 8) and 0xFF).toByte()
        packet[11] = (ipChecksum and 0xFF).toByte()

        // TCP Header (20 bytes)
        packet[20] = ((srcPort shr 8) and 0xFF).toByte()
        packet[21] = (srcPort and 0xFF).toByte()
        packet[22] = ((dstPort shr 8) and 0xFF).toByte()
        packet[23] = (dstPort and 0xFF).toByte()
        // Seq number = 0
        packet[24] = 0
        packet[25] = 0
        packet[26] = 0
        packet[27] = 0
        // Data offset 5 (20 bytes)
        packet[32] = 0x50.toByte()
        // Flags: RST + ACK (0x14)
        packet[33] = 0x14.toByte()
        // Window size
        packet[34] = 0
        packet[35] = 0

        return packet
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
        dotClient.closeSocket()
        localDnsCache.clear()
        pendingQueries.clear()
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
