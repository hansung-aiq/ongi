package com.aiq.ongi.device.safety

/**
 * 위기 표현 확인 (판단 규칙 ①). 걸리면 다른 판단 없이 안전 응답만 하고 끝낸다.
 * 목록은 assets/situations.json의 "crisis"에서 읽는다(임시본, 최종본은 석준 11/4).
 */
class SafetyChecker(
    private val patterns: List<Regex> = DEFAULT_PATTERNS,
) {
    fun isCrisis(text: String): Boolean {
        val nospace = text.replace(" ", "")
        return patterns.any { it.containsMatchIn(text) || it.containsMatchIn(nospace) }
    }

    companion object {
        /** "죽고 싶" → 띄어쓰기가 있어도 없어도 걸리는 정규식으로 */
        fun compile(words: List<String>): List<Regex> =
            words.filter { it.isNotBlank() }.map { w ->
                Regex(w.trim().split(Regex("\\s+")).joinToString("\\s?") { Regex.escape(it) })
            }

        val DEFAULT_PATTERNS = compile(
            listOf("죽고 싶", "죽어 버리", "죽을래", "살기 싫", "사라지고 싶", "없어지고 싶", "자해"),
        )

        const val SAFETY_TEXT =
            "지금 많이 힘들구나. 혼자 견디지 않아도 돼. 청소년 상담전화 1388에 전화하면 언제든 이야기를 들어줄 거야."
    }
}
