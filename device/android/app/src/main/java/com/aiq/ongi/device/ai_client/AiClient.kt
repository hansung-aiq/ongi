package com.aiq.ongi.device.ai_client

/**
 * 보드 안 AI 서버(석준, 127.0.0.1:8081)를 부르는 곳. AI를 부르는 코드는 여기에만 둔다.
 * 지금은 FakeAiClient를 쓰고, AI 서버가 생기면 HttpAiClient로 바꿔 끼운다(DEV-08).
 */
interface AiClient {
    /** 16kHz wav → 받아쓴 글 (POST /stt) */
    fun stt(wav: ByteArray): String

    /** 글 → 384차원 벡터 (POST /embed) */
    fun embed(text: String): FloatArray

    /** 글 → LLM 출력 원문 (POST /infer)
     *  예: <maum_0>(situation=4, feeling=-1)<maum_sep>친구랑 무슨 일이 있었구나<maum_end> */
    fun infer(text: String): String

    /** 글 → wav (POST /tts) */
    fun tts(text: String): ByteArray
}
