package com.aiq.ongi.device.ai_client

/**
 * 앱 안 AI 모듈 (11/2 결정: 별도 AI 서버 대신 디바이스 앱 안에서 모델을 부른다).
 * 다 만들어진 부분만 진짜로, 나머지는 가짜(FakeAiClient)로 넘긴다.
 *   embed : OnnxEmbedder (DEV-08)          ← 진짜
 *   infer : 학습 모델(Genie)이 오기 전까지 가짜
 *   stt / tts : sherpa-onnx (오디오 해결 후)
 */
class LocalAiClient(
    private val embedder: OnnxEmbedder?,
    private val fallback: AiClient = FakeAiClient(),
) : AiClient {
    override fun stt(wav: ByteArray): String = fallback.stt(wav)
    override fun embed(text: String): FloatArray = embedder?.embed(text) ?: fallback.embed(text)
    override fun infer(text: String): String = fallback.infer(text)
    override fun tts(text: String): ByteArray = fallback.tts(text)

    val hasEmbedder get() = embedder != null
}
