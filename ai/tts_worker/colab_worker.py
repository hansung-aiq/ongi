# 온기 부모 목소리 TTS 작업기 (Colab T4 / 윈도우 GPU 공용)
# 서버의 할 일(GET /tts/jobs: 미리 듣기 먼저, 그다음 메시지)을 가져와 Qwen3-TTS 제로샷 복제로 wav를 만들어 올린다.
# 모델은 학습하지 않는다: 부모가 '목소리 만들기'에서 읽은 문장 5개 녹음을 이어 붙여 견본으로 넣는다.
#
# Colab: 런타임 T4 → 셀 1 `!pip install -q -U qwen-tts soundfile requests` → 셀 2에 이 파일을 붙여 넣고 SERVER/TOKEN 고쳐 실행
import io, os, subprocess, tempfile, time
import numpy as np, requests, soundfile as sf, torch
from qwen_tts import Qwen3TTSModel

SERVER = os.environ.get("ONGI_SERVER", "https://<터널주소>.trycloudflare.com")  # 윈도우면 http://<맥IP>:8000
TOKEN = os.environ.get("ONGI_WORKER_TOKEN", "")  # 서버 .env의 TTS_WORKER_TOKEN
POLL_SEC = 2
H = {"X-Worker-Token": TOKEN} if TOKEN else {}
SR = 24000

dev = "cuda:0" if torch.cuda.is_available() else "cpu"
# T4 등은 float16에서 확률값이 깨져 CUDA assert → float32
model = Qwen3TTSModel.from_pretrained("Qwen/Qwen3-TTS-12Hz-0.6B-Base",
                                      device_map=dev, dtype=torch.float32, attn_implementation="sdpa")
print("모델 준비:", dev, flush=True)

_ref_cache = {}  # (profile_id, profile_version) -> (wav 경로, 대본)


def load_m4a(data: bytes) -> np.ndarray:
    src = tempfile.NamedTemporaryFile(suffix=".m4a", delete=False); src.write(data); src.close()
    dst = src.name + ".wav"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src.name, "-ac", "1", "-ar", str(SR), dst], check=True)
    wav, _ = sf.read(dst, dtype="float32")
    return wav


def trim(wav: np.ndarray, thr=0.01) -> np.ndarray:
    """앞뒤 무음 자르기(녹음 버튼 누른 소리·빈 시간)"""
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
    for s in job["samples"]:
        r = requests.get(f"{SERVER}/tts/profile-audio/{job['profile_id']}", headers=H, params={"index": s["index"]}, timeout=30)
        r.raise_for_status()
        parts += [trim(load_m4a(r.content)), gap]
        texts.append(s["text"])
    path = f"/tmp/ref_{job['profile_id']}_{len(_ref_cache)}.wav"
    sf.write(path, np.concatenate(parts[:-1]), SR)
    _ref_cache[key] = (path, " ".join(texts))
    print(f"  견본 준비: {len(texts)}개 이어 붙임", flush=True)
    return _ref_cache[key]


def make(job):
    ref_audio, ref_text = reference(job)
    text = job["text"]
    max_tokens = min(900, len(text) * 3 + 100)  # 끝을 못 찾고 계속 만드는 것 방지(12Hz 토큰)
    wavs, sr = model.generate_voice_clone(text=text, language="Korean", ref_audio=ref_audio, ref_text=ref_text,
                                          max_new_tokens=max_tokens)
    wav = wavs[0] if isinstance(wavs, (list, tuple)) else wavs
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
        except Exception as e:
            print("  → 실패:", e, flush=True)
            path = f"/tts/previews/{jid}/fail" if kind == "preview" else f"/tts/jobs/{jid}/fail"
            requests.post(f"{SERVER}{path}", headers=H, timeout=15)
    if not jobs:
        time.sleep(POLL_SEC)
