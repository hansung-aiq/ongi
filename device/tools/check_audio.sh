#!/bin/bash
# [온기] 부모 녹음 무음 검사 (11/9)
# 에뮬레이터 마이크가 꺼져 있거나 볼륨 0이면 녹음이 무음으로 저장된다 → 보드에서 아무 소리 없이 재생됨.
# 맥에서:  bash device/tools/check_audio.sh            (서버 files 폴더의 가장 최근 녹음)
#          bash device/tools/check_audio.sh all        (최근 5개)
#          bash device/tools/check_audio.sh 파일.m4a
# 맥 기본 도구(afconvert) + python3만 씀. 귀로 들으려면: afplay 파일.m4a

DIR=${ONGI_FILES:-$HOME/ongi-server/server/files}
if [ -f "$1" ]; then FILES=("$1")
elif [ "$1" = "all" ]; then FILES=($(ls -t "$DIR"/*.m4a 2>/dev/null | head -5))
else FILES=($(ls -t "$DIR"/*.m4a 2>/dev/null | head -1)); fi
[ ${#FILES[@]} -eq 0 ] && { echo "녹음 파일이 없어요: $DIR"; exit 1; }

for f in "${FILES[@]}"; do
    tmp=/tmp/ongi_chk_$$.wav
    afconvert -f WAVE -d LEI16 "$f" "$tmp" 2>/dev/null || { echo "❌ 변환 실패: $f"; continue; }
    python3 - "$tmp" "$(basename "$f")" "$(date -r "$f" '+%m/%d %H:%M')" <<'PY'
import array, math, struct, sys
# afconvert wav는 확장 형식(65534)일 수 있어 wave 모듈 대신 chunk를 직접 읽음
b = open(sys.argv[1], 'rb').read(); i, ch, sr, data = 12, 1, 44100, b''
while i + 8 <= len(b):
    cid, size = b[i:i+4], struct.unpack('<I', b[i+4:i+8])[0]; body = b[i+8:i+8+size]
    if cid == b'fmt ': ch, sr = struct.unpack('<HI', body[2:8])
    elif cid == b'data': data = body
    i += 8 + size + (size & 1)
a = array.array('h', data[:len(data) // 2 * 2])
db = lambda v: 20 * math.log10(max(v, 1) / 32768)
peak = max((abs(x) for x in a), default=0)
rms = math.sqrt(sum(x * x for x in a) / max(len(a), 1))
sec = len(a) / sr / ch
step = sr * ch * 2                       # 2초마다 최대 소리
parts = [db(max((abs(x) for x in a[i:i + step]), default=0)) for i in range(0, len(a), step)]
if peak < 1000:   verdict = "❌ 무음 → 마이크(윈도우 입력·볼륨, 에뮬레이터 Host Microphone) 확인 후 다시 녹음"
elif peak >= 32700 and sum(1 for x in a if abs(x) >= 32700) > sr * 0.05:
                  verdict = "⚠️ 소리가 너무 큼(터짐) → 윈도우 마이크 볼륨을 낮춰 다시 녹음 권장"
else:             verdict = "✅ OK"
print(f"{sys.argv[2]} ({sys.argv[3]})  {sec:.1f}초  최대 {db(peak):.1f}dB  평균 {db(rms):.1f}dB  {verdict}")
print("   2초마다 최대: " + " ".join(f"{p:.0f}" for p in parts))
PY
    rm -f "$tmp"
done
