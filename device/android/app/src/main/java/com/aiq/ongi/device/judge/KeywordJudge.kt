package com.aiq.ongi.device.judge

/**
 * 키워드 판단 (판단 규칙 ②, DEV-07).
 * - 한 상황만 걸리면 그 상황
 * - 여러 상황이 걸리면 우선순위: 생일(12) > 사건(2~6, 11) > 그리움(10) > 반응(1, 7~9)
 * - 아무것도 안 걸리면 null (다음 단계인 임베딩 판단으로 넘김, DEV-08)
 *
 * 키워드는 임시본. 석준님 situations.json(11/4)이 오면 그 파일에서 읽도록 바꾼다.
 */
class KeywordJudge(
    private val keywords: Map<Int, List<String>> = TEMP_KEYWORDS,
) {
    /** 걸린 상황 번호 전부 (우선순위 순서) */
    fun matches(text: String): List<Int> {
        val nospace = text.replace(" ", "")
        val hit = keywords.filter { (_, words) ->
            words.any { w -> nospace.contains(w.replace(" ", "")) }
        }.keys
        return PRIORITY.filter { it in hit }
    }

    /** 최종 판단 상황. 없으면 null */
    fun judge(text: String): Int? = matches(text).firstOrNull()

    companion object {
        /** 같은 줄 안에서는 앞에 있는 번호가 먼저 */
        val PRIORITY = listOf(12, 2, 3, 4, 5, 6, 11, 10, 1, 7, 8, 9)

        val TEMP_KEYWORDS: Map<Int, List<String>> = mapOf(
            1 to listOf("학교 가기 싫", "학교 안 가고 싶"),
            2 to listOf("혼났", "혼나", "혼내", "야단맞"),
            3 to listOf("따돌", "왕따", "안 끼워", "나만 빼고"),
            4 to listOf("싸웠", "싸워", "싸움", "다퉜", "다퉈"),
            5 to listOf("시험 망", "시험을 망", "시험 못 봤", "빵점"),
            6 to listOf("비교", "누구는 잘하는데"),
            7 to listOf("울었", "눈물", "울고 싶"),
            8 to listOf("아무것도 하기 싫", "귀찮아", "의욕"),
            9 to listOf("잠이 안", "못 자", "무서운 꿈"),
            10 to listOf("보고 싶", "보고싶"),
            11 to listOf("상 받", "상받", "칭찬 받", "1등"),
            12 to listOf("생일"),
        )
    }
}
