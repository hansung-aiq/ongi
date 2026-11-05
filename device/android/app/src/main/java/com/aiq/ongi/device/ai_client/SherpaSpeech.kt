package com.aiq.ongi.device.ai_client

import com.k2fsa.sherpa.onnx.OfflineModelConfig
import com.k2fsa.sherpa.onnx.OfflineRecognizer
import com.k2fsa.sherpa.onnx.OfflineRecognizerConfig
import com.k2fsa.sherpa.onnx.OfflineSenseVoiceModelConfig
import com.k2fsa.sherpa.onnx.OfflineTts
import com.k2fsa.sherpa.onnx.OfflineTtsConfig
import com.k2fsa.sherpa.onnx.OfflineTtsModelConfig
import com.k2fsa.sherpa.onnx.OfflineTtsVitsModelConfig
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.concurrent.thread

/**
 * 앱 안 STT·TTS (11/5). SUDA 앱과 같은 sherpa-onnx 1.12.7 + SUDA 앱에 들어 있는 모델.
 *   STT: SenseVoice (한·영·중·일·광둥어), 언어 ko 고정
 *   TTS: SUDA 한국어 여자 목소리 (VITS)
 * 모델 위치 (adb push, git 제외): Config.SPEECH_DIR(/data/local/tmp/ongi/speech) 아래
 *   stt/model.int8.onnx, stt/tokens.txt
 *   tts/model.onnx, tts/tokens.txt, tts/espeak-ng-data/
 * 모델이 없으면 준비 안 됨 → LocalAiClient가 가짜로 대신한다(시험 모드는 그대로 동작).
 * 오디오(마이크·스피커)와는 상관없이 wav 데이터만 다룬다. 녹음·재생 방식(A안 tinyalsa / B안 폰)이 정해지면 그쪽에 붙인다.
 */
class SherpaSpeech(
    private val modelDir: File,
    /** 공감 TTS 결과를 저장할 폴더 (adb pull로 맥에서 들어 보기) */
    private val outDir: File,
    private val log: (String) -> Unit = {},
) {
    @Volatile var stt: OfflineRecognizer? = null; private set
    @Volatile var tts: OfflineTts? = null; private set

    val sttReady get() = stt != null
    val ttsReady get() = tts != null

    @Volatile var lastSttMs = 0L; private set
    @Volatile var lastTtsMs = 0L; private set

    /** 뒤에서 한 번 읽기 (STT 240MB, TTS 77MB) */
    fun startLoading() = thread(name = "ongi-speech-load") {
        val sttDir = File(modelDir, "stt")
        val sttModel = File(sttDir, "model.int8.onnx")
        if (sttModel.exists()) {
            try {
                val t0 = System.currentTimeMillis()
                stt = OfflineRecognizer(
                    config = OfflineRecognizerConfig(
                        modelConfig = OfflineModelConfig(
                            senseVoice = OfflineSenseVoiceModelConfig(
                                model = sttModel.absolutePath,
                                language = "ko",
                                useInverseTextNormalization = true,
                            ),
                            tokens = File(sttDir, "tokens.txt").absolutePath,
                            numThreads = 2,
                        ),
                    ),
                )
                log("STT: SenseVoice 준비 완료 (${System.currentTimeMillis() - t0}ms)")
            } catch (e: Throwable) {
                log("STT 읽기 실패 → 가짜: ${e.message}")
            }
        } else {
            log("STT 모델 없음 → 가짜 (${sttModel.absolutePath})")
        }

        val ttsDir = File(modelDir, "tts")
        val ttsModel = File(ttsDir, "model.onnx")
        if (ttsModel.exists()) {
            try {
                val t0 = System.currentTimeMillis()
                tts = OfflineTts(
                    config = OfflineTtsConfig(
                        model = OfflineTtsModelConfig(
                            vits = OfflineTtsVitsModelConfig(
                                model = ttsModel.absolutePath,
                                tokens = File(ttsDir, "tokens.txt").absolutePath,
                                dataDir = File(ttsDir, "espeak-ng-data").absolutePath,
                            ),
                            numThreads = 2,
                        ),
                    ),
                )
                log("TTS: 한국어 목소리 준비 완료 (${System.currentTimeMillis() - t0}ms, ${tts?.sampleRate()}Hz)")
            } catch (e: Throwable) {
                log("TTS 읽기 실패 → 가짜: ${e.message}")
            }
        } else {
            log("TTS 모델 없음 → 가짜 (${ttsModel.absolutePath})")
        }
    }

    /** wav(16비트 PCM, 모노·스테레오, 샘플레이트 아무거나) → 받아쓴 글 */
    @Synchronized
    fun transcribe(wav: ByteArray): String {
        val r = stt ?: error("STT 준비 안 됨")
        val t0 = System.currentTimeMillis()
        val (samples, rate) = Wav.read(wav)
        val s = r.createStream()
        try {
            s.acceptWaveform(samples, rate)     // 16kHz가 아니면 sherpa가 맞춰 줌
            r.decode(s)
            val res = r.getResult(s)
            // 11/5: SenseVoice 결과 text는 한국어 글자 조각 사이에 띄어쓰기가 잘못 들어감("망쳤 어", "친 구랑")
            // → 조각(tokens)의 ▁(새 단어 시작) 표시로 다시 이어 붙인다. 조각이 없으면 원래 text
            val joined = res.tokens.filterNot { it.startsWith("<|") }.joinToString("")
            val text = if (joined.contains('▁')) joined.replace('▁', ' ').replace(Regex(" +"), " ").trim() else res.text.trim()
            if (text != res.text.trim()) log("STT 띄어쓰기 고침: \"${res.text.trim()}\" → \"$text\"")
            lastSttMs = System.currentTimeMillis() - t0
            return text
        } finally {
            s.release()
        }
    }

    /** 글 → wav(16비트 모노). outDir/last_tts.wav에도 저장 */
    @Synchronized
    fun speak(text: String): ByteArray {
        val t = tts ?: error("TTS 준비 안 됨")
        val t0 = System.currentTimeMillis()
        val audio = t.generate(text, sid = 0, speed = 1.0f)
        val bytes = Wav.write(audio.samples, audio.sampleRate)
        lastTtsMs = System.currentTimeMillis() - t0
        try {
            outDir.mkdirs()
            File(outDir, "last_tts.wav").writeBytes(bytes)
        } catch (_: Exception) {}
        return bytes
    }

    fun close() {
        stt?.release(); stt = null
        tts?.release(); tts = null
    }
}

