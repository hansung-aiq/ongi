package com.aiq.ongi.device.respond

/**
 * 미리 쓴 공감(대체용)과 받아주는 말. 임시본.
 * 최종본(기분 6종 × 10 + 받아주는 말 15)은 석준님이 11/18에 주면 store(SQLite empathy_lines)로 옮긴다.
 *
 * 기분: 1 슬픔·속상함 / 2 화남·억울함 / 3 불안·긴장 / 4 지침·무기력 / 5 외로움·그리움 / 6 기쁨·뿌듯함
 * 짚는 말: 아이 기분을 짚어 줌 (부모 메시지 재생 + LLM 기분이 그 상황 허용 기분 안)
 * 열어 두는 말: 기분을 단정하지 않음 (그 밖, 또는 기본 기분을 쓴 경우)
 */
object FallbackLines {
    private val pointed = mapOf(
        1 to listOf("많이 속상했겠다", "마음이 많이 아팠겠다"),
        2 to listOf("정말 억울했겠다", "화날 만했어"),
        3 to listOf("많이 떨렸겠다", "마음이 조마조마했구나"),
        4 to listOf("오늘 많이 지쳤구나", "기운이 하나도 없구나"),
        5 to listOf("많이 보고 싶었구나", "마음이 허전했구나"),
        6 to listOf("정말 뿌듯하겠다", "우와 정말 기쁘겠다"),
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
