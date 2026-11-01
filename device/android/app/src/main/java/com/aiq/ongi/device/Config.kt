package com.aiq.ongi.device

/** 디바이스 프로그램 설정값. 바꿀 값은 여기 한 곳에서만 바꾼다. */
object Config {
    /** 앱과 신호를 주고받는 WebSocket 포트 (신호 규격서 1장) */
    const val PORT = 8765

    /** generate: LLM 생성 공감(규칙 검사 후 사용) / select: 미리 쓴 공감만 */
    @Volatile var empathyMode = EmpathyMode.GENERATE

    /** 시험 모드: 마이크 대신 글로 입력 (오디오 문제 해결 전까지 true) */
    @Volatile var testMode = true

    // 시험 모드에서 소리 대신 기다리는 시간(밀리초)
    const val LISTEN_MS = 800L      // 아이가 말하는 시간
    const val EMPATHY_MS = 1500L    // 공감 한마디 재생
    const val PLAY_MS = 3000L       // 부모 메시지 재생
    const val NOTICE_MS = 2000L     // 받아주는 말, 안전 응답
}

enum class EmpathyMode { GENERATE, SELECT }
