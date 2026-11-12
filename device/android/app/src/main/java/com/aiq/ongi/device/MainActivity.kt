package com.aiq.ongi.device

import android.os.Bundle
import android.util.Log
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.widget.doAfterTextChanged
import com.aiq.ongi.device.ai_client.GenieLlm
import com.aiq.ongi.device.ai_client.LocalAiClient
import com.aiq.ongi.device.ai_client.OnnxEmbedder
import com.aiq.ongi.device.ai_client.SherpaSpeech
import com.aiq.ongi.device.judge.EmbeddingJudge
import com.aiq.ongi.device.bridge.SignalServer
import com.aiq.ongi.device.flow.OngiFlow
import com.aiq.ongi.device.judge.KeywordJudge
import com.aiq.ongi.device.judge.SituationConfig
import com.aiq.ongi.device.safety.SafetyChecker
import com.aiq.ongi.device.store.MessageStore
import com.aiq.ongi.device.store.OngiDb
import com.aiq.ongi.device.sync.ServerSync

/**
 * 디바이스 앱 첫 화면 (DEV-06 뼈대).
 * - 켜지면 WebSocket 신호 서버(8765)를 연다.
 * - 시험 모드: 글을 넣고 "보내기"를 누르면 아이가 그 말을 한 것처럼 한 사이클이 돈다.
 * - 맥에서 확인: adb forward tcp:8765 tcp:8765 → python device/test_client.py
 */
class MainActivity : AppCompatActivity() {

    private lateinit var logView: TextView
    private lateinit var scroll: ScrollView
    private var server: SignalServer? = null
    private var flow: OngiFlow? = null
    private var sync: ServerSync? = null
    private var genie: GenieLlm? = null
    private var speech: SherpaSpeech? = null

