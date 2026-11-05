package com.aiq.ongi.device.store

import android.content.ContentValues
import android.database.Cursor
import java.io.File
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/** 부모 메시지 한 개 */
data class ParentMessage(
    val id: Int,
    val situationId: Int,
    val author: String,     // "mom" / "dad"
    val kind: String,       // "voice" / "text"
    val text: String?,      // 글 메시지 내용 (voice면 null)
    val audioPath: String? = null,   // 받은 녹음 파일 (voice)
    val updatedAt: String? = null,
)

/** 아직 서버에 못 보낸 재생 기록 */
data class PlayLog(val id: Long, val messageId: Int, val playedAt: String)

/**
 * 보드 안 부모 메시지 저장소 (DEV-09, SQLite messages / play_logs).
 * 시연 4개 상황(3·4·10·11) 중 메시지가 없는 상황에만 시연용 메시지를 넣는다(11/5, 앱 켤 때마다 확인).
 * 서버에서 같은 상황 메시지가 오면 대체된다.
 */
class MessageStore(private val db: OngiDb) {

    /** 서버 시각 - 보드 시각(초). 보드는 인터넷이 없어 시계가 틀릴 수 있어서, 동기화 때 서버 시각으로 맞춘다 */
    @Volatile var clockOffsetSec: Long = db.getState("clock_offset_sec")?.toLongOrNull() ?: 0L
        set(v) { field = v; db.setState("clock_offset_sec", v.toString()) }

    /** 서버 기준 지금 시각 (공통지침 4-6 형식 2026-11-02T20:15:00) */
    fun nowText(): String =
        LocalDateTime.now().plusSeconds(clockOffsetSec).withNano(0).format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)

    init { seedDemoIfEmpty() }

    /** 그 상황의 메시지 (상황과 메시지는 1:1, 여러 개면 가장 최근 것) */
    @Synchronized
    fun find(situationId: Int): ParentMessage? =
        db.readableDatabase.rawQuery(
            "SELECT * FROM messages WHERE situation_id = ? ORDER BY demo ASC, updated_at DESC LIMIT 1",
            arrayOf(situationId.toString()),
        ).use { c -> if (c.moveToFirst()) c.toMessage() else null }

    @Synchronized
    fun all(): List<ParentMessage> =
        db.readableDatabase.rawQuery("SELECT * FROM messages ORDER BY situation_id", null).use { c ->
            buildList { while (c.moveToNext()) add(c.toMessage()) }
        }

    /** 서버 메시지 저장(있으면 덮어씀). 같은 상황의 시연용·옛 메시지는 지운다 */
    @Synchronized
    fun upsert(m: ParentMessage) {
        val w = db.writableDatabase
        w.beginTransaction()
        try {
            w.delete("messages", "situation_id = ? AND id != ?", arrayOf(m.situationId.toString(), m.id.toString()))
            w.insertWithOnConflict("messages", null, ContentValues().apply {
                put("id", m.id); put("situation_id", m.situationId); put("author", m.author)
                put("kind", m.kind); put("text", m.text); put("audio_path", m.audioPath)
                put("updated_at", m.updatedAt); put("demo", 0)
            }, android.database.sqlite.SQLiteDatabase.CONFLICT_REPLACE)
            w.setTransactionSuccessful()
        } finally {
            w.endTransaction()
        }
    }

    /** 서버에서 삭제된 메시지 → 보드에서도 지우고 녹음 파일도 지움 */
    @Synchronized
    fun delete(id: Int) {
        db.readableDatabase.rawQuery("SELECT audio_path FROM messages WHERE id = ?", arrayOf(id.toString())).use { c ->
            if (c.moveToFirst()) c.getString(0)?.let { File(it).delete() }
        }
        db.writableDatabase.delete("messages", "id = ?", arrayOf(id.toString()))
    }

    // ---- 재생 기록 ----

    @Synchronized
    fun addPlayLog(messageId: Int): PlayLog {
        val at = nowText()
        val id = db.writableDatabase.insert("play_logs", null, ContentValues().apply {
            put("message_id", messageId); put("played_at", at); put("reported", 0)
        })
        return PlayLog(id, messageId, at)
    }

    @Synchronized
    fun unreportedPlayLogs(): List<PlayLog> =
        db.readableDatabase.rawQuery("SELECT id, message_id, played_at FROM play_logs WHERE reported = 0 ORDER BY id", null).use { c ->
            buildList { while (c.moveToNext()) add(PlayLog(c.getLong(0), c.getInt(1), c.getString(2))) }
        }

    @Synchronized
    fun markReported(logId: Long) {
        db.writableDatabase.update("play_logs", ContentValues().apply { put("reported", 1) }, "id = ?", arrayOf(logId.toString()))
    }

    @Synchronized
    fun playLogCount(): Int =
        db.readableDatabase.rawQuery("SELECT COUNT(*) FROM play_logs", null).use { c -> if (c.moveToFirst()) c.getInt(0) else 0 }

    private fun seedDemoIfEmpty() {
        val demo = listOf(
            ParentMessage(4, 3, "mom", "text", "괜찮아, 시험보다 네가 더 소중해. 엄마는 늘 네 편이야."),
            ParentMessage(1, 4, "mom", "voice", null),
            ParentMessage(2, 10, "mom", "voice", null),
            ParentMessage(3, 11, "dad", "text", "민준아, 상 받은 거 정말 축하해. 아빠는 네가 노력한 게 제일 자랑스러워."),
        )
        val w = db.writableDatabase
        for (m in demo) {
            val has = db.readableDatabase.rawQuery(
                "SELECT COUNT(*) FROM messages WHERE situation_id = ? OR id = ?",
                arrayOf(m.situationId.toString(), m.id.toString()),
            ).use { c -> c.moveToFirst() && c.getInt(0) > 0 }
            if (has) continue
            w.insert("messages", null, ContentValues().apply {
            put("id", m.id); put("situation_id", m.situationId); put("author", m.author)
            put("kind", m.kind); put("text", m.text); put("demo", 1)
            })
        }
    }

    private fun Cursor.toMessage() = ParentMessage(
        id = getInt(getColumnIndexOrThrow("id")),
        situationId = getInt(getColumnIndexOrThrow("situation_id")),
        author = getString(getColumnIndexOrThrow("author")),
        kind = getString(getColumnIndexOrThrow("kind")),
        text = getString(getColumnIndexOrThrow("text")),
        audioPath = getString(getColumnIndexOrThrow("audio_path")),
        updatedAt = getString(getColumnIndexOrThrow("updated_at")),
    )
}
