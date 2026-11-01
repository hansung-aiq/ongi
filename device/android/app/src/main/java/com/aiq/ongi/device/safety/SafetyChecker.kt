package com.aiq.ongi.device.safety

/**
 * 위기 표현 확인 (판단 규칙 ①). 걸리면 다른 판단 없이 안전 응답만 하고 끝낸다.
 * 목록은 임시본. 최종 목록은 석준님 situations.json(11/4)과 함께 정한다.
 */
class SafetyChecker(
    private val patterns: List<Regex> = DEFAULT_PATTERNS,
) {
    fun isCrisis(text: String): Boolean {
        val nospace = text.replace(" ", "")
        return patterns.any { it.containsMatchIn(text) || it.containsMatchIn(nospace) }
    }

    companion object {
        val DEFAULT_PATTERNS = listOf(
            "죽고\\s?싶", "죽어\\s?버리", "죽을래", "살기\\s?싫",
            "사라지고\\s?싶", "없어지고\\s?싶", "자해",
        ).map { Regex(it) }

        const val SAFETY_TEXT =
            "지금 많이 힘들구나. 혼자 견디지 않아도 돼. 청소년 상담전화 1388에 전화하면 언제든 이야기를 들어줄 거야."
    }
}
