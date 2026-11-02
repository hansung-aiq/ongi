package com.aiq.ongi.device.flow

import com.aiq.ongi.device.Config
import com.aiq.ongi.device.ai_client.AiClient
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
        task?.cancel(true)      // runCycle 안의 sleep이 끊기고 finally에서 idle을 보냄
    }

    fun shutdown() {
        worker.shutdownNow()
    }

    private fun runCycle(testText: String?) {
        // 1. 듣기
        sink.send(Signal.Listening)
        val text = listen(testText) ?: return
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
        val d = responder.decide(judged, infer, text)
        log("결정: ${d.log}")

        // 7. 신호 보내고 재생
        when (d) {
            is Decision.Play -> {
                sink.send(Signal.Empathy(d.empathy, hasMessage = true, author = d.message.author))
                pause(Config.EMPATHY_MS)     // TODO /tts 합성 후 재생
                val m = d.message
                sink.send(Signal.Playing(m.situationId, m.id, m.author, m.kind, m.text))
                pause(Config.PLAY_MS)        // TODO 부모 메시지 wav 재생
                sync.reportPlayed(m.id)
            }
            is Decision.EmpathyOnly -> {
                sink.send(Signal.Empathy(d.empathy, hasMessage = false, author = null))
                pause(Config.EMPATHY_MS)
            }
            is Decision.NotFound -> {
                sink.send(Signal.NotFound(d.text))
                pause(Config.NOTICE_MS)
            }
        }
    }

    /** 시험 모드면 글을 그대로, 아니면 마이크 → VAD → /stt (DEV-08) */
    private fun listen(testText: String?): String? {
        if (Config.testMode) {
            pause(Config.LISTEN_MS)
            if (testText == null) {
                sink.send(Signal.Error("D-001"))
                return null
            }
            return testText.trim()
        }
        // TODO DEV-08: 마이크 녹음 + VAD로 말 끝 감지 → wav → ai.stt(wav)
        sink.send(Signal.Error("D-001"))
        return null
    }

    private fun pause(ms: Long) = Thread.sleep(ms)
}
