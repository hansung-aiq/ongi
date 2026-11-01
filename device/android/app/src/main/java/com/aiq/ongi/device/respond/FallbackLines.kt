package com.aiq.ongi.device.respond

/**
 * 미리 쓴 공감(대체용)과 받아주는 말. 임시본.
 * 최종본(기분 6종 × 10 + 받아주는 말 15)은 석준님이 11/18에 주면 store(SQLite empathy_lines)로 옮긴다.
 *
 * 짚는 말: 아이 기분을 짚어 줌 (부모 메시지 재생 + 기분이 그 상황에 맞을 때)
 * 열어 두는 말: 기분을 단정하지 않음 (그 밖의 경우)
 */
object FallbackLines {
    private val pointed = mapOf(
        1 to listOf("많이 속상했겠다", "마음이 많이 상했겠다"),
        2 to listOf("많이 서운했구나", "마음이 쓸쓸했겠다"),
        3 to listOf("정말 기뻤겠다", "신나는 일이 있었구나"),
        4 to listOf("많이 화가 났구나", "정말 억울했겠다"),
        5 to listOf("많이 무서웠겠다", "걱정이 많았구나"),
        6 to listOf("많이 힘들었겠다", "오늘 많이 지쳤구나"),
    )

    private val open = listOf(
        "오늘 그런 일이 있었구나",
        "이야기해 줘서 고마워",
        "그랬구나 들려줘서 고마워",
    )

    private val acknowledge = listOf(
        "그런 날도 있지, 이야기해 줘서 고마워",
        "그랬구나, 들려줘서 고마워",
    )

    fun pointed(feeling: Int): String = pointed[feeling]?.random() ?: open.random()
    fun open(): String = open.random()
    fun acknowledge(): String = acknowledge.random()
}
