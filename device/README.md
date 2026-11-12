# device/ — 보드 안 디바이스 프로그램

담당: 공지현

| 위치 | 내용 |
|---|---|
| `device/android/` | 디바이스 앱 (Kotlin, Android Studio 프로젝트, 패키지 `com.aiq.ongi.device`) |
| `device/mock_board.py` | 가짜 보드 (앱 개발용 WebSocket 8765 서버) |
| `device/test_client.py` | 가짜 보드·진짜 보드 신호 확인용 |

## 코드 구조 (`app/src/main/java/com/aiq/ongi/device/`)

| 패키지 | 하는 일 | 상태 |
|---|---|---|
| `MainActivity.kt` | 화면(시험 모드 입력칸·버튼·기록), 부품 조립 | 뼈대 |
| `Config.kt` | 포트, empathy_mode, 시험 모드, 대기 시간 | 뼈대 |
| `flow/` | 한 사이클 흐름(듣기 → 판단 → 공감 → 재생), start/stop | 뼈대 (DEV-06) |
| `bridge/` | 앱과 WebSocket 8765, 신호 8종 JSON | 완료 |
| `safety/` | 위기 표현 → 안전 응답 | 임시 목록 |
| `judge/` | 키워드 판단 + 우선순위 | 임시 키워드 (DEV-07) |
| `ai_client/` | 보드 안 AI 서버 호출(/stt /embed /infer /tts) | 가짜 응답 (DEV-08에서 진짜) |
| `respond/` | /infer 파싱, 생성 공감 규칙 검사, 재생 규칙, 대체 문장 | 완료 (대체 문장은 임시) |
| `store/` | 부모 메시지 | 시연용 고정 3개 (DEV-09에서 SQLite) |
| `sync/` | 서버 동기화 | 빈 틀 (DEV-09) |

## 보드
- Coretronic COREKOM R6490Q (QCS6490), Android 13
- 맥과 USB-C로 연결, `adb devices`로 확인

## 진짜 보드 신호 확인 (시험 모드)
```bash
adb forward tcp:8765 tcp:8765
python3 device/test_client.py ws://127.0.0.1:8765 "오늘 친구랑 싸웠어"
```

시험 문장
| 문장 | 기대 결과 |
|---|---|
| 오늘 친구랑 싸웠어 | 공감(생성) + 엄마 녹음 |
| 엄마 보고 싶어 | 공감(생성) + 엄마 녹음 |
| 나 오늘 상 받았어 | 공감(생성) + 아빠 글 |
| 배고파 | 받아주는 말 |
| 친구랑 싸워서 학교 가기 싫어 | 생성 공감이 규칙 위반 → 대체 공감 + 엄마 녹음 (TC-22) |
| 형식 깨짐 시험 | LLM 실패 → 받아주는 말 |
| 나 죽고 싶어 | 안전 응답(1388) |

## 가짜 보드 실행 (앱 개발용)
```bash
pip3 install websockets
python3 device/mock_board.py
python3 device/test_client.py          # 다른 터미널에서
```
