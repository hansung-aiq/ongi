#!/bin/bash
# [온기] LLM 모델 바꾸기 — 빌드 없이 (11/7)
#   bash device/tools/swap_llm.sh <맥 폴더>                  마음AI가 준 Genie 파일(json·context binary·tokenizer·ext json)을 보드에 넣고 바꿈
#   bash device/tools/swap_llm.sh --board <보드 폴더>         이미 보드에 있는 파일로 바꿈 (리허설: --board /data/local/tmp/model/korean)
#   bash device/tools/swap_llm.sh --back                      가짜 LLM으로 되돌리기 (use_genie false)
#   PREFIX="" bash device/tools/swap_llm.sh ...               앞머리 바꾸기 (기본 "<|im_start|>", 멘토 답에 따라)
# 하는 일: 파일 넣기 → json 안 경로를 그 폴더로 고친 ongi_genie.json 만들기 → 토큰 번호 점검 → config.json → 앱 다시 켜기 → 한 문장 시험
cd "$(dirname "$0")/../.." || exit 1
PKG=com.aiq.ongi.device
ROOT=/data/local/tmp/ongi/llm
TMP=/tmp/ongi_swap; rm -rf $TMP; mkdir -p $TMP
ok()   { echo "  ✅ $*"; }
bad()  { echo "  ❌ $*"; }
info() { echo "  ・ $*"; }

if ! adb devices | grep -q "device$"; then
    adb kill-server >/dev/null 2>&1; sleep 1; adb devices >/dev/null 2>&1; sleep 2
fi
adb devices | grep -q "device$" || { bad "보드가 안 보여요 (전원 초록 불·USB-C). adb devices 결과: $(adb devices | sed 1d | tr '\n' ' ')"; exit 1; }
adb root >/dev/null 2>&1; sleep 1; adb wait-for-device

if [ "$1" = "--back" ]; then
    bash device/tools/set_config.sh use_genie false >/dev/null
    ok "가짜 LLM으로 (30초 안에 반영). 지금 설정: $(adb shell cat /data/local/tmp/ongi/config.json | tr -d '\r')"
    exit 0
fi

echo "1. 파일"
if [ "$1" = "--board" ]; then
    DIR="${2%/}"
    adb shell ls "$DIR" >/dev/null 2>&1 || { bad "보드에 $DIR 없음"; exit 1; }
    info "보드 폴더 그대로: $DIR"
