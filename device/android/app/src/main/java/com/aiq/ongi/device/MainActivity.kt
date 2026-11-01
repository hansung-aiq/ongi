package com.aiq.ongi.device

import android.Manifest
import android.annotation.SuppressLint
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.os.Bundle
import android.util.Log
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import kotlin.concurrent.thread
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.sin

class MainActivity : AppCompatActivity() {
    private val tag = "ongi"
    private val hwRate = 48000   // 보드 USB 사운드카드는 44100/48000Hz만 지원
    private val sttRate = 16000  // STT·VAD 입력 기준
    private lateinit var status: TextView
    private val am by lazy { getSystemService(AUDIO_SERVICE) as AudioManager }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        status = findViewById(R.id.txtStatus)

        findViewById<Button>(R.id.btnTone).setOnClickListener { thread { playTone() } }
        findViewById<Button>(R.id.btnRecord).setOnClickListener {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
                != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), 1)
                show("마이크 권한을 허용한 뒤 다시 누르세요")
            } else {
                thread { recordAndPlay() }
            }
        }
    }

    private fun show(msg: String) {
        Log.i(tag, msg)
        runOnUiThread { status.text = msg }
    }

    // USB 사운드카드 찾기 (카드 번호는 꽂는 위치에 따라 바뀌므로 종류로 찾음)
    private fun usbDevice(flag: Int): AudioDeviceInfo? =
        am.getDevices(flag).firstOrNull {
            it.type == AudioDeviceInfo.TYPE_USB_HEADSET || it.type == AudioDeviceInfo.TYPE_USB_DEVICE
        }

    // 버튼 1: 440Hz 삐 소리 1초
    private fun playTone() {
        val mono = ShortArray(sttRate) { i -> (sin(2 * PI * 440 * i / sttRate) * 8000).toInt().toShort() }
        show("스피커: 삐 소리 1초 재생 중")
        play16k(mono)
        show("스피커 시험 끝")
    }

    // 버튼 2: 48kHz로 3초 녹음 → 16kHz로 줄임 → 재생
    @SuppressLint("MissingPermission")
    private fun recordAndPlay() {
        val minBuf = AudioRecord.getMinBufferSize(
            hwRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
        )
        if (minBuf <= 0) { show("오류: 48kHz 녹음을 열 수 없음 (minBuf=$minBuf)"); return }

        val rec = AudioRecord(
            MediaRecorder.AudioSource.VOICE_RECOGNITION, hwRate,
            AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, minBuf * 4
        )
        if (rec.state != AudioRecord.STATE_INITIALIZED) {
            show("오류: AudioRecord 초기화 실패"); rec.release(); return
        }
        usbDevice(AudioManager.GET_DEVICES_INPUTS)?.let { rec.preferredDevice = it }

        val raw = ShortArray(hwRate * 3)
        var off = 0
        rec.startRecording()
        show("녹음 중... 3초 동안 말하세요")
        while (off < raw.size) {
            val r = rec.read(raw, off, minOf(2048, raw.size - off))
            if (r <= 0) break
            off += r
        }
        val dev = rec.routedDevice?.productName ?: "알 수 없음"
        rec.stop(); rec.release()

        if (off < 3) { show("오류: 녹음된 샘플 없음"); return }
        val pcm16k = downsample(raw, off)   // STT에 넘길 형태
        val peak = pcm16k.maxOf { abs(it.toInt()) }
        show("녹음 끝: 16kHz ${pcm16k.size}샘플, 최대 크기 $peak / 32767, 장치 $dev → 재생")
        play16k(pcm16k)
        show("완료: 최대 크기 $peak (100 이하면 마이크 소리가 거의 안 들어온 것), 장치 $dev")
    }

    // 48kHz → 16kHz: 3개씩 평균
    private fun downsample(src: ShortArray, len: Int): ShortArray =
        ShortArray(len / 3) { i -> ((src[3 * i] + src[3 * i + 1] + src[3 * i + 2]) / 3).toShort() }

    // 16kHz 모노 → 48kHz 스테레오로 늘려서 재생 (사운드카드가 스테레오 48k만 받음)
    private fun play16k(mono: ShortArray) {
        val out = ShortArray(mono.size * 3 * 2)
        for (i in mono.indices) {
            for (k in 0 until 3) {
                val j = (i * 3 + k) * 2
                out[j] = mono[i]
                out[j + 1] = mono[i]
            }
        }
        val track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(hwRate)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                    .build()
            )
            .setTransferMode(AudioTrack.MODE_STATIC)
            .setBufferSizeInBytes(out.size * 2)
            .build()
        usbDevice(AudioManager.GET_DEVICES_OUTPUTS)?.let {
            track.preferredDevice = it
            Log.i(tag, "출력 장치: ${it.productName}")
        }
        track.write(out, 0, out.size)
        track.play()
        Thread.sleep(mono.size * 1000L / sttRate + 300)
        track.stop(); track.release()
    }
}