/** 아주 단순한 wav 읽기·쓰기 (16비트 PCM만) */
object Wav {
    /** → (모노 float -1~1, 샘플레이트) */
    fun read(bytes: ByteArray): Pair<FloatArray, Int> {
        val b = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        require(bytes.size > 44 && String(bytes, 0, 4) == "RIFF" && String(bytes, 8, 4) == "WAVE") { "wav 아님" }
        var pos = 12
        var channels = 1; var rate = 16000; var bits = 16
        var dataStart = -1; var dataLen = 0
        while (pos + 8 <= bytes.size) {
            val id = String(bytes, pos, 4)
            val len = b.getInt(pos + 4)
            if (id == "fmt ") {
                channels = b.getShort(pos + 10).toInt()
                rate = b.getInt(pos + 12)
                bits = b.getShort(pos + 22).toInt()
            } else if (id == "data") {
                dataStart = pos + 8
                // 녹음 중에 멈춘 파일은 data 길이가 0이거나 틀릴 수 있음 → 남은 바이트 전부
                dataLen = if (len <= 0 || len > bytes.size - dataStart) bytes.size - dataStart else len
                break
            }
            pos += 8 + len + (len and 1)
        }
        require(dataStart > 0) { "wav data 없음" }
        require(bits == 16) { "16비트 wav만 됨 (지금 ${bits}비트)" }
        val frames = dataLen / (2 * channels)
        val out = FloatArray(frames)
        for (i in 0 until frames) {
            var sum = 0
            for (c in 0 until channels) sum += b.getShort(dataStart + (i * channels + c) * 2).toInt()
            out[i] = sum / (channels * 32768f)
        }
        return out to rate
    }

    fun write(samples: FloatArray, rate: Int): ByteArray {
        val data = ByteBuffer.allocate(samples.size * 2).order(ByteOrder.LITTLE_ENDIAN)
        for (s in samples) data.putShort((s.coerceIn(-1f, 1f) * 32767).toInt().toShort())
        val h = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
        h.put("RIFF".toByteArray()); h.putInt(36 + samples.size * 2); h.put("WAVE".toByteArray())
        h.put("fmt ".toByteArray()); h.putInt(16); h.putShort(1); h.putShort(1)
        h.putInt(rate); h.putInt(rate * 2); h.putShort(2); h.putShort(16)
        h.put("data".toByteArray()); h.putInt(samples.size * 2)
        return ByteArrayOutputStream().apply { write(h.array()); write(data.array()) }.toByteArray()
    }
}