    @Volatile private var inputText = "오늘 친구랑 싸웠어"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val input = EditText(this).apply {
            hint = "아이 말 (시험 모드)"
            setText(inputText)
            doAfterTextChanged { inputText = it?.toString().orEmpty() }
        }
        val sendBtn = Button(this).apply { text = "보내기 (시험 모드)" }
        val stopBtn = Button(this).apply { text = "멈춤" }
        val clearBtn = Button(this).apply { text = "기록 지우기" }
        val llmBtn = Button(this).apply { text = "LLM: 가짜" }
        val micBtn = Button(this).apply { text = if (Config.testMode) "입력: 글(시험 모드)" else "입력: 마이크" }
        logView = TextView(this).apply { textSize = 12f }
        scroll = ScrollView(this).apply { addView(logView) }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 64, 32, 32)
            addView(TextView(context).apply { text = "온기 디바이스 · 포트 ${Config.PORT}"; textSize = 18f })
            addView(input)
            addView(sendBtn)
            addView(stopBtn)
            addView(clearBtn)
            addView(llmBtn)
            addView(micBtn)
            addView(scroll, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f))
        }
        setContentView(root)

        // 상황 키워드·위기 표현 읽기 (assets/situations.json, 못 읽으면 코드 안 기본값)
        val cfg = try {
            SituationConfig.parse(assets.open("situations.json").bufferedReader().use { it.readText() })
        } catch (e: Exception) {
            log("situations.json 읽기 실패 → 기본값 사용: ${e.message}")
            null
        }
        cfg?.let { log("situations.json: ${it.version} / 상황 ${it.rules.size}개 / 위기 표현 ${it.crisis.size}개") }

        // 임베딩 모델·기준 문장 (없으면 키워드만으로 동작)
        val modelDir = java.io.File(getExternalFilesDir(null), Config.MODEL_DIR)
        val embedder = try { OnnxEmbedder(modelDir) } catch (e: Throwable) {
            log("임베딩 모델 없음/실패 → 키워드만 사용 (${modelDir.absolutePath}): ${e.message}"); null
        }
        val embedJudge = if (embedder == null) null else try { EmbeddingJudge.load(modelDir) } catch (e: Throwable) {
            log("기준 문장 읽기 실패 → 키워드만 사용: ${e.message}"); null
        }
        embedJudge?.let { log("임베딩 판단: 기준 문장 ${it.size}개 / 차이 ${it.margin} / 점수 ${it.threshold}") }

        // LLM (Genie, 뒤에서 읽기). 다 읽히면 버튼으로 진짜/가짜 전환
        // 11/7: config.json의 llm_config·llm_prefix·use_genie를 먼저 읽어 둔다(swap_llm.sh)
        com.aiq.ongi.device.ConfigFile.reload(::log)
        val genie = GenieLlm(::log).also { it.startLoading() }
        this.genie = genie

        // STT·TTS (sherpa-onnx, 뒤에서 읽기). 모델이 없으면 가짜
        val speechDir = java.io.File(Config.SPEECH_DIR).takeIf { it.isDirectory } ?: modelDir
        val speech = SherpaSpeech(speechDir, java.io.File(getExternalFilesDir(null), "tts"), ::log).also { it.startLoading() }
        this.speech = speech

        // 오디오 A안: 도우미 + 마이크(말 끝 판단, silero VAD)
        val helper = com.aiq.ongi.device.audio.TinyAlsaHelper(java.io.File(Config.AUDIO_HELPER_DIR), ::log)
        val mic = com.aiq.ongi.device.audio.MicListener(helper, java.io.File(Config.SPEECH_DIR, "vad/silero_vad.onnx"), ::log)

        // 부품 조립: 신호 서버 ↔ 흐름
        val db = OngiDb(this)
        val store = MessageStore(db)
        val sync = ServerSync(store, db, java.io.File(filesDir, "audio"), ::log)
        lateinit var srv: SignalServer
        val f = OngiFlow(
            sink = { signal -> srv.send(signal) },
            ai = LocalAiClient(embedder, genie, speech, ::log),
            store = store,
            sync = sync,
            log = ::log,
            safety = cfg?.safetyChecker() ?: SafetyChecker(),
            judge = cfg?.keywordJudge() ?: KeywordJudge(),
            embedJudge = embedJudge,
            outDir = java.io.File(getExternalFilesDir(null), "out"),
            speaker = helper,
            mic = mic,
        )
        srv = SignalServer(
            port = Config.PORT,
            // 앱이 text를 안 보내면: 마이크 모드면 마이크, 시험 모드면 화면 입력칸 글 (11/5)
            onStartRequest = { text -> f.start(text ?: if (Config.testMode) inputText else null) },
            onStopRequest = { f.stop() },
            onCheckRequest = { wav, text, llm -> f.check(wav, text, llm) },
            log = ::log,
        )
        srv.start()
        server = srv
        flow = f

        sendBtn.setOnClickListener { f.start(inputText) }
        stopBtn.setOnClickListener { f.stop() }
        clearBtn.setOnClickListener { logView.text = "" }
        micBtn.setOnClickListener {
            Config.testMode = !Config.testMode
            micBtn.text = if (Config.testMode) "입력: 글(시험 모드)" else "입력: 마이크"
            log("입력 전환 → ${if (Config.testMode) "글(시험 모드)" else "마이크(앱 start에 글이 없으면 마이크로 들음)"}")
        }
        llmBtn.setOnClickListener {
            if (!genie.ready) { log("LLM: Genie가 아직 준비 안 됨(기록 확인)"); return@setOnClickListener }
            Config.useGenie = !Config.useGenie
            llmBtn.text = if (Config.useGenie) "LLM: Genie" else "LLM: 가짜"
            log("LLM 전환 → ${if (Config.useGenie) "Genie(보드 NPU)" else "가짜"}")
        }

        // 11/5: 부모 메시지·연결 문장 소리 미리 만들기 (TTS가 준비되면 한 번, 메시지가 바뀌면 다시)
        sync.onChanged = { f.prewarm() }
        Thread({
            val end = System.currentTimeMillis() + 60_000
            while (!speech.ttsReady && System.currentTimeMillis() < end) Thread.sleep(500)
            f.prewarm()
        }, "ongi-prewarm-wait").start()

        sync.start()
        this.sync = sync
    }

    override fun onDestroy() {
        flow?.shutdown()
        sync?.stop()
        genie?.close()
        speech?.close()
        try { server?.stop(500) } catch (_: Exception) {}
        super.onDestroy()
    }

    private fun log(msg: String) {
        Log.d("ongi", msg)
        runOnUiThread {
            logView.append(msg + "\n")
            scroll.post { scroll.fullScroll(ScrollView.FOCUS_DOWN) }
        }
    }
}