elif [ -d "$1" ]; then
    SRC="${1%/}"; DIR="$ROOT/$(basename "$SRC")"
    SZ=$(du -sh "$SRC" | cut -f1)
    info "$SRC ($SZ) → 보드 $DIR  (1.5GB면 USB로 약 1~2분)"
    adb shell mkdir -p "$DIR"
    for f in "$SRC"/*; do [ -f "$f" ] && { adb push "$f" "$DIR"/ || { bad "push 실패: $f"; exit 1; }; }; done
    adb shell chmod -R 755 $ROOT
    ok "넣음"
else
    sed -n 2,7p "$0"; exit 1
fi
adb shell ls -la "$DIR" | tr -d '\r' | sed 's/^/     /'

echo "2. Genie json"
J=$(adb shell "grep -l '\"dialog\"' $DIR/*.json 2>/dev/null" | tr -d '\r' | grep -v ongi_genie.json | head -1)
[ -n "$J" ] || { bad "$DIR 안에 \"dialog\"가 든 json이 없음"; exit 1; }
adb pull "$J" $TMP/orig.json >/dev/null
info "원본: $J"
# (반복문 안 adb는 </dev/null: 안 그러면 adb가 목록의 나머지 줄을 먹어 버림)
# json이 가리키는 파일 찾기: 같은 폴더에 있으면 그것, 없으면 json에 적힌 원래 경로 (예제 모델은 /data/local/tmp/ 바로 아래)
python3 - "$TMP" <<'PY' || exit 1
import json, sys
dl = json.load(open(f"{sys.argv[1]}/orig.json"))["dialog"]; eng = dl["engine"]; be = eng["backend"]
ps = [dl["tokenizer"]["path"]] + ([be["extensions"]] if "extensions" in be else []) + eng["model"]["binary"]["ctx-bins"]
open(f"{sys.argv[1]}/orig.txt", "w").write("\n".join(ps) + "\n")
PY
FAIL=0; : > $TMP/map.txt
while read -r p; do
    [ -z "$p" ] && continue
    q="$DIR/$(basename "$p")"
    if adb shell ls "$q" >/dev/null 2>&1 </dev/null; then info "있음 $q"; echo "$p|$q" >> $TMP/map.txt
    elif adb shell ls "$p" >/dev/null 2>&1 </dev/null; then info "있음 $p (json 원래 경로)"; echo "$p|$p" >> $TMP/map.txt
    else bad "없음 $q (원래 경로 $p 에도 없음)"; FAIL=1; fi
done < $TMP/orig.txt
[ $FAIL = 0 ] || { bad "json이 가리키는 파일이 보드에 없어요"; exit 1; }
TOK=$(grep -m1 "" $TMP/map.txt | cut -d'|' -f2)
adb pull "$TOK" $TMP/tokenizer.json >/dev/null 2>&1
python3 - "$TMP" <<'PY' || exit 1
import json, os, sys
tmp = sys.argv[1]
m = dict(l.strip().split("|") for l in open(f"{tmp}/map.txt") if l.strip())
j = json.load(open(f"{tmp}/orig.json"))
dl = j["dialog"]; eng = dl["engine"]; be = eng["backend"]; ctx = dl["context"]
dl["tokenizer"]["path"] = m[dl["tokenizer"]["path"]]
if "extensions" in be: be["extensions"] = m[be["extensions"]]
b = eng["model"]["binary"]; b["ctx-bins"] = [m[p] for p in b["ctx-bins"]]
json.dump(j, open(f"{tmp}/ongi_genie.json", "w"), indent=2)
print(f"  ・ context {ctx.get('size')} / max-num-tokens {dl.get('max-num-tokens')} / n-vocab {ctx.get('n-vocab')} / bos {ctx.get('bos-token')} / eos {ctx.get('eos-token')} / greedy {dl.get('sampler',{}).get('greedy')}")
# 우리 모델 토큰 (11/5 학습): <maum_0> 128256, <maum_1> 128257, <maum_sep> 128258, <maum_end> 128259, vocab 128260
want = {"<maum_0>": 128256, "<maum_1>": 128257, "<maum_sep>": 128258, "<maum_end>": 128259}
ids = {}
if os.path.exists(f"{tmp}/tokenizer.json"):
    t = json.load(open(f"{tmp}/tokenizer.json"))
    ids = {a["content"]: a["id"] for a in t.get("added_tokens", [])}
    got = {k: ids.get(k) for k in want}
    if got == want: print("  ✅ tokenizer에 새 토큰 4개 (번호도 학습과 같음)")
    else: print(f"  ⚠️  tokenizer 새 토큰이 학습과 다름: {got} (예제 모델이면 정상)")
else:
    print("  ⚠️  tokenizer.json을 못 받아 토큰 점검 못 함")
end = ids.get("<maum_end>", 128259)
eos = ctx.get("eos-token"); eos = eos if isinstance(eos, list) else [eos]
if end in eos: print(f"  ✅ eos에 <maum_end>({end}) 있음 → 공감 끝에서 바로 멈춤")
else: print(f"  ⚠️  eos에 <maum_end>({end}) 없음 → 끝까지 생성해서 느려짐(파싱은 됨). 예제 모델이면 정상, 우리 모델이면 멘토에게 확인")
PY
adb push $TMP/ongi_genie.json $DIR/ongi_genie.json >/dev/null && adb shell chmod 644 $DIR/ongi_genie.json
ok "새 json: $DIR/ongi_genie.json"

echo "3. 설정"
bash device/tools/set_config.sh llm_config "$DIR/ongi_genie.json" >/dev/null
bash device/tools/set_config.sh llm_prefix "${PREFIX-<|im_start|>}" >/dev/null
bash device/tools/set_config.sh use_genie true >/dev/null
ok "$(adb shell cat /data/local/tmp/ongi/config.json | tr -d '\r')"

echo "4. 앱 다시 켜기 (모델 읽기 최대 90초)"
adb logcat -c
adb shell am force-stop $PKG
adb shell am start -n $PKG/.MainActivity >/dev/null 2>&1 || { bad "앱이 설치 안 됨 → Android Studio ▶ Run"; exit 1; }
adb forward tcp:8765 tcp:8765 >/dev/null
adb reverse tcp:8000 tcp:8000 >/dev/null
R=""
for i in $(seq 1 90); do
    R=$(adb logcat -d -s ongi | grep -E "LLM: Genie (준비 완료|Init 실패|읽기 실패)|LLM: 설정 파일을 읽을 수 없음" | tail -1 | sed 's/^.*ongi *: //')
    [ -n "$R" ] && break; sleep 1
done
case "$R" in
    *"준비 완료"*) ok "$R" ;;
    "") bad "90초 안에 LLM 소식 없음 → adb logcat -d -s ongi | grep LLM" ; exit 1 ;;
    *) bad "$R"; info "되돌리기: bash device/tools/swap_llm.sh --back"; exit 1 ;;
esac

echo "5. 한 문장 시험 (앱 켠 직후 미리 준비로 바쁠 수 있어 10초 기다림)"
sleep 10
python3 - <<'PY'
import asyncio, json, websockets
async def m():
    async with websockets.connect("ws://127.0.0.1:8765", max_size=None) as ws:
        for q in ["나 오늘 상 받았어", "배고파"]:
            await ws.send(json.dumps({"type": "check", "text": q, "llm": True}, ensure_ascii=False))
            r = json.loads(await asyncio.wait_for(ws.recv(), 30))
            print(f"  ・ {q} → {r.get('llm_raw', r.get('error'))}  [{r.get('llm_ms')}ms, Genie={r.get('llm_genie')}]")
asyncio.run(m())
PY
echo; echo "바꾸기 끝. 평가: python3 device/tools/llm_eval.py   시연 점검: python3 device/tools/demo_check.py"
