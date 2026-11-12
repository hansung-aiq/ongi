package com.aiq.ongi.device.respond

/** LLM 답을 나눈 결과 */
data class InferResult(
    val general: Boolean,      // <maum_1> 일반 대화
    val situation: Int,        // -1이면 상황 없음
    val feeling: Int,          // -1이면 기분 없음
    val empathy: String?,      // <maum_sep> 뒤 공감 문장
)

/**
 * /infer 답 파싱. 모양이 깨지면 null(= LLM 실패로 처리).
 * <maum_(\d)>\((.*?)\)(?:<maum_sep>(.*?))?(<maum_end>|끝)
 * Genie는 eos 토큰(<maum_end>, id 128265)에서 멈추고 그 토큰을 출력에 넣지 않는다 → <maum_end> 없이 끝나도 허용.
 * 보드 시험(11/2): 예제 모델 출력 "<maum_1>()" (끝 토큰 없음)
 */
object InferParser {
    private val SHAPE = Regex("<maum_(\\d)>\\((.*?)\\)(?:<maum_sep>(.*?))?(?:<maum_end>|<\\|eot_id\\|>|<\\|end_of_text\\|>|$)", RegexOption.DOT_MATCHES_ALL)
    private val SITUATION = Regex("situation\\s*=\\s*(-?\\d+)")
    private val FEELING = Regex("feeling\\s*=\\s*(-?\\d+)")

    fun parse(output: String?): InferResult? {
        val m = SHAPE.find(output ?: return null) ?: return null
        val kind = m.groupValues[1]
        if (kind == "1") return InferResult(general = true, situation = -1, feeling = -1, empathy = null)
        if (kind != "0") return null
        val args = m.groupValues[2]
        val situation = SITUATION.find(args)?.groupValues?.get(1)?.toIntOrNull() ?: return null
        val feeling = FEELING.find(args)?.groupValues?.get(1)?.toIntOrNull() ?: return null
        if (situation !in -1..12 || situation == 0 || feeling !in -1..6 || feeling == 0) return null
        val empathy = m.groupValues[3].trim().ifEmpty { null }
        return InferResult(general = false, situation = situation, feeling = feeling, empathy = empathy)
    }
}
