package com.aiq.ongi.device.bridge

/**
 * 디바이스 → 앱 신호 8종 (신호 규격서 3장, AB-03 ~ AB-10).
 * toJson()으로 규격서와 같은 JSON 글자를 만든다.
 */
sealed class Signal {
    object Listening : Signal()
    data class Thinking(val text: String) : Signal()
    data class Empathy(val text: String, val hasMessage: Boolean, val author: String?) : Signal()
    data class Playing(
        val situationId: Int,
        val messageId: Int,
        val author: String,
        val kind: String,          // "voice" / "text"
        val text: String?,         // voice면 null
    ) : Signal()
    data class NotFound(val text: String) : Signal()
    object Idle : Signal()
    data class Error(val code: String) : Signal()
    data class Safety(val text: String) : Signal()

    fun toJson(): String = when (this) {
        Listening -> obj("type" to "listening")
        is Thinking -> obj("type" to "thinking", "text" to text)
        is Empathy -> obj("type" to "empathy", "text" to text, "has_message" to hasMessage, "author" to author)
        is Playing -> obj(
            "type" to "playing", "situation_id" to situationId, "message_id" to messageId,
            "author" to author, "kind" to kind, "text" to text,
        )
        is NotFound -> obj("type" to "not_found", "text" to text)
        Idle -> obj("type" to "idle")
        is Error -> obj("type" to "error", "code" to code)
        is Safety -> obj("type" to "safety", "text" to text)
    }

    private fun obj(vararg pairs: Pair<String, Any?>): String =
        pairs.joinToString(", ", "{", "}") { (k, v) -> "\"$k\": ${value(v)}" }

    private fun value(v: Any?): String = when (v) {
        null -> "null"
        is Boolean, is Int -> v.toString()
        else -> "\"" + v.toString()
            .replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n") + "\""
    }
}

/** 신호를 내보내는 곳. 진짜는 SignalServer(WebSocket), 시험할 때는 화면 출력으로 바꿔 끼운다. */
fun interface SignalSink {
    fun send(signal: Signal)
}
