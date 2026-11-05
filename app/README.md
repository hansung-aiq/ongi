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
