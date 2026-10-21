package ir.ryzerdns.ryzer_dns_android

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
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
import java.util.concurrent.atomic.AtomicInteger
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLContext
import javax.net.ssl.SNIHostName
import javax.net.ssl.SSLPeerUnverifiedException
import javax.net.ssl.SSLSocket

class RyzerDnsVpnService : VpnService() {

    private var vpnInterface: ParcelFileDescriptor? = null
    private var dohWorkerThread: Thread? = null
    private val isDohRunning = AtomicBoolean(false)
    private val threadPool = Executors.newFixedThreadPool(8)
    private val localDnsCache = ConcurrentHashMap<String, Pair<Long, ByteArray>>()
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    private val targetServerIpBytes = byteArrayOf(87.toByte(), 248.toByte(), 145.toByte(), 40.toByte())
    private val targetServerHost = "dns.ryzerdns.ir"

    private var dotPool: DoTResolverPool? = null

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
                val secondaryDns = intent.getStringExtra("secondary_dns") ?: "193.242.208.98"
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

    private fun setupUnderlyingNetworks() {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val callback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    try {
                        setUnderlyingNetworks(arrayOf(network))
                        Log.i(TAG, "Underlying network connected: $network")
                    } catch (e: Exception) {
                        Log.w(TAG, "setUnderlyingNetworks error: ${e.message}")
                    }
                }

                override fun onLost(network: Network) {
                    try {
                        val active = cm.activeNetwork
                        if (active != null) {
                            setUnderlyingNetworks(arrayOf(active))
                        } else {
                            setUnderlyingNetworks(null)
                        }
                    } catch (_: Exception) {}
                }

