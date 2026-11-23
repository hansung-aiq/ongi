# 온기 부모 목소리 TTS 작업기 (Colab T4 / 윈도우 GPU 공용)
# 서버의 할 일(GET /tts/jobs: 미리 듣기 먼저, 그다음 메시지)을 가져와 Qwen3-TTS 제로샷 복제로 wav를 만들어 올린다.
# 모델은 학습하지 않는다: 부모가 '목소리 만들기'에서 읽은 문장 5개 녹음을 이어 붙여 견본으로 넣는다.
#
# 윈도우: $env:ONGI_SERVER="http://<맥IP>:8000"; $env:ONGI_WORKER_TOKEN="..."; .venv\Scripts\python tts_worker.py
import io, os, subprocess, tempfile, time, traceback
import numpy as np, requests, soundfile as sf, torch
from qwen_tts import Qwen3TTSModel

SERVER = os.environ.get("ONGI_SERVER", "http://192.168.0.178:8000")
TOKEN = os.environ.get("ONGI_WORKER_TOKEN", "")  # 서버 .env의 TTS_WORKER_TOKEN
POLL_SEC = 2
H = {"X-Worker-Token": TOKEN} if TOKEN else {}
SR = 24000
TMP = tempfile.gettempdir()  # 윈도우에는 /tmp가 없다
# 속도 옵션 (환경 변수)
#  ONGI_DTYPE=float16   : 반정밀도. 1650 Ti 등에서 2배 가까이 빠름. 소리가 깨지거나 CUDA 오류가 나면 float32로
#  ONGI_MAX_REF_SEC=12  : 견본을 앞에서부터 이 길이(초)까지만 씀(문장 단위). 짧을수록 빠름
#  ONGI_XVEC=1          : 대본 없이 목소리 특징만 씀. 가장 빠르지만 닮은 정도가 떨어짐
DTYPE = getattr(torch, os.environ.get("ONGI_DTYPE", "float32"))
MAX_REF_SEC = float(os.environ.get("ONGI_MAX_REF_SEC", "12"))
XVEC = os.environ.get("ONGI_XVEC") == "1"
#  ONGI_RETRY=1         : 소리가 글자 수에 비해 너무 짧으면(끝 잘림) 다시 만드는 횟수
RETRY = int(os.environ.get("ONGI_RETRY", "1"))
#  ONGI_TARGET_RMS=0.1  : 보드 기본 TTS(공감 한마디)와 같은 크기로 맞춤. 0이면 그대로
#  ONGI_PAD_SEC=1.5     : 끝에 무음. 보드 tinyplay가 마지막 소리를 자르는 것 방지
TARGET_RMS = float(os.environ.get("ONGI_TARGET_RMS", "0"))
PAD_SEC = float(os.environ.get("ONGI_PAD_SEC", "1.5"))

dev = "cuda:0" if torch.cuda.is_available() else "cpu"
# T4·GTX 등은 float16에서 확률값이 깨져 CUDA assert → float32
model = Qwen3TTSModel.from_pretrained("Qwen/Qwen3-TTS-12Hz-0.6B-Base",
                                      device_map=dev, dtype=DTYPE, attn_implementation="sdpa")
print(f"모델 준비: {dev} / {DTYPE} / 견본 최대 {MAX_REF_SEC:.0f}초 / 대본 없이: {XVEC}", flush=True)

_ref_cache = {}  # (profile_id, profile_version) -> (wav 경로, 대본)
_prompt_cache = {}  # 같은 키 -> 모델이 견본을 미리 계산한 것(매번 견본을 다시 분석하지 않게)


def load_m4a(data: bytes) -> np.ndarray:
    src = os.path.join(TMP, f"ongi_src_{time.time_ns()}.m4a")
    with open(src, "wb") as f:
        f.write(data)
    dst = src + ".wav"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-ac", "1", "-ar", str(SR), dst], check=True)
    wav, _ = sf.read(dst, dtype="float32")
    return wav


def trim(wav: np.ndarray, thr=0.01) -> np.ndarray:
    """앞뒤 무음 자르기(녹음 버튼 누른 소리·빈 시간)"""
    thr = max(thr, 0.1 * float(np.abs(wav).max()))  # 방 소음보다 크게: 녹음 크기의 10%
    idx = np.where(np.abs(wav) > thr)[0]
    if len(idx) == 0:
        return wav
    a, b = max(0, idx[0] - int(0.1 * SR)), min(len(wav), idx[-1] + int(0.15 * SR))
    return wav[a:b]


