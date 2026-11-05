package com.aiq.ongi.device.sync

import com.aiq.ongi.device.Config
import com.aiq.ongi.device.store.MessageStore
import com.aiq.ongi.device.store.OngiDb
import com.aiq.ongi.device.store.ParentMessage
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit

/**
 * 서버(정범) ↔ 보드 동기화 (DEV-09). 서버 과제서 4장 API-11 ~ 14.
 *
 *  30초마다
 *   1. API-14  못 보낸 재생 기록부터 보냄
 *   2. API-11  GET /device/changes?since=…  → 바뀐 메시지(삭제 포함)
 *   3. API-12  voice면 GET /device/audio/{id} → files/audio/{id}.m4a  (16kHz wav 변환은 오디오 해결 후)
 *   4. API-13  POST /device/ack {"message_ids":[…]}
 *  재생 직후 reportPlayed → play_logs 저장 + API-14 (실패하면 다음 동기화 때 다시)
 *
 *  API-11 응답 모양(정범님 규격 확정 전 가정, 가짜 서버 device/mock_server.py와 같음):
 *   {"server_time":"2026-11-02T21:30:00",
 *    "messages":[{"id":5,"situation_id":2,"author":"dad","kind":"voice","text":null,
 *                 "deleted":false,"updated_at":"2026-11-02T21:29:10"}]}
 *  서버가 꺼져 있으면 기록만 남기고 보드는 저장된 메시지로 계속 동작한다.
 */
class ServerSync(
    private val store: MessageStore,
    private val db: OngiDb,
    private val audioDir: File,
    private val log: (String) -> Unit,
) {
    /** 서버 주소는 매번 Config에서 (config.json으로 빌드 없이 바뀜, 11/5) */
    private val baseUrl get() = Config.SERVER_URL

    private val worker = Executors.newSingleThreadScheduledExecutor()

    /** 메시지가 바뀌면(받음·지움) 부른다. 흐름이 부모 메시지 소리를 미리 만든다 (11/5) */
    @Volatile var onChanged: (() -> Unit)? = null
    private var task: ScheduledFuture<*>? = null
    @Volatile private var lastError: String? = null

    fun start() {
        log("동기화 시작: $baseUrl, ${Config.SYNC_SEC}초마다 / 보드 메시지 ${store.all().size}개, 재생 기록 ${store.playLogCount()}개")
        task = worker.scheduleWithFixedDelay({ syncOnce() }, 1, Config.SYNC_SEC, TimeUnit.SECONDS)
    }

    fun stop() {
        task?.cancel(false)
        worker.shutdownNow()
    }

    /** 한 번 동기화. 서버 오류는 같은 오류면 한 번만 기록 */
    fun syncOnce() {
        com.aiq.ongi.device.ConfigFile.reload(log)
        try {
            flushPlayLogs()
            val since = db.getState("since") ?: "2000-01-01T00:00:00"
            val res = JSONObject(http("GET", "/device/changes?since=" + URLEncoder.encode(since, "UTF-8")))
            val arr = res.optJSONArray("messages") ?: JSONArray()
            val acked = mutableListOf<Int>()
            var changed = false
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                val id = o.getInt("id")
                if (o.optBoolean("deleted", false)) {
                    store.delete(id)
                    changed = true
                    log("동기화: 메시지 $id 삭제됨 → 보드에서도 지움")
                    continue
                }
                val kind = o.getString("kind")
                val audio = if (kind == "voice") downloadAudio(id) else null
                store.upsert(
                    ParentMessage(
                        id = id,
                        situationId = o.getInt("situation_id"),
                        author = o.getString("author"),
                        kind = kind,
                        text = if (o.isNull("text")) null else o.getString("text"),
                        audioPath = audio?.absolutePath,
                        updatedAt = o.optString("updated_at", null),
                    ),
                )
                acked += id
                log("동기화: 메시지 $id 받음 (상황 ${o.getInt("situation_id")}, ${o.getString("author")}, $kind${if (audio != null) ", 녹음 ${audio.length()}바이트" else ""})")
            }
            if (acked.isNotEmpty()) {
                http("POST", "/device/ack", JSONObject().put("message_ids", JSONArray(acked)).toString())
                log("동기화: 받았음 알림(API-13) ${acked}")
            }
            res.optString("server_time", null)?.let { st ->
                db.setState("since", st)
                // 보드 시계 보정: 서버 시각 - 보드 시각 (1분 넘게 다르면 기록)
                try {
                    val off = java.time.Duration.between(java.time.LocalDateTime.now(), java.time.LocalDateTime.parse(st)).seconds
                    if (kotlin.math.abs(off - store.clockOffsetSec) > 60) log("보드 시계 보정: 서버와 ${off}초 차이 → 재생 기록은 서버 시각으로")
                    store.clockOffsetSec = off
                } catch (_: Exception) {}
            }
            if (changed || acked.isNotEmpty()) onChanged?.invoke()
            if (lastError != null) log("동기화: 서버 다시 연결됨")
            lastError = null
        } catch (e: Exception) {
            val msg = e.message ?: e.javaClass.simpleName
            if (msg != lastError) log("동기화 실패(저장된 메시지로 계속): $msg")
            lastError = msg
        }
    }

    /** 재생 직후 호출 (흐름 스레드). 저장은 바로, 서버 전송은 동기화 스레드에서 */
    fun reportPlayed(messageId: Int) {
        val pl = store.addPlayLog(messageId)
        log("재생 기록: message_id=$messageId, ${pl.playedAt}")
        worker.execute { try { flushPlayLogs() } catch (_: Exception) {} }
    }

    private fun flushPlayLogs() {
        for (pl in store.unreportedPlayLogs()) {
            http("POST", "/device/play-logs", JSONObject().put("message_id", pl.messageId).put("played_at", pl.playedAt).toString())
            store.markReported(pl.id)
            log("재생 기록 보냄(API-14): message_id=${pl.messageId}")
        }
    }

    private fun downloadAudio(id: Int): File {
        audioDir.mkdirs()
        val f = File(audioDir, "$id.m4a")
        val c = open("GET", "/device/audio/$id")
        try {
            check(c.responseCode == 200) { "API-12 $id: HTTP ${c.responseCode}" }
            c.inputStream.use { input -> f.outputStream().use { input.copyTo(it) } }
        } finally {
            c.disconnect()
        }
        return f
    }

    private fun http(method: String, path: String, body: String? = null): String {
        val c = open(method, path)
        try {
            if (body != null) {
                c.doOutput = true
                c.setRequestProperty("Content-Type", "application/json; charset=utf-8")
                c.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            }
            val code = c.responseCode
            val text = (if (code in 200..299) c.inputStream else c.errorStream)?.bufferedReader()?.use { it.readText() }.orEmpty()
            check(code in 200..299) { "$method $path: HTTP $code $text" }
            return text
        } finally {
            c.disconnect()
        }
    }

    private fun open(method: String, path: String): HttpURLConnection =
        (URL(baseUrl.trimEnd('/') + path).openConnection() as HttpURLConnection).apply {
            requestMethod = method
            connectTimeout = 3000
            readTimeout = 10000
        }
}
