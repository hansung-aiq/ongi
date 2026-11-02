package com.aiq.ongi.device.store

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/**
 * 보드 안 저장소 (DEV-09). 파일: /data/data/com.aiq.ongi.device/databases/ongi.db
 *
 *  messages   서버에서 받은 부모 메시지 (id = 서버 message.id). 상황당 1개(설계기준)
 *  play_logs  재생 기록. reported=0이면 아직 서버(API-14)에 못 보낸 것 → 다음 동기화 때 다시 보냄
 *  sync_state 마지막으로 받은 서버 시각(since) 등
 *
 * 기준 문장(anchors)은 파일(anchors.f32)로 두고, 대체 공감(empathy_lines)은 최종본(11/18)이 오면 추가한다.
 * 아이 말 원문은 저장하지 않는다(공통지침: 아이 말은 기기 밖으로 보내지 않고, 기록도 남기지 않음).
 */
class OngiDb(context: Context) : SQLiteOpenHelper(context, "ongi.db", null, 1) {

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """CREATE TABLE messages (
                id INTEGER PRIMARY KEY,
                situation_id INTEGER NOT NULL,
                author TEXT NOT NULL,
                kind TEXT NOT NULL,
                text TEXT,
                audio_path TEXT,
                updated_at TEXT,
                demo INTEGER NOT NULL DEFAULT 0
            )""",
        )
        db.execSQL("CREATE INDEX idx_messages_situation ON messages(situation_id)")
        db.execSQL(
            """CREATE TABLE play_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                message_id INTEGER NOT NULL,
                played_at TEXT NOT NULL,
                reported INTEGER NOT NULL DEFAULT 0
            )""",
        )
        db.execSQL("CREATE TABLE sync_state (key TEXT PRIMARY KEY, value TEXT)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // 첫 버전. 바뀌면 여기서 ALTER
    }

    fun getState(key: String): String? =
        readableDatabase.rawQuery("SELECT value FROM sync_state WHERE key = ?", arrayOf(key)).use { c ->
            if (c.moveToFirst()) c.getString(0) else null
        }

    fun setState(key: String, value: String) {
        writableDatabase.insertWithOnConflict(
            "sync_state", null,
            ContentValues().apply { put("key", key); put("value", value) },
            SQLiteDatabase.CONFLICT_REPLACE,
        )
    }
}
