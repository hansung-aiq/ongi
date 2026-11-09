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
    /** 마이크 듣기 (말 끝 판단) */
    private val mic: com.aiq.ongi.device.audio.MicListener? = null,
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

    /**
     * 개발용 판단만 해 보기 (11/5): STT → 위기 → 키워드 → 임베딩까지, LLM·재생 없이. 결과 JSON.
     * STT가 잘못 듣는 모양을 한꺼번에 찾을 때 쓴다(device/tools/stt_sweep.py). 대화 중이면 busy
     */
    fun check(wav: String?, text: String?, llm: Boolean = false): String {
        val o = org.json.JSONObject().put("type", "check_result")
        if (running) return o.put("error", "busy").toString()
        return try {
            worker.submit(java.util.concurrent.Callable {
                val t0 = System.currentTimeMillis()
                val heard = if (wav != null) ai.stt(File(wav).readBytes()) else text.orEmpty()
                val sttMs = System.currentTimeMillis() - t0
                val t = heard.trim().trimEnd('.', '!', '?', '。')
                o.put("heard", t).put("stt_ms", sttMs)
                // 11/7: LLM 원문 (위기 표현이어도 채점용으로 먼저 돌림)
                if (llm) {
                    val t1 = System.currentTimeMillis()
                    val raw = try { ai.infer(t) } catch (e: Exception) { "ERROR: ${e.message ?: e.javaClass.simpleName}" }
                    o.put("llm_raw", raw).put("llm_ms", System.currentTimeMillis() - t1)
                    o.put("llm_genie", (ai as? com.aiq.ongi.device.ai_client.LocalAiClient)?.genieActive == true)
                    InferParser.parse(raw)?.let { r ->
                        o.put("llm_general", r.general).put("llm_situation", r.situation).put("llm_feeling", r.feeling).put("llm_empathy", r.empathy ?: "")
                    }
                }
                if (safety.isCrisis(t)) return@Callable o.put("by", "safety").put("situation", -1).toString()
                val hits = judge.matches(t)
                var s = hits.firstOrNull()
                var by = if (s != null) "keyword" else "none"
                if (s == null && embedJudge != null) {
                    val r = embedJudge.judge(ai.embed(t))
                    s = r.situation?.takeIf { judge.blockedFor(it, t) == null }
                    if (s != null) by = "embedding"
                    o.put("embed_near", r.nearestText).put("embed_score", r.score.toDouble()).put("embed_general", r.generalScore.toDouble())
                }
                o.put("by", by).put("situation", s ?: 0).toString()
            }).get(30, java.util.concurrent.TimeUnit.SECONDS)
        } catch (e: Exception) {
            o.put("error", e.message ?: e.javaClass.simpleName).toString()
        }
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
            sayNotice(Config.RETRY_TEXT, "다시 말해 달라는 안내")     // 11/5: 소리로도 안내
            return
        }

        // 2. 받아쓴 글
        sink.send(Signal.Thinking(text))

        // 3. 위기 표현 → 안전 응답 후 끝
        if (safety.isCrisis(text)) {
            log("위기 표현 → 안전 응답")
            // 11/5: 안전 응답도 소리로. 숫자는 TTS가 읽기 쉽게 바꿔서 읽음(화면 글은 1388 그대로)
            val sec = speakToFile(SafetyChecker.SAFETY_TEXT.replace("1388", "일삼팔팔"), "notice.wav", "안전 응답")
            sink.send(Signal.Safety(SafetyChecker.SAFETY_TEXT))
            playOrWait(speaker?.takeIf { it.alive }, "notice.wav", sec, Config.NOTICE_MS)
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
            val bridge = bridgeSound(bridgeText)
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

    /** 글 → TTS → 스피커용 wav(outDir/name). 소리 길이(초), 못 만들면 null */
    private fun speakToFile(text: String, name: String, what: String): Double? = try {
        val wav = ai.tts(text)
        if (wav.size > 44) prepare(AudioPrep.fromWav(wav), name, what) else null
    } catch (e: Exception) {
        log("TTS 실패($what): ${e.message}"); null
    }

    /** 짧은 안내를 소리로 (D-002 등) */
    private fun sayNotice(text: String, what: String) {
        val sec = speakToFile(text, "notice.wav", what)
        playOrWait(speaker?.takeIf { it.alive }, "notice.wav", sec, Config.NOTICE_MS)
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

    /**
     * 11/5: 부모 메시지·연결 문장 소리는 미리 만들어 둔다(첫 응답 시간 단축: 글 메시지 TTS가 2초쯤 걸림).
     * 메시지가 바뀌면(id·수정 시각·내용) 키가 달라져서 새로 만든다.
     */
    private val soundCache = java.util.concurrent.ConcurrentHashMap<String, AudioPrep.Mono>()

    private fun keyOf(m: com.aiq.ongi.device.store.ParentMessage) =
        // 11/9: voice의 text는 받아쓴 글이라 소리와 상관없음 → 키에서 뺌(받아쓴 뒤 소리를 다시 만들지 않게)
        "m${m.id}|${m.updatedAt}|${m.kind}|${m.audioPath}|${if (m.kind == "text") m.text?.hashCode() else ""}"

    /** 앱이 켜질 때(TTS 준비 후)와 동기화로 메시지가 바뀔 때 부른다. 뒤에서 돈다 */
    fun prewarm() {
        Thread({
            try {
                val t0 = System.currentTimeMillis()
                val all = store.all()
                var n = 0
                for (m in all) {
                    if (messageSound(m) != null) n++
                    bridgeSound(bridge(m))
                }
                log("미리 준비: 부모 메시지 ${n}/${all.size}개 소리 + 연결 문장 (${System.currentTimeMillis() - t0}ms)")
                if (Config.TRANSCRIBE_VOICE) for (m in all) if (m.kind == "voice" && m.text.isNullOrBlank()) transcribe(m)
            } catch (e: Exception) {
                log("미리 준비 실패: ${e.message}")
            }
        }, "ongi-prewarm").start()
    }

    /**
     * 녹음 메시지 받아쓰기 (11/9 C안). 메시지를 받을 때 미리 하므로 아이 응답 시간에는 영향 없음.
     * 무음 녹음은 받아쓰지 않는다(파형만). 아이와 대화 중이면 끝날 때까지 기다림(STT를 같이 씀)
     */
    private fun transcribe(m: com.aiq.ongi.device.store.ParentMessage) {
        val path = m.audioPath ?: return
        if (!File(path).exists()) return
        try {
            val sound = AudioPrep.decode(File(path))
            val peak = sound.samples.maxOfOrNull { kotlin.math.abs(it) } ?: 0f
            if (peak < 0.03f) { log("받아쓰기: 메시지 ${m.id} 무음(최대 ${"%.3f".format(peak)}) → 글 없이 파형만"); return }
            var waited = 0
            while (running && waited < 120) { Thread.sleep(500); waited++ }
            val t0 = System.currentTimeMillis()
            val text = ai.stt(monoWav(sound)).trim().trimEnd(',', '.', ' ')
            if (text.isBlank()) { log("받아쓰기: 메시지 ${m.id} 결과 없음"); return }
            store.setTranscript(m.id, text)
            log("받아쓰기: 메시지 ${m.id} ${"%.1f".format(sound.seconds)}초 → ${System.currentTimeMillis() - t0}ms \"${text.take(60)}${if (text.length > 60) "…" else ""}\"")
        } catch (e: Exception) {
            log("받아쓰기 실패: 메시지 ${m.id} ${e.message}")
        }
    }

    /** float 모노 → 16비트 모노 wav (STT 입력) */
    private fun monoWav(m: AudioPrep.Mono): ByteArray {
        val n = m.samples.size
        val b = java.nio.ByteBuffer.allocate(44 + n * 2).order(java.nio.ByteOrder.LITTLE_ENDIAN)
        b.put("RIFF".toByteArray()).putInt(36 + n * 2).put("WAVE".toByteArray())
        b.put("fmt ".toByteArray()).putInt(16).putShort(1).putShort(1).putInt(m.rate).putInt(m.rate * 2).putShort(2).putShort(16)
        b.put("data".toByteArray()).putInt(n * 2)
        for (v in m.samples) b.putShort((v.coerceIn(-1f, 1f) * 32767).toInt().toShort())
        return b.array()
    }

    private fun bridgeSound(text: String): AudioPrep.Mono? {
        soundCache["b$text"]?.let { return it }
        return try {
            ai.tts(text).takeIf { it.size > 44 }?.let { AudioPrep.to48k(AudioPrep.fromWav(it)) }?.also { soundCache["b$text"] = it }
        } catch (e: Exception) { null }
    }

    /** 부모 메시지 소리(48kHz): 미리 만든 게 있으면 그것, 없으면 지금 만듦 */
    private fun messageSound(m: com.aiq.ongi.device.store.ParentMessage): AudioPrep.Mono? {
        soundCache[keyOf(m)]?.let { return it }
        return buildMessageSound(m)?.let { AudioPrep.to48k(it) }?.also { soundCache[keyOf(m)] = it }
    }

    /** 녹음이면 m4a를 풀고, 글이면 TTS로 읽는다 */
    private fun buildMessageSound(m: com.aiq.ongi.device.store.ParentMessage): AudioPrep.Mono? = try {
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
     * 듣기 (11/5 정리)
     *   testText가 있으면 시험 입력: 글 그대로 / "wav:경로"(그 wav를 STT) / "stream:경로"(wav를 실제 시간처럼 넣어 말 끝 판단 → STT)
     *                              / "mic"(진짜 마이크, 말 끝 판단) / "mic:초"(그 초만큼 녹음)
     *   testText가 없으면: 마이크 모드(Config.testMode=false)면 진짜 마이크, 아니면 D-001
     */
    private fun listen(testText: String?): String? {
        val t = testText?.trim()
        return when {
            t == null && !Config.testMode -> sttOf("마이크") { mic?.listen() }
            t == null -> { pause(Config.LISTEN_MS); sink.send(Signal.Error("D-001")); null }
            t == "mic" -> sttOf("마이크") { mic?.listen() }
            t.startsWith("mic:") -> {
                val sec = t.removePrefix("mic:").trim().toIntOrNull() ?: 5
                log("마이크: ${sec}초 녹음 시작 (도우미 tinycap)")
                sttOf("마이크 ${sec}초") { speaker?.takeIf { it.alive }?.record(sec) }
            }
            t.startsWith("wav:") -> {
                val f = File(t.removePrefix("wav:").trim())
                sttOf(f.name) { f.takeIf { it.exists() }?.readBytes() }
            }
            t.startsWith("stream:") -> {
                val f = File(t.removePrefix("stream:").trim())
                sttOf("마이크 시험 ${f.name}") { f.takeIf { it.exists() }?.readBytes()?.let { mic?.stream(it) } }
            }
            else -> { pause(Config.LISTEN_MS); tSpeechEnd = System.currentTimeMillis(); t }
        }
    }

    /** 소리 얻기 → STT. 소리가 없으면 D-001 */
    private fun sttOf(what: String, get: () -> ByteArray?): String? {
        val wav = try { get() } catch (e: Exception) { log("$what 실패: ${e.message}"); null }
        if (wav == null) { log("$what: 소리 없음"); sink.send(Signal.Error("D-001")); return null }
        tSpeechEnd = System.currentTimeMillis()      // 말이 끝난 때 = STT 시작
        val text = try { ai.stt(wav) } catch (e: Exception) { log("STT 실패: ${e.message}"); "" }
        sttMs = System.currentTimeMillis() - tSpeechEnd
        log("STT ${sttMs}ms: $what → \"$text\"")
        return text
    }

    private fun pause(ms: Long) = Thread.sleep(ms)
}
