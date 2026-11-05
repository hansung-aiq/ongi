package com.aiq.ongi.device.ai_client

import com.aiq.ongi.device.Config

/**
 * 앱 안 AI 모듈 (11/2 결정: 별도 AI 서버 대신 디바이스 앱 안에서 모델을 부른다).
 *   embed : OnnxEmbedder (DEV-08)                    ← 진짜
 *   infer : Config.useGenie && Genie 준비됨 → Genie   ← 진짜 / 아니면 가짜(FakeAiClient)
 *   stt / tts : SherpaSpeech (11/5, SUDA와 같은 sherpa-onnx + SUDA 모델) ← 모델 있으면 진짜 / 없으면 가짜
 */
class LocalAiClient(
    private val embedder: OnnxEmbedder?,
    private val genie: GenieLlm? = null,
    private val speech: SherpaSpeech? = null,
    private val log: (String) -> Unit = {},
    private val fallback: AiClient = FakeAiClient(),
) : AiClient {
    override fun stt(wav: ByteArray): String {
        val s = speech
        return if (s != null && s.sttReady) s.transcribe(wav) else fallback.stt(wav)
    }
    override fun embed(text: String): FloatArray = embedder?.embed(text) ?: fallback.embed(text)

    override fun infer(text: String): String {
        val g = genie
        if (!Config.useGenie || g == null || !g.ready) return fallback.infer(text)
        val out = g.infer(text)   // 실패·시간 초과는 예외 → 흐름이 "LLM 실패"로 처리
        log("LLM(Genie) ${g.lastMs}ms: ${out.take(200)}")
        return out
    }

    override fun tts(text: String): ByteArray {
        val s = speech
        return if (s != null && s.ttsReady) s.speak(text) else fallback.tts(text)
    }

    val hasEmbedder get() = embedder != null
}
