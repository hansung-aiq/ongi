package com.aiq.ongi.device.respond

/**
 * 생성 공감 규칙 검사 (판단 규칙 ⑥). ai/tools/check_empathy.py와 같은 규칙.
 * 하나라도 어기면 미리 쓴 공감으로 대체한다.
 * 목록은 ai/tools/empathy_rules.json 임시본과 같다. 최종본(석준 11/4)이 오면 assets에서 읽도록 바꾼다.
 */
object EmpathyChecker {
    private const val MAX_LENGTH = 25
    private val ALLOWED = Regex("^[가-힣 ]+\\??$")

    private val HONORIFIC = listOf("요\\??$", "니다\\??$", "세요", "습니까", "십시오").map { Regex(it) }
    private val ADVICE = listOf(
        "해\\s?봐", "해\\s?보자", "보는\\s?게", "는\\s?게\\s?좋", "게\\s?어때", "해야", "야\\s?해",
        "하렴", "하자", "지\\s?마", "말자", "말아",
    ).map { Regex(it) }
    private val PROMISE = listOf("(할|줄|올|갈|볼|있을|될|도와줄|지켜줄)게", "(^|\\s)꼭\\s", "약속").map { Regex(it) }
    private val PARENT = listOf("엄마", "아빠", "부모님", "어머니", "아버지").map { Regex(it) }
    private val EMOTION = listOf(
        "속상", "슬프", "슬펐", "슬픈", "기쁘", "기뻤", "기쁜", "화나", "화났", "화가", "무섭", "무서", "걱정",
        "외롭", "외로", "서운", "억울", "행복", "신나", "신났", "짜증", "불안", "우울", "창피", "부끄", "답답",
        "섭섭", "그립", "그리웠", "힘들", "괴롭", "괴로", "뿌듯", "자랑스", "설레", "설렜", "놀랐", "실망",
        "마음이\\s?무거", "마음이\\s?아프", "울적", "쓸쓸", "좋았", "즐거",
    ).map { Regex(it) }

    /** 어긴 규칙 목록. 빈 목록이면 통과 */
    fun check(text: String?, feeling: Int): List<String> {
        val t = text?.trim().orEmpty()
        if (t.isEmpty()) return listOf("빈 문장")
        val reasons = mutableListOf<String>()
        if (t.length > MAX_LENGTH) reasons += "길이 ${t.length}자"
        if (!ALLOWED.matches(t)) reasons += "허용 안 되는 문자"
        hit(HONORIFIC, t)?.let { reasons += "존댓말($it)" }
        hit(ADVICE, t)?.let { reasons += "조언·지시($it)" }
        hit(PROMISE, t)?.let { reasons += "약속($it)" }
        hit(PARENT, t)?.let { reasons += "부모 호칭($it)" }
        if (feeling == -1) hit(EMOTION, t)?.let { reasons += "기분 -1인데 감정 단어($it)" }
        return reasons
    }

    private fun hit(patterns: List<Regex>, text: String): String? {
        val nospace = text.replace(" ", "")
        for (p in patterns) {
            val m = p.find(text) ?: p.find(nospace)
            if (m != null) return m.value.trim()
        }
        return null
    }
}
