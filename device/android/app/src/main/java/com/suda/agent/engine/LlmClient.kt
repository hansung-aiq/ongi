package com.suda.agent.engine

/**
 * SUDA 앱의 libLlama2Genie.so를 그대로 부르기 위한 JNI 연결 클래스.
 * 패키지·클래스·함수 이름이 so 안의 Java_com_suda_agent_engine_LlmClient_* 와 같아야 해서 이 이름을 쓴다.
 * (SUDA 앱 분석 11/2: Init(설정 json 경로) → 0이면 성공, Infer(프롬프트) → 답 문자열, UnInit())
 * 우리 코드는 이 클래스를 직접 쓰지 말고 ai_client/GenieLlm 을 쓴다.
 */
class LlmClient {
    external fun Init(configPath: String): Int
    external fun Infer(prompt: String): String
    external fun UnInit()

    companion object {
        init { System.loadLibrary("Llama2Genie") }
    }
}
