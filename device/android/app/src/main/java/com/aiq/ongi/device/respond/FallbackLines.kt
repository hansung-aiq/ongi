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

    /**
     * 시연 4개 상황 대체 공감 (11/5 확정). 공감 규칙(25자, 한글·공백, 반말, 조언·약속·부모 호칭·물음표 없음) 통과.
     * 쓰는 때: 키워드가 잡았는데 LLM이 다르게 답함(판단 규칙 A) / LLM 실패 / 생성 공감이 규칙을 어김
     * 학습 정답 문장(시험을 망쳐서 속상했구나 등)과 겹치지 않게 써서, 로그 없이도 생성인지 대체인지 구분된다.
     */
    private val bySituation = mapOf(
        3 to listOf("시험 때문에 많이 속상했구나", "열심히 했는데 속상했겠다", "시험이 마음처럼 안 됐구나"),
        4 to listOf("친구랑 다퉈서 속상했겠다", "마음이 많이 상했겠다", "친구랑 싸워서 마음이 아팠구나"),
        10 to listOf("많이 보고 싶었구나", "보고 싶은 마음이 크구나", "많이 그리웠구나"),
        11 to listOf("정말 뿌듯하겠다", "우와 정말 잘했구나", "오늘 정말 기쁜 날이구나"),
    )

    /** 시연 상황이면 그 상황 문장, 아니면 null */
    fun forSituation(situation: Int?): String? = situation?.let { bySituation[it]?.random() }

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
