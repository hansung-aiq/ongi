package com.aiq.ongi.device.flow

import com.aiq.ongi.device.Config
import com.aiq.ongi.device.ai_client.AiClient
import com.aiq.ongi.device.ai_client.AudioPrep
import java.io.File
import com.aiq.ongi.device.bridge.Signal
import com.aiq.ongi.device.bridge.SignalSink
import com.aiq.ongi.device.judge.EmbeddingJudge
import com.aiq.ongi.device.judge.KeywordJudge
import com.aiq.ongi.device.respond.Decision
import com.aiq.ongi.device.respond.InferParser
import com.aiq.ongi.device.respond.Responder
import com.aiq.ongi.device.safety.SafetyChecker
import com.aiq.ongi.device.store.MessageStore
import com.aiq.ongi.device.sync.ServerSync
import java.util.concurrent.Executors
import java.util.concurrent.Future

/**
 * 한 사이클 흐름: 듣기 → 받아쓰기 → 위기 확인 → 판단 → LLM → 재생 규칙 → 신호
 * 신호 순서는 신호 규격서 4장. 모든 경우는 start로 시작해서 idle로 끝난다.
 */
class OngiFlow(
    private val sink: SignalSink,
    private val ai: AiClient,
    private val store: MessageStore,
    private val sync: ServerSync,
    private val log: (String) -> Unit = {},
    private val safety: SafetyChecker = SafetyChecker(),
    private val judge: KeywordJudge = KeywordJudge(),
    /** 임베딩 판단 (모델 파일이 없으면 null → 키워드만) */
    private val embedJudge: EmbeddingJudge? = null,
    /** 재생할 소리(48kHz 스테레오 wav)를 만들어 두는 폴더. A안에서 tinyplay가 이 파일을 튼다 (11/5) */
    private val outDir: File? = null,
    /** 오디오 도우미 (A안). 살아 있으면 스피커로 틀고, 아니면 소리 길이만큼 기다리기만 한다 */
    private val speaker: com.aiq.ongi.device.audio.TinyAlsaHelper? = null,
) {
    private val responder = Responder(store) { id -> judge.rule(id)?.allowedFeelings ?: emptyList() }
    private val worker = Executors.newSingleThreadExecutor()

    @Volatile private var running = false
    private var task: Future<*>? = null

    /** 앱의 start. testText는 시험 모드 입력(마이크 대신 글) */
    @Synchronized
    fun start(testText: String?) {
        if (running) {
            log("이미 진행 중 → start 무시")
            return
        }
        running = true
        task = worker.submit {
            try {
                runCycle(testText)
            } catch (e: InterruptedException) {
                log("멈춤")
            } catch (e: Exception) {
                log("오류: ${e.message}")
                sink.send(Signal.Error("D-003"))
            } finally {
                sink.send(Signal.Idle)
                running = false
            }
        }
    }

    /** 앱의 stop. 하던 일을 멈추고 idle */
    @Synchronized
    fun stop() {
        if (!running) {
            sink.send(Signal.Idle)
            return
        }
        speaker?.stop()
        task?.cancel(true)      // runCycle 안의 sleep이 끊기고 finally에서 idle을 보냄
    }

    fun shutdown() {
        worker.shutdownNow()
    }

    /** 시간 측정 (11/5): 말 끝(=STT 시작) → 공감 소리 준비까지 */
    private var tSpeechEnd = 0L
    private var sttMs = 0L

    private fun runCycle(testText: String?) {
        // 1. 듣기
        sink.send(Signal.Listening)
        tSpeechEnd = System.currentTimeMillis()
        sttMs = 0L
        val text = listen(testText)?.trim()?.trimEnd('.', '!', '?', '。') ?: return
        if (text.isBlank()) {
            sink.send(Signal.Error("D-002"))
            return
        }

        // 2. 받아쓴 글
        sink.send(Signal.Thinking(text))

        // 3. 위기 표현 → 안전 응답 후 끝
        if (safety.isCrisis(text)) {
            log("위기 표현 → 안전 응답")
            sink.send(Signal.Safety(SafetyChecker.SAFETY_TEXT))
            pause(Config.NOTICE_MS)
            return
        }

        // 4. 판단: 키워드 → (없으면) 임베딩
        val hits = judge.matches(text)
        var judged = hits.firstOrNull()
        log(
            when {
                hits.isEmpty() -> "키워드 판단: 없음"
                hits.size == 1 -> "키워드 판단: $judged ${judge.nameOf(judged!!)}"
                else -> "키워드 판단: $judged ${judge.nameOf(judged!!)} (걸린 상황 $hits, 우선순위로 선택)"
            },
        )
        if (judged == null && embedJudge != null) {
            try {
                val t0 = System.currentTimeMillis()
                val r = embedJudge.judge(ai.embed(text))
                judged = r.situation
                // 11/5: 키워드가 막는 말(block)로 거른 상황을 임베딩이 다시 고르지 않게 (예: "친구들끼리 다퉜대" → 4 아님)
                judged?.let { s -> judge.blockedFor(s, text)?.let { b -> log("임베딩 판단 $s → 막는 말 \"$b\"이 있어서 버림"); judged = null } }
                val ms = System.currentTimeMillis() - t0
                log(
                    "임베딩 판단: ${if (judged != null) "$judged ${judge.nameOf(judged)}" else "없음"} " +
                        "(가장 가까운 상황 문장 \"${r.nearestText}\" ${r.nearestId}번 ${"%.3f".format(r.score)} / 일반 문장 ${"%.3f".format(r.generalScore)}, 기준 차이 ${embedJudge.margin}·점수 ${embedJudge.threshold}, ${ms}ms)",
                )
            } catch (e: Exception) {
                log("임베딩 판단 실패: ${e.message}")
            }
        }

        // 5. LLM
        val raw = try { ai.infer(text) } catch (e: Exception) { log("LLM 호출 실패: ${e.message}"); null }
        val infer = InferParser.parse(raw)
        log("LLM: ${when { infer == null -> "형식 깨짐(실패)"; infer.general -> "일반 대화(maum_1)"; else -> "상황 ${infer.situation}, 기분 ${infer.feeling}" }}")

        // 6. 재생 규칙
        val d = responder.decide(judged, infer, text, byKeyword = hits.isNotEmpty())
        log("결정: ${d.log}")

        // 7. 신호 보내고 재생 (공감 한마디는 TTS로 wav를 만들고 시간을 잰다)
        val tJudged = System.currentTimeMillis()
        val spoken = when (d) {
            is Decision.Play -> d.empathy
            is Decision.EmpathyOnly -> d.empathy
            is Decision.NotFound -> d.text
        }
        val ttsMs = speak(spoken)
        if (ttsMs >= 0) {
            val total = System.currentTimeMillis() - tSpeechEnd
            log("한 바퀴: 말 끝 → 공감 소리 준비 ${total}ms (STT ${sttMs} / 판단·LLM ${tJudged - tSpeechEnd - sttMs} / TTS ${ttsMs})")
        }
        // 8. 스피커용 소리 만들기 (48kHz 스테레오 wav). 사운드카드가 붙으면 이 파일을 그대로 튼다
        //    부모 메시지가 있으면: 공감 → (0.4초) → 연결 문장 → (0.4초) → 부모 메시지를 하나로 이어 out/turn.wav (11/5)
        val empathySound = lastTtsWav?.let { AudioPrep.fromWav(it) }
        val empathySec0 = prepare(empathySound, "empathy.wav", "공감 한마디")
        var empathySec = empathySec0
        var messageSec: Double? = null
        if (d is Decision.Play) {
            val m = d.message
            val msg = messageSound(m)
            messageSec = prepare(msg, "message.wav", "부모 메시지 ${m.id}(${m.author} ${m.kind})")
            val bridgeText = bridge(m)
            val bridge = try { ai.tts(bridgeText).takeIf { it.size > 44 }?.let { AudioPrep.fromWav(it) } } catch (e: Exception) { null }
            if (bridge != null) {
                log("연결 문장: \"$bridgeText\" ${"%.1f".format(bridge.seconds)}초")
                empathySec = (empathySec0 ?: 0.0) + 0.4 + bridge.seconds + 0.4
            }
            val parts = listOfNotNull(empathySound, bridge, msg)
            if (parts.size >= 2) prepare(AudioPrep.concat(parts), "turn.wav", "한 번에 이어서(공감 → 연결 → 메시지)")
        }

        // 9. 신호 + 스피커 (A안 도우미가 살아 있으면 tinyplay, 아니면 소리 길이만큼 기다림)
        val spk = speaker?.takeIf { it.alive }
        if (speaker != null && spk == null) log("스피커: 오디오 도우미 꺼짐 → 소리 없이 시간만 기다림")
        when (d) {
            is Decision.Play -> {
                sink.send(Signal.Empathy(d.empathy, hasMessage = true, author = d.message.author))
                // 공감 → 연결 → 메시지를 이어 붙인 turn.wav 하나를 틀고, 공감·연결이 끝날 즈음 playing 신호
                val turn = outDir?.let { File(it, "turn.wav") }?.takeIf { it.exists() }
                val started = spk != null && turn != null && spk.startPlay(turn).also { if (it) log("스피커: turn.wav 재생 시작") }
                pause(ms(empathySec, Config.EMPATHY_MS))
                val m = d.message
                sink.send(Signal.Playing(m.situationId, m.id, m.author, m.kind, m.text))
                if (started) {
                    val err = spk!!.waitPlay((((messageSec ?: 10.0) + 5) * 1000).toLong())
                    log(if (err == null) "스피커: 재생 끝" else "스피커: 재생 실패 → $err")
                } else {
                    pause(ms(messageSec, Config.PLAY_MS))
                }
                sync.reportPlayed(m.id)
            }
            is Decision.EmpathyOnly -> {
                sink.send(Signal.Empathy(d.empathy, hasMessage = false, author = null))
                playOrWait(spk, "empathy.wav", empathySec, Config.EMPATHY_MS)
            }
            is Decision.NotFound -> {
                sink.send(Signal.NotFound(d.text))
                playOrWait(spk, "empathy.wav", empathySec, Config.NOTICE_MS)
            }
        }
    }

    /** 도우미가 있으면 틀고 끝날 때까지, 없으면 소리 길이만큼 기다림 */
    private fun playOrWait(spk: com.aiq.ongi.device.audio.TinyAlsaHelper?, name: String, sec: Double?, default: Long) {
        val f = outDir?.let { File(it, name) }?.takeIf { it.exists() }
        if (spk != null && f != null && spk.startPlay(f)) {
            val err = spk.waitPlay(ms(sec, default) + 5000)
            log(if (err == null) "스피커: $name 재생 끝" else "스피커: $name 재생 실패 → $err")
        } else {
            pause(ms(sec, default))
        }
    }

    /** 공감 한마디와 부모 메시지 사이 연결 문장 */
    private fun bridge(m: com.aiq.ongi.device.store.ParentMessage): String {
        val parent = if (m.author == "dad") "아빠" else "엄마"
        val t = if (m.kind == "voice") Config.BRIDGE_VOICE else Config.BRIDGE_TEXT
        return t.replace("{부모}", parent).replace("{이름}", Config.CHILD_NAME)
    }

    /** 마지막 TTS 결과 (공감 한마디 wav) */
    private var lastTtsWav: ByteArray? = null

    /** 소리 길이(초) → 기다릴 시간. 소리가 없으면 기본값 */
    private fun ms(sec: Double?, default: Long) = if (sec != null) (sec * 1000).toLong() + 300 else default

    /** 부모 메시지 소리: 녹음이면 m4a를 풀고, 글이면 TTS로 읽는다 */
    private fun messageSound(m: com.aiq.ongi.device.store.ParentMessage): AudioPrep.Mono? = try {
        when {
            m.kind == "voice" && m.audioPath != null && File(m.audioPath).exists() -> AudioPrep.decode(File(m.audioPath))
            m.kind == "voice" -> { log("부모 메시지 ${m.id}: 녹음 파일 없음(시연 메시지) → 소리 없이 진행"); null }
            !m.text.isNullOrBlank() -> ai.tts(m.text).takeIf { it.size > 44 }?.let { AudioPrep.fromWav(it) }
            else -> null
        }
    } catch (e: Exception) {
        log("부모 메시지 ${m.id} 소리 준비 실패: ${e.message}"); null
    }

    /** 스피커용 wav 저장. 소리 길이(초), 못 만들면 null */
    private fun prepare(sound: AudioPrep.Mono?, name: String, what: String): Double? {
        val dir = outDir ?: return null
        if (sound == null || sound.samples.isEmpty()) return null
        return try {
            val t0 = System.currentTimeMillis()
            dir.mkdirs()
            File(dir, name).writeBytes(AudioPrep.toSpeakerWav(sound))
            log("재생 준비: $what ${"%.1f".format(sound.seconds)}초 (${sound.rate}Hz → 48kHz 스테레오, ${System.currentTimeMillis() - t0}ms) → out/$name")
            sound.seconds
        } catch (e: Exception) {
            log("재생 준비 실패($what): ${e.message}"); null
        }
    }

    /** 공감 한마디 TTS. 걸린 시간(ms), TTS가 가짜거나 실패면 -1 */
    private fun speak(text: String): Long {
        lastTtsWav = null
        return try {
            val t0 = System.currentTimeMillis()
            val wav = ai.tts(text)
            val ms = System.currentTimeMillis() - t0
            if (wav.size <= 44) return -1
            lastTtsWav = wav
            val rate = (wav[24].toInt() and 0xff) or ((wav[25].toInt() and 0xff) shl 8) or ((wav[26].toInt() and 0xff) shl 16)
            log("TTS ${ms}ms: \"$text\" → 소리 ${"%.1f".format((wav.size - 44) / 2.0 / rate)}초")
            ms
        } catch (e: Exception) {
            log("TTS 실패: ${e.message}")
            -1
        }
    }

    /**
     * 시험 모드면 글을 그대로, 아니면 마이크 → VAD → /stt (DEV-08)
     * 11/5: 시험 모드에서 "wav:파일경로"를 보내면 그 wav를 STT로 받아쓴다 (마이크 대신 wav 파일)
     */
    private fun listen(testText: String?): String? {
        if (Config.testMode) {
            if (testText == null) {
                pause(Config.LISTEN_MS)
                sink.send(Signal.Error("D-001"))
                return null
            }
            if (testText.startsWith("mic:")) {
                val sec = testText.removePrefix("mic:").trim().toIntOrNull() ?: 5
                val spk = speaker?.takeIf { it.alive }
                if (spk == null) { log("마이크: 오디오 도우미 꺼짐"); sink.send(Signal.Error("D-001")); return null }
                log("마이크: ${sec}초 녹음 시작 (도우미 tinycap)")
                val wav = spk.record(sec) ?: run { sink.send(Signal.Error("D-001")); return null }
                tSpeechEnd = System.currentTimeMillis()
                val text = try { ai.stt(wav) } catch (e: Exception) { log("STT 실패: ${e.message}"); "" }
                sttMs = System.currentTimeMillis() - tSpeechEnd
                log("STT ${sttMs}ms: 마이크 ${sec}초 → \"$text\"")
                return text
            }
            if (testText.startsWith("wav:")) {
                val f = java.io.File(testText.removePrefix("wav:").trim())
                if (!f.exists()) { log("wav 없음: ${f.absolutePath}"); sink.send(Signal.Error("D-001")); return null }
                tSpeechEnd = System.currentTimeMillis()
                val text = try { ai.stt(f.readBytes()) } catch (e: Exception) { log("STT 실패: ${e.message}"); "" }
                sttMs = System.currentTimeMillis() - tSpeechEnd
                log("STT ${sttMs}ms: ${f.name} → \"$text\"")
                return text
            }
            pause(Config.LISTEN_MS)
            tSpeechEnd = System.currentTimeMillis()
            return testText.trim()
        }
        // TODO DEV-08: 마이크 녹음 + VAD로 말 끝 감지 → wav → ai.stt(wav)
        sink.send(Signal.Error("D-001"))
        return null
    }

    private fun pause(ms: Long) = Thread.sleep(ms)
}
