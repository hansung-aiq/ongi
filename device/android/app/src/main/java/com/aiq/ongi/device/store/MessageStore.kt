package com.aiq.ongi.device.store

/** 부모 메시지 한 개 */
data class ParentMessage(
    val id: Int,
    val situationId: Int,
    val author: String,     // "mom" / "dad"
    val kind: String,       // "voice" / "text"
    val text: String?,      // 글 메시지 내용 (voice면 null)
)

/**
 * 보드 안 부모 메시지 저장소.
 * 지금은 시연용 고정 데이터(공통지침 규칙 7). DEV-09에서 SQLite(messages)로 바꾼다.
 */
class MessageStore {
    private val messages = mutableListOf(
        ParentMessage(1, 4, "mom", "voice", null),
        ParentMessage(2, 10, "mom", "voice", null),
        ParentMessage(3, 11, "dad", "text", "민준아, 상 받은 거 정말 축하해. 아빠는 네가 노력한 게 제일 자랑스러워."),
    )

    /** 그 상황의 메시지 (상황과 메시지는 1:1) */
    @Synchronized
    fun find(situationId: Int): ParentMessage? = messages.firstOrNull { it.situationId == situationId }

    @Synchronized
    fun all(): List<ParentMessage> = messages.toList()
}
