package com.aiq.ongi.device

/** 디바이스 프로그램 설정값. 바꿀 값은 여기 한 곳에서만 바꾼다. */
object Config {
    /** 앱과 신호를 주고받는 WebSocket 포트 (신호 규격서 1장) */
    const val PORT = 8765

    /** generate: LLM 생성 공감(규칙 검사 후 사용) / select: 미리 쓴 공감만 */
    @Volatile var empathyMode = EmpathyMode.GENERATE

    /** 모델 파일 폴더 이름. 실제 위치: /sdcard/Android/data/com.aiq.ongi.device/files/models
     *  (adb push로 넣는다. Colab의 ongi_embed.zip을 풀어서 그대로) */
    const val MODEL_DIR = "models"

    /** 서버 주소 (DEV-09). 개발: 맥 가짜 서버 + `adb reverse tcp:8000 tcp:8000` → 127.0.0.1:8000
     *  같은 공유기 시연: http://192.168.0.20:8000 / AWS 배포 후: EC2 주소 */
    @Volatile var SERVER_URL = "http://127.0.0.1:8000"

    /** LLM: true면 보드 NPU의 Genie로, false면 가짜 답(FakeAiClient). 화면 버튼으로 바꿈
     *  지금 보드의 예제 모델은 마음AI 도서관 안내 모델이라 우리 형식으로 답하지 않음 → 학습 모델이 오기 전엔 false가 기본 */
    @Volatile var useGenie = false

    /** Genie 설정 json. 학습 모델이 오면 이 파일(과 안에 적힌 context binary·tokenizer 경로)만 바꾼다 */
    @Volatile var LLM_CONFIG = "/data/local/tmp/model/korean/llama32-1b-htp.json"

    /** 프롬프트 앞머리. SUDA 앱은 "<|im_start|>"를 붙임. 우리 모델 학습 방식에 맞춰야 함(멘토 확인) */
    @Volatile var LLM_PROMPT_PREFIX = "<|im_start|>"

    /** STT·TTS 모델 폴더 (stt/, tts/). Android/data 안에는 adb로 하위 폴더를 만들 수 없어서 Genie처럼 /data/local/tmp에 둔다(11/5).
     *  이 폴더가 없으면 models 폴더(MODEL_DIR)에서 찾는다 */
    const val SPEECH_DIR = "/data/local/tmp/ongi/speech"

    /** 아이 이름 (연결 문장에 씀). 나중에 앱 2-1 자녀 정보 설정에서 받는다. 지금은 시연용 */
    @Volatile var CHILD_NAME = "민준"

    /** 공감 한마디와 부모 메시지 사이 연결 문장 (11/5). {부모} = 엄마/아빠, {이름} = 아이 이름. LLM이 만들지 않는 정해 둔 문장 */
    const val BRIDGE_VOICE = "{부모}가 {이름}이한테 남긴 말이 있어. 들려줄게"
    const val BRIDGE_TEXT = "{부모}가 {이름}이한테 남긴 말을 읽어 줄게"

    /** LLM 한 번에 기다리는 최대 시간 */
    const val LLM_TIMEOUT_MS = 8000L

    /** 동기화 간격(초) */
    const val SYNC_SEC = 30L

    /** 시험 모드: 마이크 대신 글로 입력 (오디오 문제 해결 전까지 true) */
    @Volatile var testMode = true

    // 시험 모드에서 소리 대신 기다리는 시간(밀리초)
    const val LISTEN_MS = 800L      // 아이가 말하는 시간
    const val EMPATHY_MS = 1500L    // 공감 한마디 재생
    const val PLAY_MS = 3000L       // 부모 메시지 재생
    const val NOTICE_MS = 2000L     // 받아주는 말, 안전 응답
}

enum class EmpathyMode { GENERATE, SELECT }