def reference(job):
    """견본 여러 개를 0.3초 쉼을 두고 이어 붙여 하나의 견본 + 대본으로"""
    key = (job["profile_id"], job["profile_version"])
    if key in _ref_cache:
        return _ref_cache[key]
    parts, texts, gap = [], [], np.zeros(int(0.3 * SR), dtype="float32")
    total = 0.0
    for s in job["samples"]:
        r = requests.get(f"{SERVER}/tts/profile-audio/{job['profile_id']}", headers=H, params={"index": s["index"]}, timeout=30)
        r.raise_for_status()
        w = trim(load_m4a(r.content))
        if texts and total + len(w) / SR > MAX_REF_SEC:
            break  # 문장 단위로 잘라야 대본과 소리가 맞는다
        parts += [w, gap]
        texts.append(s["text"])
        total += len(w) / SR + 0.3
    path = os.path.join(TMP, f"ongi_ref_{job['profile_id']}_{len(_ref_cache)}.wav")
    sf.write(path, np.concatenate(parts[:-1]), SR)
    _ref_cache[key] = (path, " ".join(texts))
    print(f"  견본 준비: {len(texts)}개 이어 붙임, {total:.1f}초", flush=True)
    return _ref_cache[key]


def prompt_for(job):
    key = (job["profile_id"], job["profile_version"], XVEC)
    if key not in _prompt_cache:
        ref_audio, ref_text = reference(job)
        t = time.time()
        _prompt_cache[key] = model.create_voice_clone_prompt(
            ref_audio=ref_audio, ref_text=None if XVEC else ref_text, x_vector_only_mode=XVEC)
        print(f"  견본 분석: {time.time() - t:.1f}초 (다음부터는 재사용)", flush=True)
    return _prompt_cache[key]


def loudness(w: np.ndarray, sr: int) -> np.ndarray:
    """말하는 부분의 크기를 TARGET_RMS로. 너무 큰 소리는 0.9 위에서 부드럽게 눌러 깨지지 않게"""
    if TARGET_RMS <= 0:
        return w
    win = int(sr * 0.02); n = len(w) // win
    e = (w[:n * win].reshape(n, win) ** 2).mean(1); e = e[e > 1e-4]
    if not len(e):
        return w
    y = (w * min(TARGET_RMS / float(np.sqrt(e.mean())), 4.0)).astype(np.float32)
    a = np.abs(y); o = a > 0.9
    y[o] = np.sign(y[o]) * (0.9 + 0.1 * np.tanh((a[o] - 0.9) / 0.1))
    return y


def make(job):
    prompt = prompt_for(job)
    text = job["text"]
    max_tokens = min(900, len(text) * 3 + 100)  # 끝을 못 찾고 계속 만드는 것 방지(12Hz 토큰)
    # 끝을 일찍 선언해 뒷부분이 잘리는 경우가 있어, 글자 수에 비해 너무 짧으면 다시 만든다
    chars = len([c for c in text if not c.isspace() and c not in ".,!?~…"])
    min_sec = chars * 0.12
    best = None
    for attempt in range(1 + RETRY):
        t = time.time()
        wavs, sr = model.generate_voice_clone(text=text, language="Korean", voice_clone_prompt=prompt,
                                              max_new_tokens=max_tokens)
        w = wavs[0] if isinstance(wavs, (list, tuple)) else wavs
        sec = len(w) / sr
        print(f"  생성{'' if attempt == 0 else f'(다시 {attempt})'}: {time.time() - t:.1f}초 → 음성 {sec:.1f}초 "
              f"(글자 {chars}개, 최소 {min_sec:.1f}초)", flush=True)
        if best is None or sec > best[1]:
            best = (w, sec)
        if sec >= min_sec:
            break
    wav = loudness(np.asarray(best[0], dtype=np.float32), sr)
    wav = np.concatenate([wav, np.zeros(int(PAD_SEC * sr), dtype=np.float32)])
    buf = io.BytesIO()
    sf.write(buf, wav, sr, format="WAV", subtype="PCM_16")  # 보드 Wav.read는 16bit PCM
    return buf.getvalue(), len(wav) / sr


print("작업 대기:", SERVER, flush=True)
while True:
    try:
        jobs = requests.get(f"{SERVER}/tts/jobs", headers=H, params={"limit": 1}, timeout=15).json()["items"]
    except Exception as e:
        print("서버 연결 실패:", e, flush=True); time.sleep(5); continue
    for job in jobs:  # 한 번에 하나씩: 그 사이 들어온 미리 듣기가 먼저 처리되게
        kind, jid, t = job["type"], job["id"], time.time()
        print(f"[{kind} {jid}] {job['text'][:30]}…", flush=True)
        try:
            data, secs = make(job)
            files = {"file": (f"{jid}.wav", data, "audio/wav")}
            if kind == "preview":
                r = requests.post(f"{SERVER}/tts/previews/{jid}/result", headers=H, files=files, timeout=60)
            else:
                r = requests.post(f"{SERVER}/tts/jobs/{jid}", headers=H, data={"updated_at": job["updated_at"]},
                                  files=files, timeout=60)
            print(f"  → {r.status_code} / 음성 {secs:.1f}초 / {time.time() - t:.1f}초 걸림", flush=True)
        except Exception:
            print("  → 실패:", flush=True)
            traceback.print_exc()
            path = f"/tts/previews/{jid}/fail" if kind == "preview" else f"/tts/jobs/{jid}/fail"
            try:
                requests.post(f"{SERVER}{path}", headers=H, timeout=15)
            except Exception:
                pass
    if not jobs:
        time.sleep(POLL_SEC)
