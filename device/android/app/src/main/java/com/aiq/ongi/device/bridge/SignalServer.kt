package com.aiq.ongi.device.bridge

import org.java_websocket.WebSocket
import org.java_websocket.handshake.ClientHandshake
import org.java_websocket.server.WebSocketServer
import org.json.JSONObject
import java.net.InetSocketAddress

/**
 * 앱과 연결되는 WebSocket 서버 (8765).
 * 앱 → 디바이스: start / stop (신호 규격서 2장)
 * 개발 편의: {"type":"start","text":"오늘 친구랑 싸웠어"}처럼 text를 넣으면 시험 모드 입력으로 쓴다.
 */
class SignalServer(
    port: Int,
    private val onStartRequest: (text: String?) -> Unit,
    private val onStopRequest: () -> Unit,
    /** 개발용(11/5): {"type":"check","wav":경로} 또는 {"type":"check","text":글} → 재생 없이 STT·판단 결과만 그 연결에 답함 */
    private val onCheckRequest: ((wav: String?, text: String?) -> String)? = null,
    private val log: (String) -> Unit,
) : WebSocketServer(InetSocketAddress(port)), SignalSink {

    init {
        isReuseAddr = true
    }

    override fun onStart() {
        log("신호 서버 시작: 포트 $port")
    }

    override fun onOpen(conn: WebSocket?, handshake: ClientHandshake?) {
        log("앱 접속: ${conn?.remoteSocketAddress}")
    }

    override fun onClose(conn: WebSocket?, code: Int, reason: String?, remote: Boolean) {
        log("앱 연결 끊김: ${conn?.remoteSocketAddress}")
    }

    override fun onMessage(conn: WebSocket?, message: String?) {
        log("← $message")
        val obj = try {
            JSONObject(message ?: return)
        } catch (e: Exception) {
            log("JSON이 아닌 메시지 무시")
            return
        }
        when (obj.optString("type")) {
            "start" -> onStartRequest(obj.optString("text").ifBlank { null })
            "stop" -> onStopRequest()
            "check" -> onCheckRequest?.let { conn?.send(it(obj.optString("wav").ifBlank { null }, obj.optString("text").ifBlank { null })) }
            else -> log("모르는 type: ${obj.optString("type")}")
        }
    }

    override fun onError(conn: WebSocket?, ex: Exception?) {
        log("신호 서버 오류: ${ex?.message}")
    }

    override fun send(signal: Signal) {
        val json = signal.toJson()
        broadcast(json)
        log("→ $json")
    }
}
