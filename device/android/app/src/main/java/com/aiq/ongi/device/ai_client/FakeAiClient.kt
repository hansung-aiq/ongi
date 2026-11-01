package com.aiq.ongi.device.ai_client

/**
 * 가짜 AI 서버. 시연 문장은 정해 둔 답을, 나머지는 단순 규칙으로 답한다.
 * 진짜 LLM처럼 <maum_sep> 뒤에 공감 문장을 붙여 준다.
 */
class FakeAiClient : AiClient {

    private val fixed = mapOf(
        "오늘 친구랑 싸웠어" to "<maum_0>(situation=4, feeling=-1)<maum_sep>친구랑 무슨 일이 있었구나<maum_end>",
        "엄마 보고 싶어" to "<maum_0>(situation=10, feeling=-1)<maum_sep>많이 보고 싶었구나<maum_end>",
        "나 오늘 상 받았어" to "<maum_0>(situation=11, feeling=-1)<maum_sep>상 받았구나 정말 대단하다<maum_end>",
        "배고파" to "<maum_1>()<maum_end>",
        // 규칙 위반 시험용(TC-22): 기분 -1인데 감정 단어 → 기기가 대체 문장으로 바꿔야 함
        "친구랑 싸워서 학교 가기 싫어" to "<maum_0>(situation=4, feeling=-1)<maum_sep>많이 속상했구나<maum_end>",
        // 형식 깨짐 시험용: LLM 실패로 처리돼야 함
        "형식 깨짐 시험" to "situation=4 아무말",
    )

    override fun stt(wav: ByteArray): String = ""

    override fun embed(text: String): FloatArray = FloatArray(384)

    override fun infer(text: String): String {
        Thread.sleep(300)   // 생각하는 시간 흉내
        return fixed[text.trim()] ?: "<maum_1>()<maum_end>"
    }

    override fun tts(text: String): ByteArray = ByteArray(0)
}
