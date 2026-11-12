package com.aiq.ongi.device.ai_client

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * 재생할 소리를 보드 스피커 형식으로 맞춘다 (11/5, 오디오 A안 준비).
 * USB 사운드카드는 재생이 48kHz·스테레오·16비트만 된다(10/30 조사) →
 *   부모 녹음(m4a) : MediaCodec으로 풀기 → 48kHz 스테레오 wav
 *   TTS(22050Hz 모노 wav) → 48kHz 스테레오 wav
 * 결과 wav는 tinyplay로 그대로 튼다(A안). 사운드카드가 없을 때는 파일만 만들고 맥에서 들어 본다.
 */
object AudioPrep {
    const val OUT_RATE = 48000

    /** 모노 소리 (-1~1) */
    class Mono(val samples: FloatArray, val rate: Int) {
        val seconds get() = samples.size.toDouble() / rate
    }

    /** m4a(AAC) 등 압축 소리 파일 → 모노 */
    fun decode(file: File): Mono {
        val ex = MediaExtractor()
        ex.setDataSource(file.absolutePath)
        val track = (0 until ex.trackCount).firstOrNull {
            ex.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
        } ?: run { ex.release(); error("소리 트랙 없음: ${file.name}") }
        ex.selectTrack(track)
        val fmt = ex.getTrackFormat(track)
        var rate = fmt.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        var ch = fmt.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        val codec = MediaCodec.createDecoderByType(fmt.getString(MediaFormat.KEY_MIME)!!)
        codec.configure(fmt, null, null, 0)
        codec.start()
        val pcm = ByteArrayOutputStream()
        val info = MediaCodec.BufferInfo()
        var inDone = false
        var outDone = false
        var guard = 0
        try {
            while (!outDone && guard++ < 200_000) {
                if (!inDone) {
                    val i = codec.dequeueInputBuffer(10_000)
                    if (i >= 0) {
                        val buf = codec.getInputBuffer(i)!!
                        val n = ex.readSampleData(buf, 0)
                        if (n < 0) {
                            codec.queueInputBuffer(i, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inDone = true
                        } else {
                            codec.queueInputBuffer(i, 0, n, ex.sampleTime, 0)
                            ex.advance()
                        }
                    }
                }
                val o = codec.dequeueOutputBuffer(info, 10_000)
                if (o >= 0) {
                    if (info.size > 0) {
                        val b = codec.getOutputBuffer(o)!!
                        val arr = ByteArray(info.size)
                        b.position(info.offset)
                        b.get(arr)
                        pcm.write(arr)
                    }
                    codec.releaseOutputBuffer(o, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outDone = true
                } else if (o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    val f = codec.outputFormat
                    rate = f.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    ch = f.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                }
            }
        } finally {
            codec.stop(); codec.release(); ex.release()
        }
        val bytes = pcm.toByteArray()
        val bb = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        val frames = bytes.size / (2 * ch)
        val out = FloatArray(frames)
        for (i in 0 until frames) {
            var s = 0
            for (c in 0 until ch) s += bb.getShort((i * ch + c) * 2).toInt()
            out[i] = s / (ch * 32768f)
        }
        return Mono(out, rate)
    }

    /** wav 바이트(16비트) → 모노 */
    fun fromWav(bytes: ByteArray): Mono {
        val (s, r) = Wav.read(bytes)
        return Mono(s, r)
    }

    /** 모노 → 48kHz 모노 (선형 보간) */
    fun to48k(m: Mono): Mono {
        if (m.rate == OUT_RATE) return m
        val n = (m.samples.size.toLong() * OUT_RATE / m.rate).toInt()
        val out = FloatArray(n)
        val step = m.rate.toDouble() / OUT_RATE
        for (i in 0 until n) {
            val x = i * step
            val j = x.toInt()
            val a = m.samples[minOf(j, m.samples.size - 1)]
            val b = m.samples[minOf(j + 1, m.samples.size - 1)]
            out[i] = (a + (b - a) * (x - j)).toFloat()
        }
        return Mono(out, OUT_RATE)
    }

    /** 여러 소리를 사이에 쉼(gapSec)을 두고 하나로 (11/5: 공감 → 연결 문장 → 부모 메시지) */
    fun concat(parts: List<Mono>, gapSec: Double = 0.4): Mono {
        val ps = parts.map { to48k(it) }
        val gap = (gapSec * OUT_RATE).toInt()
        val out = FloatArray(ps.sumOf { it.samples.size } + gap * maxOf(0, ps.size - 1))
        var pos = 0
        ps.forEachIndexed { i, p ->
            if (i > 0) pos += gap
            p.samples.copyInto(out, pos); pos += p.samples.size
        }
        return Mono(out, OUT_RATE)
    }

    /** 모노 → 48kHz 스테레오 16비트 wav 바이트 */
    fun toSpeakerWav(src: Mono): ByteArray {
        val m = to48k(src)
        val n = m.samples.size
        val data = ByteBuffer.allocate(n * 4).order(ByteOrder.LITTLE_ENDIAN)
        for (i in 0 until n) {
            val v = (m.samples[i].coerceIn(-1f, 1f) * 32767).toInt().toShort()
            data.putShort(v); data.putShort(v)     // 왼쪽·오른쪽 같게
        }
        val h = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
        h.put("RIFF".toByteArray()); h.putInt(36 + n * 4); h.put("WAVE".toByteArray())
        h.put("fmt ".toByteArray()); h.putInt(16); h.putShort(1); h.putShort(2)
        h.putInt(OUT_RATE); h.putInt(OUT_RATE * 4); h.putShort(4); h.putShort(16)
        h.put("data".toByteArray()); h.putInt(n * 4)
        return ByteArrayOutputStream().apply { write(h.array()); write(data.array()) }.toByteArray()
    }
}
