#!/bin/bash
# [온기] 보드 설정 바꾸기 — 빌드 없이 (11/5)
#   bash device/tools/set_config.sh                                   지금 설정 보기
#   bash device/tools/set_config.sh server_url http://192.168.0.20:8000   서버 주소 (정범님 노트북)
#   bash device/tools/set_config.sh server_url http://127.0.0.1:8000      맥 가짜 서버로 되돌리기 (adb reverse 필요)
#   bash device/tools/set_config.sh child_name 민준                     아이 이름 (연결 문장)
# 앱은 30초마다(동기화 때) 다시 읽는다. 바뀌면 기록에 "설정: …"이 나온다.
F=/data/local/tmp/ongi/config.json
cur=$(adb shell cat $F 2>/dev/null | tr -d '\r')
[ -z "$cur" ] && cur="{}"
if [ $# -lt 2 ]; then echo "지금 설정: $cur"; exit 0; fi
new=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); d[sys.argv[2]]=sys.argv[3]; print(json.dumps(d, ensure_ascii=False))" "$cur" "$1" "$2")
adb shell mkdir -p /data/local/tmp/ongi
printf '%s' "$new" > /tmp/ongi_config.json
adb push /tmp/ongi_config.json $F >/dev/null && adb shell chmod 644 $F
echo "새 설정: $(adb shell cat $F | tr -d '\r')"
echo "30초 안에 반영 → adb logcat -d -s ongi | grep 설정"
