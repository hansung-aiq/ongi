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
import com.aiq.ongi.device.ai_client.LocalAiClient
import com.aiq.ongi.device.ai_client.OnnxEmbedder
import com.aiq.ongi.device.judge.EmbeddingJudge
import com.aiq.ongi.device.bridge.SignalServer
import com.aiq.ongi.device.flow.OngiFlow
import com.aiq.ongi.device.judge.KeywordJudge
import com.aiq.ongi.device.judge.SituationConfig
import com.aiq.ongi.device.safety.SafetyChecker
import com.aiq.ongi.device.store.MessageStore
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

        // 부품 조립: 신호 서버 ↔ 흐름
        val store = MessageStore()
        val sync = ServerSync(store, ::log)
        lateinit var srv: SignalServer
        val f = OngiFlow(
            sink = { signal -> srv.send(signal) },
            ai = LocalAiClient(embedder),
            store = store,
            sync = sync,
            log = ::log,
            safety = cfg?.safetyChecker() ?: SafetyChecker(),
            judge = cfg?.keywordJudge() ?: KeywordJudge(),
            embedJudge = embedJudge,
        )
        srv = SignalServer(
            port = Config.PORT,
            onStartRequest = { text -> f.start(text ?: inputText) },   // 앱이 text를 안 보내면 화면 입력칸 글
            onStopRequest = { f.stop() },
            log = ::log,
        )
        srv.start()
        server = srv
        flow = f

        sendBtn.setOnClickListener { f.start(inputText) }
        stopBtn.setOnClickListener { f.stop() }
        clearBtn.setOnClickListener { logView.text = "" }

        sync.syncOnce()
    }

    override fun onDestroy() {
        flow?.shutdown()
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
