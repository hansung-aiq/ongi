#!/bin/bash
# [온기] 공유기(랜)로 보드 ↔ 서버 연결 시험 (11/7, 11/10에 그대로 씀)
#   bash device/tools/lan_check.sh                 맥 가짜 서버로 시험 (먼저 다른 탭에서 python3 device/mock_server.py)
#   bash device/tools/lan_check.sh 192.168.0.20    정범님 서버로 (정범 PC IPv4)
# 하는 일: 보드·맥 주소 → 보드에서 서버 닿는지 → 보드 서버 주소 바꿈 → 동기화 → 한 바퀴(재생 기록) → 결과
#   결과는 _local/lan_check_<시각>.txt 에도 저장 (와이파이를 바꾸는 동안 Claude 대화가 끊겨도 나중에 보여 주기)
#   끝나도 보드는 그 서버 주소를 유지. 되돌리기: bash device/tools/set_config.sh server_url http://127.0.0.1:8000
cd "$(dirname "$0")/../.." || exit 1
mkdir -p _local
OUT=_local/lan_check_$(date +%m%d_%H%M).txt
exec > >(tee "$OUT") 2>&1
ok()  { echo "  ✅ $*"; }
bad() { echo "  ❌ $*"; }

echo "=== 공유기 연결 시험 $(date '+%m/%d %H:%M')"
adb devices | grep -q "device$" || { bad "보드가 USB로 안 보여요 (adb)"; exit 1; }
adb root >/dev/null 2>&1; sleep 1

echo "1. 주소"
B=$(adb shell "ip -4 addr" | tr -d '\r' | grep inet | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
[ -n "$B" ] && ok "보드 $B" || { bad "보드에 네트워크 주소 없음 → 보드 가운데 랜 포트 ↔ ipTIME 주황 포트, 1분 기다린 뒤 다시"; exit 1; }
M=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
echo "  ・ 맥 $M"
S=${1:-$M}
URL="http://$S:8000"
echo "  ・ 시험할 서버 $URL $([ -z "$1" ] && echo '(맥 가짜 서버)')"

echo "2. 보드 → 서버"
if adb shell "command -v curl" >/dev/null 2>&1; then
    R=$(adb shell "curl -s -m 4 -o /dev/null -w '%{http_code}' $URL/device/changes" | tr -d '\r')
else
    # 보드에 curl이 없으면 nc로 HTTP 첫 줄만 봄
    R=$(adb shell "printf 'GET /device/changes HTTP/1.0\r\nHost: $S\r\n\r\n' | nc -w 4 $S 8000 | head -1" | tr -d '\r' | awk '{print $2}')
fi
if [ "$R" = "200" ]; then ok "닿음 (HTTP 200)"
else
    bad "안 닿음 (응답: ${R:-없음})"
    echo "  확인할 것: 서버가 켜져 있나 / 서버를 --host 0.0.0.0 으로 켰나 / 방화벽(맥: 시스템 설정 → 네트워크 → 방화벽, Windows: 8000 허용) / 같은 공유기인가"
    adb shell "ping -c 2 -W 2 $S" | tail -2 | sed 's/^/     ping: /'
    exit 1
fi

echo "3. 보드 서버 주소 바꾸고 동기화 (최대 70초)"
adb logcat -c
bash device/tools/set_config.sh server_url "$URL" >/dev/null
for i in $(seq 1 70); do adb logcat -d -s ongi | grep -q "받았음 알림\|동기화 실패" && break; sleep 1; done
adb logcat -d -s ongi | grep -E "설정: 서버|동기화" | sed 's/^.*ongi *: /  ・ /' | tail -8
adb logcat -d -s ongi | grep -q "받았음 알림" && ok "메시지 받음 (API-11·12·13)" || bad "동기화 안 됨"

echo "4. 한 바퀴 → 재생 기록 (API-14, 약 30초)"
adb forward tcp:8765 tcp:8765 >/dev/null
python3 device/test_client.py ws://127.0.0.1:8765 "나 오늘 상 받았어" | grep -E "playing|empathy" | cut -c1-90 | sed 's/^/  ・ /'
for i in $(seq 1 15); do adb logcat -d -s ongi | grep -q "재생 기록 보냄" && break; sleep 1; done
adb logcat -d -s ongi | grep -q "재생 기록 보냄" && ok "재생 기록 보냄" || bad "재생 기록 못 보냄"

echo
echo "끝. 결과 파일: $OUT"
echo "보드는 지금 $URL 을 씀. USB로 되돌리기: bash device/tools/set_config.sh server_url http://127.0.0.1:8000"
