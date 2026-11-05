package com.aiq.ongi.device.audio

import com.aiq.ongi.device.ai_client.Wav
import com.k2fsa.sherpa.onnx.SileroVadModelConfig
import com.k2fsa.sherpa.onnx.Vad
import com.k2fsa.sherpa.onnx.VadModelConfig
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * 진짜 마이크로 듣기 (11/5, A안). 말이 끝나면 바로 녹음을 멈춘다.
 *   도우미가 tinycap으로 rec.wav(48kHz 모노)를 쓰는 동안 → 앱이 늘어나는 부분을 0.1초마다 읽어
 *   → 16kHz로 줄여 VAD(silero, SUDA 앱 모델)에 넣고 → 말을 한 뒤 조용함이 END_SILENCE_MS 이어지면 멈춤
 *   VAD 모델이 없으면 소리 크기(RMS)로 판단한다.
 * 결과: 16kHz 모노 wav 바이트 (STT에 그대로)
 *
 * 사운드카드 없이 시험: stream(파일) — wav 파일을 실제 시간처럼 0.1초씩 넣어 같은 판단을 해 본다.
 */
class MicListener(
    private val speaker: TinyAlsaHelper?,
    vadModel: File?,
    private val log: (String) -> Unit = {},
) {
    companion object {
        const val MAX_SEC = 8              // 최대 녹음
        const val NO_SPEECH_SEC = 5.0      // 이 시간 안에 말이 없으면 그만
        const val END_SILENCE_MS = 800     // 말한 뒤 이만큼 조용하면 끝
        const val RMS_SPEECH = 0.02f       // VAD가 없을 때 쓰는 소리 크기 기준
    }

    private val vad: Vad? = vadModel?.takeIf { it.exists() }?.let {
        try {
            Vad(config = VadModelConfig(
                sileroVadModelConfig = SileroVadModelConfig(model = it.absolutePath, threshold = 0.5f, minSilenceDuration = 0.25f, minSpeechDuration = 0.2f),
                sampleRate = 16000,
            )).also { log("VAD: silero 준비 완료") }
        } catch (e: Throwable) { log("VAD 읽기 실패 → 소리 크기로 판단: ${e.message}"); null }
    } ?: run { log("VAD 모델 없음 → 소리 크기로 판단"); null }

    /** 말 끝 판단기 (한 번 듣기마다 새로) */
    private inner class Endpoint {
        val pcm = ArrayList<Float>()
        var speechSeen = false
        var lastSpeechAt = 0.0
        var t = 0.0
        fun feed(s16k: FloatArray): Boolean {     // true면 끝
            s16k.forEach { pcm.add(it) }
            t += s16k.size / 16000.0
            val speaking = vad?.let { it.acceptWaveform(s16k); it.isSpeechDetected() }
                ?: (Math.sqrt(s16k.map { (it * it).toDouble() }.average()) > RMS_SPEECH)
            if (speaking) { speechSeen = true; lastSpeechAt = t }
            return when {
                speechSeen && (t - lastSpeechAt) * 1000 >= END_SILENCE_MS -> true
                !speechSeen && t >= NO_SPEECH_SEC -> true
                t >= MAX_SEC -> true
                else -> false
            }
        }
        fun result(): ByteArray? {
            vad?.reset()
            if (!speechSeen) return null
            // 끝의 조용한 부분은 잘라서 보냄(STT가 빨라짐)
            val keep = minOf(pcm.size, ((lastSpeechAt + 0.3) * 16000).toInt())
            return Wav.write(FloatArray(keep) { pcm[it] }, 16000)
        }
    }

    /** 마이크로 듣기. 말을 안 했거나 실패하면 null */
    @Synchronized
    fun listen(): ByteArray? {
        val spk = speaker?.takeIf { it.alive } ?: run { log("마이크: 오디오 도우미 꺼짐"); return null }
        val file = spk.recFile
        if (!spk.startRecord(MAX_SEC + 1)) return null
        val ep = Endpoint()
        var pos = 44L
        var carry = ByteArray(0)
        val t0 = System.currentTimeMillis()
        // 파일이 생길 때까지 잠깐
        while (!file.exists() && System.currentTimeMillis() - t0 < 2000) Thread.sleep(20)
        var reason = "최대 ${MAX_SEC}초"
        try {
            while (System.currentTimeMillis() - t0 < (MAX_SEC + 2) * 1000L) {
                Thread.sleep(100)
                val len = file.length()
                if (len > pos) {
                    val buf = ByteArray((len - pos).toInt())
                    RandomAccessFile(file, "r").use { it.seek(pos); it.readFully(buf) }
                    pos = len
                    val all = carry + buf
                    val usable = all.size / 6 * 6            // 48kHz 16비트 모노 3샘플(6바이트) = 16kHz 1샘플
                    carry = all.copyOfRange(usable, all.size)
                    if (ep.feed(down3(all, usable))) {
                        reason = if (ep.speechSeen) "말 끝(${END_SILENCE_MS}ms 조용)" else "${NO_SPEECH_SEC}초 동안 말 없음"
                        break
                    }
                }
            }
        } finally {
            spk.stop()
        }
        spk.waitRecord(2000)
        val ms = System.currentTimeMillis() - t0
        log("마이크: ${"%.1f".format(ep.t)}초 듣고 멈춤 — $reason, 말 ${if (ep.speechSeen) "있음" else "없음"} (${ms}ms)")
        return ep.result()
    }

    /** 시험용: wav 파일을 실제 시간처럼 0.1초씩 넣어 말 끝 판단을 해 봄 */
    fun stream(wavBytes: ByteArray, realtime: Boolean = true): ByteArray? {
        val (s, rate) = Wav.read(wavBytes)
        val s16 = if (rate == 16000) s else FloatArray((s.size.toLong() * 16000 / rate).toInt()) { s[(it.toLong() * rate / 16000).toInt().coerceAtMost(s.size - 1)] }
        val ep = Endpoint()
        val step = 1600
        var i = 0
        var reason = "파일 끝"
        val t0 = System.currentTimeMillis()
        while (i < s16.size) {
            val chunk = s16.copyOfRange(i, minOf(i + step, s16.size)); i += step
            if (realtime) Thread.sleep(100)
            if (ep.feed(chunk)) { reason = if (ep.speechSeen) "말 끝(${END_SILENCE_MS}ms 조용)" else "말 없음"; break }
        }
        log("마이크 시험(파일): 전체 ${"%.1f".format(s16.size / 16000.0)}초 중 ${"%.1f".format(ep.t)}초에 멈춤 — $reason (${System.currentTimeMillis() - t0}ms)")
        return ep.result()
    }

    /** 48kHz 16비트 바이트 → 16kHz float (3개 평균) */
    private fun down3(b: ByteArray, n: Int): FloatArray {
        val bb = ByteBuffer.wrap(b, 0, n).order(ByteOrder.LITTLE_ENDIAN)
        val out = FloatArray(n / 6)
        for (k in out.indices) {
            val a = bb.getShort(k * 6).toInt(); val c = bb.getShort(k * 6 + 2).toInt(); val d = bb.getShort(k * 6 + 4).toInt()
            out[k] = (a + c + d) / (3 * 32768f)
        }
        return out
    }

    fun close() { vad?.release() }
}
