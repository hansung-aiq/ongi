package com.aiq.ongi.device.judge

/** 상황 하나의 정보 (situations.json의 situations 한 줄, 설계기준 v1.1 2장) */
data class SituationRule(
    val id: Int,
    val name: String,
    val keywords: List<String>,
    val exclude: List<String> = emptyList(),        // 그 부분만 지우고 다시 봄 (예: 눈싸움)
    val block: List<String> = emptyList(),          // 있으면 그 상황 아님 (예: 동생이, 매운 거 먹어서)
    val allowedFeelings: List<Int> = emptyList(),   // 짚는 말을 쓸 수 있는 기분
    val defaultFeeling: Int = -1,                   // 기분을 모를 때 쓰는 기분
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
            if (rule.block.any { base.contains(squash(it)) }) return@filter false
            var t = base
            rule.exclude.forEach { t = t.replace(squash(it), " ") }   // 제외어를 먼저 지운다
            rule.keywords.any { t.contains(squash(it)) }
        }.map { it.id }.toSet()
        return priority.filter { it in hit } + hit.filter { it !in priority }
    }

    /** 최종 판단 상황. 없으면 null */
    fun judge(text: String): Int? = matches(text).firstOrNull()

    fun rule(id: Int): SituationRule? = rules.firstOrNull { it.id == id }

    fun nameOf(id: Int): String = rule(id)?.name ?: "상황 $id"

    private fun squash(s: String) = s.replace(" ", "")

    companion object {
        /** assets를 못 읽을 때 쓰는 기본값 (situations.json 임시본과 같음) */
        val PRIORITY = listOf(12, 2, 3, 4, 5, 6, 11, 10, 1, 7, 8, 9)

        val TEMP_RULES: List<SituationRule> = listOf(
            SituationRule(1, "학교 가기 싫은 날",
                listOf("학교 가기 싫", "학교 가는 게 싫", "학교 안 가고 싶", "학교 쉬고 싶", "학교 안 가면"),
                allowedFeelings = listOf(2, 3, 4), defaultFeeling = 4),
            SituationRule(2, "실수해서 혼났을 때", listOf("혼났", "혼나", "혼내", "혼냈", "야단맞", "꾸중"),
                block = listOf("동생이 엄마", "동생이 아빠", "동생이 선생님", "짝꿍이", "형이", "누나가", "언니가", "오빠가", "만화에서", "영화에서", "떠든 애들", "안 혼났", "동생 꾸중"),
                allowedFeelings = listOf(1, 2, 3), defaultFeeling = 1),
            SituationRule(3, "시험을 망친 날",
                listOf("시험 망", "시험을 망", "시험 완전 망", "시험 못 봤", "시험 못 쳤", "빵점"),
                block = listOf("동생이 시험", "형이", "누나가", "언니가", "오빠가", "망쳤대"),
                allowedFeelings = listOf(1, 2, 3, 4), defaultFeeling = 1),
            SituationRule(4, "친구와 싸운 날", listOf("싸웠", "싸워", "싸움", "다퉜", "다퉈"),
                listOf("눈싸움", "베개싸움", "물싸움", "닭싸움"),
                block = listOf("만화에서", "영화에서"),
                allowedFeelings = listOf(1, 2), defaultFeeling = 1),
            SituationRule(5, "친구가 날 싫어하는 것 같을 때",
                listOf("나만 빼고", "나랑 안 놀", "안 끼워", "따돌", "왕따", "뒷담", "나 무시", "날 싫어", "나를 싫어", "나 싫어하"),
                allowedFeelings = listOf(1, 2, 3), defaultFeeling = 1),
            SituationRule(6, "남들과 비교될 때", listOf("비교", "누구는 잘하는데", "누구는 하는데"),
                allowedFeelings = listOf(1, 2), defaultFeeling = 1),
            SituationRule(7, "울고 싶은 날", listOf("울었", "눈물", "울고 싶", "울 것 같"),
                block = listOf("양파", "웃겨서", "하품", "매운", "동생이 울", "만화에서", "영화에서"),
                allowedFeelings = listOf(1, 2), defaultFeeling = 1),
            SituationRule(8, "아무것도 하기 싫은 날", listOf("아무것도 하기 싫", "아무것도 안 하고 싶", "다 하기 싫", "의욕"),
                allowedFeelings = listOf(2, 4), defaultFeeling = 4),
            SituationRule(9, "잠이 안 오는 밤", listOf("잠이 안", "못 자", "잠 안 와", "무서운 꿈"),
                allowedFeelings = listOf(2, 3), defaultFeeling = 3),
            SituationRule(10, "부모님이 보고 싶을 때", listOf("보고 싶", "보고싶"),
                allowedFeelings = listOf(5), defaultFeeling = 5),
            SituationRule(11, "자랑하고 싶은 날", listOf("상 받", "상받", "칭찬 받", "칭찬받", "1등", "백점", "100점"),
                listOf("동생이 칭찬", "친구가 상", "동생이 상"),
                allowedFeelings = listOf(6), defaultFeeling = 6),
            SituationRule(12, "생일", listOf("생일"), listOf("생일 선물 사러", "친구 생일", "동생 생일"),
                block = listOf("엄마 생일", "아빠 생일", "짝꿍 생일", "형 생일", "누나 생일", "언니 생일", "오빠 생일", "생일 파티 초대", "생일이 언제"),
                allowedFeelings = listOf(5, 6), defaultFeeling = 6),
        )
    }
}
