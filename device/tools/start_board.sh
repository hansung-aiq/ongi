#!/bin/bash
# [온기] 보드 준비 한 번에 (11/5)
# 보드 전원 켜고 USB-C 연결한 뒤, 맥 터미널에서:
#   cd ~/ongi && bash device/tools/start_board.sh
# 하는 일: 보드 연결 확인 → root → 오디오 도우미 → 앱 다시 켜기 → 포트 연결 → 준비 확인
# 앱은 미리 Android Studio로 설치돼 있어야 한다(▶ Run 한 번). 이 스크립트는 다시 켜기만 한다.

cd "$(dirname "$0")/../.." || exit 1
PKG=com.aiq.ongi.device
H=/data/local/tmp/ongi
ok()   { echo "  ✅ $*"; }
bad()  { echo "  ❌ $*"; }
info() { echo "  ・ $*"; }

echo "1. 보드 연결"
if ! adb devices | grep -q "device$"; then
    adb kill-server >/dev/null 2>&1; sleep 1; adb devices >/dev/null 2>&1; sleep 1
fi
if adb devices | grep -q "device$"; then ok "$(adb devices | grep 'device$' | head -1)"
else bad "보드가 안 보여요. 전원(초록 불)·USB-C 케이블을 확인하고 다시 실행하세요"; exit 1; fi

echo "2. root"
adb root >/dev/null 2>&1; sleep 2; adb wait-for-device
if [ "$(adb shell id -u | tr -d '\r')" = "0" ]; then ok "root"; else bad "root가 안 됨"; exit 1; fi

echo "3. 오디오 도우미"
adb shell mkdir -p $H
adb push device/tools/ongi_audio.sh $H/ >/dev/null
adb shell "pkill -f ongi_audio.sh" >/dev/null 2>&1
adb shell "nohup sh $H/ongi_audio.sh > $H/audio.log 2>&1 &"
sleep 2
A=$(adb shell cat $H/audio/alive 2>/dev/null | tr -d '\r'); N=$(adb shell date +%s | tr -d '\r')
if [ -n "$A" ] && [ $((N - A)) -le 3 ]; then ok "도우미 살아 있음"; else bad "도우미가 안 떴어요 → adb shell cat $H/audio.log"; fi
if adb shell cat /proc/asound/cards | grep -qi usb; then ok "USB 사운드카드 있음"
else info "USB 사운드카드 없음 (소리 없이 시간만 기다림. 꽂으려면 부팅 후에)"; fi

echo "4. 모델 파일"
adb shell ls $H/speech/stt/model.int8.onnx >/dev/null 2>&1 && ok "STT·TTS 모델" || bad "STT·TTS 모델 없음 → 컨텍스트 4-2-3"
if ! adb shell ls $H/speech/vad/silero_vad.onnx >/dev/null 2>&1 && [ -f _local/speech/vad/silero_vad.onnx ]; then
    adb shell mkdir -p $H/speech/vad; adb push _local/speech/vad/silero_vad.onnx $H/speech/vad/ >/dev/null; adb shell chmod -R 755 $H/speech
fi
adb shell ls $H/speech/vad/silero_vad.onnx >/dev/null 2>&1 && ok "VAD 모델(말 끝 판단)" || info "VAD 모델 없음(소리 크기로 판단)"
adb shell ls /sdcard/Android/data/$PKG/files/models/minilm_int8.onnx >/dev/null 2>&1 && ok "임베딩 모델" || info "임베딩 모델 없음(키워드만 씀) → 컨텍스트 4-2-1"

echo "5. 앱 다시 켜기"
adb logcat -c
adb shell am force-stop $PKG
adb shell am start -n $PKG/.MainActivity >/dev/null 2>&1 && ok "앱 켬" || { bad "앱이 설치 안 됨 → Android Studio ▶ Run"; exit 1; }

echo "6. 포트"
adb forward tcp:8765 tcp:8765 >/dev/null && ok "보드 신호 8765 → 맥 127.0.0.1:8765"
adb reverse tcp:8000 tcp:8000 >/dev/null && ok "보드 127.0.0.1:8000 → 맥 서버 8000 (가짜 서버: python3 device/mock_server.py)"

echo "7. 준비 확인 (최대 60초, 부모 메시지 소리 미리 만들기까지 기다림)"
for i in $(seq 1 60); do
    L=$(adb logcat -d -s ongi)
    echo "$L" | grep -q "신호 서버 시작" && echo "$L" | grep -q "STT: 미리 한 번 돌림" && echo "$L" | grep -q "미리 준비:" && break
    sleep 1
done
for k in "situations.json" "임베딩 판단: 기준" "신호 서버 시작" "LLM: Genie 준비 완료" "STT: SenseVoice 준비 완료" "TTS: 한국어 목소리 준비 완료" "STT: 미리 한 번 돌림" "미리 준비:" "VAD" "동기화 시작" "실패" "없음 →"; do
    line=$(echo "$L" | grep "$k" | tail -1 | sed 's/^.*ongi *: //')
    [ -n "$line" ] && info "$line"
done
if echo "$L" | grep -q "STT: 미리 한 번 돌림" && echo "$L" | grep -q "미리 준비:" && echo "$L" | grep -q "신호 서버 시작"; then
    echo; echo "준비 끝 🎉  시연 점검: python3 device/tools/demo_check.py"
else
    echo; bad "아직 준비 안 됨. adb logcat -d -s ongi | tail -30 을 확인하세요"
fi
