# app/ — 부모·자녀 앱 (Flutter)

담당: 서유정

## 준비물

- Flutter 3.47 이상 (`flutter doctor`로 확인)
- Android Studio + Flutter·Dart 플러그인
- Android NDK 28.2.13676358 (Android Studio → Settings → Languages & Frameworks → Android SDK → SDK Tools → Show Package Details)
- Windows는 개발자 모드 켜기 (`start ms-settings:developers`)

## 실행 방법

Android Studio에서 `app` 폴더를 열고 기기를 고른 뒤 Run을 누른다. 터미널로는 아래처럼 실행한다.

```
cd app
flutter pub get
flutter devices            # 연결된 폰이나 에뮬레이터 확인
flutter run
```

에뮬레이터는 Android Studio의 Device Manager에서 만든다. 만들어 둔 에뮬레이터는 아래처럼 켠다.

```
flutter emulators                     # 이름 확인
flutter emulators --launch <이름>
```

폰은 개발자 옵션의 USB 디버깅을 켜고 PC에 연결한다.

## 보드 IP·서버 주소 바꾸는 곳

`lib/config.dart` 한 곳에서만 바꾼다. 바꾼 뒤에는 앱을 다시 실행한다.

```dart
static const boardWsUrl = 'ws://10.0.2.2:8765';
static const serverUrl = 'http://10.0.2.2:8000';
```

기본값은 에뮬레이터에서 PC의 가짜 보드·서버로 가는 주소다. 다른 환경은 아래 표대로 바꾼다.

| 연결 대상 | 폰에서 실행 | 에뮬레이터에서 실행 |
|---|---|---|
| 가짜 보드 | `ws://<노트북 IP>:8765` | `ws://10.0.2.2:8765` |
| 가짜 서버 | `http://<노트북 IP>:8000` | `http://10.0.2.2:8000` |
| 진짜 보드 | `ws://<보드 IP>:8765` | 같은 네트워크일 때만 가능 |
| 진짜 서버 | `http://<서버 IP>:8000` | `http://<서버 IP>:8000` |

- 폰과 노트북은 같은 공유기에 연결한다.
- Windows 노트북 IP는 `ipconfig`의 IPv4 주소로 확인한다.
- `10.0.2.2`는 에뮬레이터에서 PC를 가리키는 주소다.

## 화면 흐름

앱을 켜면 1-1 로그인(시작하기) → 1-2 역할 선택으로 간다.

- 부모: 3-1 부모 홈 → 분류 카드 → 3-3 분류별 메시지 → 빈 상황 → 3-4 메시지 남기기 → 3-5 저장 완료
- 자녀: 5-1 자녀 홈 (보드 신호로 화면이 바뀐다)

## 가짜 보드로 시험하기 (자녀 화면)

보드 없이 노트북의 가짜 보드(`device/mock_board.py`)에 붙여 자녀 화면을 확인한다. 신호 규격은 `docs/신호규격서.txt`를 따른다.

```
pip install websockets                       # 처음 한 번
python device/mock_board.py                  # ongi 폴더에서 실행, 창은 켜 둔다

cd app
flutter run                                  # 기본 주소(`ws://10.0.2.2:8765`)로 바로 연결
```

폰에서 실행할 때는 위 표대로 `boardWsUrl`을 노트북 IP로 바꾼다.

"온기에게 말하기"를 누를 때마다 시연 문장 4개("오늘 친구랑 싸웠어", "엄마 보고 싶어", "나 오늘 상 받았어", "배고파")가 차례대로 진행된다.

가짜 보드를 끄면 앱은 "연결 안 됨" 화면을 띄우고 3초마다 다시 연결한다.

## 가짜 서버로 시험하기 (부모 화면)

서버 없이 노트북의 가짜 서버(`device/mock_server.py`)에 붙여 부모 화면을 확인한다.

```
python device/mock_server.py                 # ongi 폴더에서 실행, 창은 켜 둔다 (설치할 것 없음)

cd app
flutter run                                  # 기본 주소(`http://10.0.2.2:8000`)로 바로 연결
```

폰에서 실행할 때는 위 표대로 `serverUrl`을 노트북 IP로 바꾼다.

- 현재 쓰는 API: API-02 상황 목록, API-03 메시지 목록, API-04 메시지 등록(글 200자까지 / 녹음), API-05 녹음 올리기


### 녹음 (3-4 음성 녹음 탭)

- 마이크를 누르면 녹음, 멈춤 버튼을 누르면 끝난다. 60초가 되면 저절로 멈춘다.
- 녹음 파일은 m4a(AAC)로 폰 임시 폴더에 저장되고, 저장하기를 누르면 API-05로 올린 뒤 받은 `audio_path`로 API-04(`kind: "voice"`)에 등록한다.
- 녹음한 뒤 다시 듣기, 다시 녹음을 할 수 있다.
- 에뮬레이터에서 노트북 마이크로 녹음하려면 에뮬레이터의 ⋯(Extended controls) → Microphone → "Virtual microphone uses host audio input"을 켠다.
- 올라간 녹음은 `_local/mock_audio/uploads/`에 저장된다.