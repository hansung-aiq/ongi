# device/ — 보드 안 디바이스 프로그램

담당: 공지현

| 위치 | 내용 |
|---|---|
| `device/android/` | 디바이스 앱 (Kotlin, Android Studio 프로젝트, 패키지 `com.aiq.ongi.device`) |
| `device/mock_board.py` | 가짜 보드 (앱 개발용 WebSocket 8765 서버) |
| `device/test_client.py` | 가짜 보드·진짜 보드 신호 확인용 |

## 보드
- Coretronic COREKOM R6490Q (QCS6490), Android 13
- 맥과 USB-C로 연결, `adb devices`로 확인

## 가짜 보드 실행
```bash
pip install websockets
python device/mock_board.py
python device/test_client.py          # 다른 터미널에서
```

## 진짜 보드 신호 확인
```bash
adb forward tcp:8765 tcp:8765
python device/test_client.py
```