                override fun onCapabilitiesChanged(network: Network, networkCapabilities: NetworkCapabilities) {
                    if (networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)) {
                        try {
                            setUnderlyingNetworks(arrayOf(network))
                        } catch (_: Exception) {}
                    }
                }
            }
            networkCallback = callback
            try {
                cm.registerDefaultNetworkCallback(callback)
            } catch (e: Exception) {
                Log.w(TAG, "registerDefaultNetworkCallback failed: ${e.message}")
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val active = cm.activeNetwork
                if (active != null) {
                    setUnderlyingNetworks(arrayOf(active))
                    Log.i(TAG, "Initial underlying network established: $active")
                }
            } catch (e: Exception) {
                Log.w(TAG, "Initial setUnderlyingNetworks error: ${e.message}")
            }
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

        val title = "RyzerDNS فعال است"
        val subtitle = "مسیرهای شبکه و بازی‌ها بهینه‌سازی شد"

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
            builder.setSession("RyzerDNS")
            builder.setMtu(1500)

            if (enableDoh) {
                // Virtual DNS resolver endpoint on 10.111.222.2
                // Local interface address 10.111.222.1/30
                builder.addAddress("10.111.222.1", 30)
                builder.addDnsServer("10.111.222.2")
                builder.addRoute("10.111.222.2", 32)
                Log.i(TAG, "Configuring Ultra Connection with Virtual DNS 10.111.222.2 (DoT:853)")
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

            // Allow non-DNS internet traffic to flow directly through physical network
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

            // Bind underlying physical network to propagate NET_CAPABILITY_VALIDATED
            setupUnderlyingNetworks()

            if (enableDoh && pfd != null) {
                dotPool = DoTResolverPool(this, poolSize = 6).apply {
                    prewarm()
                }
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

                    // 1. Handle ICMP Echo Request (Ping) for 10.111.222.2 immediately
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

                    // 3. Fast In-Memory Cache (0.1ms reply)
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

                    // 4. Forward via DoT Pool to dns.ryzerdns.ir:853
                    threadPool.execute {
                        handleDoTQuery(clientIp, srcPort, dnsServerIp, dnsQuery, cacheKey, outStream)
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

    private fun handleDoTQuery(
        clientIp: ByteArray,
        clientPort: Int,
        dnsServerIp: ByteArray,
        dnsQuery: ByteArray,
        cacheKey: String?,
        tunOutStream: FileOutputStream
    ) {
        var respBytes: ByteArray? = null

        // 1. Resolve strictly via Native Protected DoT Pool (Port 853) - 100% Encrypted & Zero UDP 53 Fallback!
        try {
            respBytes = dotPool?.resolve(dnsQuery)
        } catch (e: Exception) {
            Log.w(TAG, "DoT Pool query error: ${e.message}")
        }

        // 2. Inject Response Packet back into TUN Interface
        if (respBytes != null && respBytes.size >= 12) {
            val replyPacket = buildIpv4UdpPacket(dnsServerIp, clientIp, 53, clientPort, respBytes)
            synchronized(tunOutStream) {
                try {
                    tunOutStream.write(replyPacket)
                    tunOutStream.flush()
                } catch (e: Exception) {
                    Log.w(TAG, "Failed writing to TUN: ${e.message}")
                }
            }

            // Save to Cache for 60 seconds
            if (cacheKey != null) {
                localDnsCache[cacheKey] = Pair(System.currentTimeMillis() + 60_000L, respBytes)
            }
        } else {
            Log.w(TAG, "DoT Query unresolvable: $cacheKey (Strict Port 853 Mode - Zero UDP Leak)")
        }
    }

    inner class DoTResolverPool(private val vpnService: VpnService, private val poolSize: Int = 6) {
        private val resolvers = Array(poolSize) { idx -> DoTResolver(vpnService, idx) }
        private val counter = AtomicInteger(0)

        fun prewarm() {
            for (r in resolvers) {
                threadPool.execute {
                    try {
                        r.ensureConnected()
                    } catch (e: Exception) {
                        Log.w(TAG, "DoT prewarm worker error: ${e.message}")
                    }
                }
            }
        }

        fun resolve(query: ByteArray): ByteArray? {
            // ⚡ Non-blocking load-balanced dispatch: pick first available idle resolver
            for (r in resolvers) {
                if (!r.isBusy.get()) {
                    val resp = r.resolve(query)
                    if (resp != null) return resp
                }
            }
            // If all busy, round-robin fallback
            val idx = Math.abs(counter.getAndIncrement() % poolSize)
            return resolvers[idx].resolve(query)
        }

        fun closeAll() {
            for (r in resolvers) {
                r.closeSocket()
            }
        }
    }

    inner class DoTResolver(private val vpnService: VpnService, private val workerIndex: Int = 0) {
        private val serverPort = 853
        val isBusy = AtomicBoolean(false)

        // 🔒 System-Standard SSLContext (Validates official CA - Zero TrustAll / Zero MITM vulnerability)
        private val sslContext: SSLContext = SSLContext.getInstance("TLS").apply {
            init(null, null, null)
        }

        private var socket: SSLSocket? = null
        private var inStream: InputStream? = null
        private var outStream: OutputStream? = null

        @Synchronized
        fun resolve(query: ByteArray): ByteArray? {
            isBusy.set(true)
            try {
                for (attempt in 0..1) {
                    try {
                        ensureConnected()
                        val out = outStream ?: throw IOException("No outStream")
                        val inp = inStream ?: throw IOException("No inStream")

                        val qLen = query.size
                        out.write((qLen shr 8) and 0xFF)
                        out.write(qLen and 0xFF)
                        out.write(query)
                        out.flush()

                        val lenBuf = ByteArray(2)
                        var r = 0
                        while (r < 2) {
                            val c = inp.read(lenBuf, r, 2 - r)
                            if (c <= 0) throw IOException("EOF on len read")
                            r += c
                        }
                        val respLen = ((lenBuf[0].toInt() and 0xFF) shl 8) or (lenBuf[1].toInt() and 0xFF)
                        if (respLen <= 0 || respLen > 4096) throw IOException("Invalid respLen: $respLen")

                        val resp = ByteArray(respLen)
                        var total = 0
                        while (total < respLen) {
                            val c = inp.read(resp, total, respLen - total)
                            if (c <= 0) throw IOException("EOF on payload read")
                            total += c
                        }
                        return resp
                    } catch (e: Exception) {
                        Log.w(TAG, "DoTResolver #$workerIndex query error: ${e.message}")
                        closeSocket()
                    }
                }
                return null
            } finally {
                isBusy.set(false)
            }
        }

        fun ensureConnected() {
            if (socket != null && socket?.isConnected == true && socket?.isClosed == false) {
                return
            }
            closeSocket()

            val plain = Socket()
            vpnService.protect(plain)
            plain.tcpNoDelay = true
            plain.keepAlive = true
            plain.soTimeout = 4000

            // 🌐 Dynamic resolution of dns.ryzerdns.ir with dual-node fallback
            val resolvedAddresses = try {
                InetAddress.getAllByName(targetServerHost)
            } catch (_: Exception) {
                arrayOf(
                    InetAddress.getByAddress(targetServerIpBytes),
                    InetAddress.getByName("193.242.208.98")
                )
            }
            val chosenIp = resolvedAddresses[workerIndex % resolvedAddresses.size]
            plain.connect(InetSocketAddress(chosenIp, serverPort), 3000)

            val ssl = sslContext.socketFactory.createSocket(plain, targetServerHost, serverPort, true) as SSLSocket
            ssl.tcpNoDelay = true
            ssl.keepAlive = true
            ssl.soTimeout = 4000

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                try {
                    val sslParams = ssl.sslParameters
                    sslParams.serverNames = listOf(SNIHostName(targetServerHost))
                    ssl.sslParameters = sslParams
                } catch (_: Exception) {}
            }

            ssl.startHandshake()

            // 🔒 Official RFC 7858 Standard Hostname Verification for dns.ryzerdns.ir
            val session = ssl.session
            if (!HttpsURLConnection.getDefaultHostnameVerifier().verify(targetServerHost, session)) {
                ssl.close()
                plain.close()
                throw SSLPeerUnverifiedException("Hostname verification failed for $targetServerHost")
            }

            socket = ssl
            inStream = ssl.inputStream
            outStream = ssl.outputStream
        }

        fun closeSocket() {
            try { inStream?.close() } catch (_: Exception) {}
            try { outStream?.close() } catch (_: Exception) {}
            try { socket?.close() } catch (_: Exception) {}
            socket = null
            inStream = null
            outStream = null
            isBusy.set(false)
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
        localDnsCache.clear()
        dotPool?.closeAll()
        dotPool = null

        networkCallback?.let {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            try {
                cm.unregisterNetworkCallback(it)
            } catch (_: Exception) {}
            networkCallback = null
        }

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
