package com.aiq.ongi.device.ai_client

/**
 * 가짜 AI 서버. 시연 문장은 정해 둔 답을, 나머지는 단순 규칙으로 답한다.
 * 진짜 LLM처럼 <maum_sep> 뒤에 공감 문장을 붙여 준다.
 */
class FakeAiClient : AiClient {

    private val fixed = mapOf(
        // 시연 문장 4개 (11/5, v3.7 학습 정답과 똑같은 답. 학습 모델이 오면 이 답이 나와야 정상)
        "나 오늘 시험 망쳤어" to "<maum_0>(situation=3, feeling=1)<maum_sep>시험을 망쳐서 속상했구나<maum_end>",
        "오늘 친구랑 싸웠어" to "<maum_0>(situation=4, feeling=1)<maum_sep>친구랑 싸워서 속상했구나<maum_end>",
        "엄마 보고 싶어" to "<maum_0>(situation=10, feeling=5)<maum_sep>엄마가 많이 보고 싶구나<maum_end>",   // 아이가 말한 호칭 → 허용
        "나 오늘 상 받았어" to "<maum_0>(situation=11, feeling=6)<maum_sep>오늘 상을 받은 날이구나<maum_end>",
        // 11/5 판단 규칙 A 시험: 키워드는 3번인데 LLM이 일반 대화라고 답함 → 키워드 우선, 대체 공감 + 메시지
        "시험 완전 망했어" to "<maum_1>()<maum_end>",
        // 11/2 규칙 시험: 아이가 말하지 않은 호칭 → 대체 / 물음표 → 대체
        "선생님한테 혼났어" to "<maum_0>(situation=2, feeling=-1)<maum_sep>엄마한테 혼났구나<maum_end>",
        "물음표 시험" to "<maum_0>(situation=3, feeling=-1)<maum_sep>어떤 문제가 어려웠어?<maum_end>",
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
        // 11/5: STT 글은 끝에 마침표가 붙거나 띄어쓰기가 다를 수 있어서, 띄어쓰기·문장부호를 빼고 비교
        val key = norm(text)
        return fixed.entries.firstOrNull { norm(it.key) == key }?.value ?: "<maum_1>()<maum_end>"
    }

    override fun tts(text: String): ByteArray = ByteArray(0)

    private fun norm(s: String) = s.replace(Regex("[\\s.,!?~。]"), "")
}
