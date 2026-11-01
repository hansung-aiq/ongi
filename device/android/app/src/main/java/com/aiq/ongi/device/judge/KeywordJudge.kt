package com.aiq.ongi.device.judge

/** 상황 하나의 키워드 정보 (situations.json의 situations 한 줄) */
data class SituationRule(
    val id: Int,
    val name: String,
    val keywords: List<String>,
    val exclude: List<String> = emptyList(),   // 키워드가 있어도 상황이 아닌 말 (예: 눈싸움)
)

/**
 * 키워드 판단 (판단 규칙 ②, DEV-07).
 * - 위기 표현은 이보다 먼저 SafetyChecker가 본다
 * - 한 상황만 걸리면 그 상황
 * - 여러 상황이 걸리면 우선순위: 생일(12) > 사건(2~6, 11) > 그리움(10) > 반응(1, 7~9)
 * - 아무것도 안 걸리면 null (다음 단계인 임베딩 판단으로 넘김, DEV-08)
 *
 * 띄어쓰기는 지우고 비교한다(받아쓰기 띄어쓰기가 들쭉날쭉하므로).
 * 키워드·제외어·우선순위는 assets/situations.json에서 읽는다(SituationConfig).
 */
class KeywordJudge(
    private val rules: List<SituationRule> = TEMP_RULES,
    private val priority: List<Int> = PRIORITY,
) {
    /** 걸린 상황 번호 전부 (우선순위 순서) */
    fun matches(text: String): List<Int> {
        val base = squash(text)
        val hit = rules.filter { rule ->
            var t = base
            rule.exclude.forEach { t = t.replace(squash(it), " ") }   // 제외어를 먼저 지운다
            rule.keywords.any { t.contains(squash(it)) }
        }.map { it.id }.toSet()
        return priority.filter { it in hit } + hit.filter { it !in priority }
    }

    /** 최종 판단 상황. 없으면 null */
    fun judge(text: String): Int? = matches(text).firstOrNull()

    fun nameOf(id: Int): String = rules.firstOrNull { it.id == id }?.name ?: "상황 $id"

    private fun squash(s: String) = s.replace(" ", "")

    companion object {
        /** assets를 못 읽을 때 쓰는 기본값 (situations.json 임시본과 같음) */
        val PRIORITY = listOf(12, 2, 3, 4, 5, 6, 11, 10, 1, 7, 8, 9)

        val TEMP_RULES: List<SituationRule> = listOf(
            SituationRule(1, "학교 가기 싫을 때", listOf("학교 가기 싫", "학교 안 가고 싶")),
            SituationRule(2, "혼났을 때", listOf("혼났", "혼나", "혼내", "혼냈", "야단맞")),
            SituationRule(3, "따돌림당했을 때", listOf("따돌", "왕따", "안 끼워", "나만 빼고")),
            SituationRule(4, "친구랑 싸웠을 때", listOf("싸웠", "싸워", "싸움", "다퉜", "다퉈"),
                listOf("눈싸움", "베개싸움", "물싸움", "닭싸움")),
            SituationRule(5, "시험을 망쳤을 때", listOf("시험 망", "시험을 망", "시험 못 봤", "빵점")),
            SituationRule(6, "비교당했을 때", listOf("비교", "누구는 잘하는데")),
            SituationRule(7, "울고 싶을 때", listOf("울었", "눈물", "울고 싶")),
            SituationRule(8, "아무것도 하기 싫을 때", listOf("아무것도 하기 싫", "귀찮아", "의욕")),
            SituationRule(9, "잠이 안 올 때", listOf("잠이 안", "못 자", "무서운 꿈")),
            SituationRule(10, "보고 싶을 때", listOf("보고 싶", "보고싶")),
            SituationRule(11, "자랑하고 싶을 때", listOf("상 받", "상받", "칭찬 받", "1등")),
            SituationRule(12, "생일", listOf("생일"), listOf("생일 선물 사러", "친구 생일")),
        )
    }
}
