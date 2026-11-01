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
import com.aiq.ongi.device.ai_client.FakeAiClient
import com.aiq.ongi.device.bridge.SignalServer
import com.aiq.ongi.device.flow.OngiFlow
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

        // 부품 조립: 신호 서버 ↔ 흐름
        val store = MessageStore()
        val sync = ServerSync(store, ::log)
        lateinit var srv: SignalServer
        val f = OngiFlow(sink = { signal -> srv.send(signal) }, ai = FakeAiClient(), store = store, sync = sync, log = ::log)
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
