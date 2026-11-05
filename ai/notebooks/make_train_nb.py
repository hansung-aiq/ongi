import json
cells = []
def md(s): cells.append({"cell_type":"markdown","metadata":{},"source":s.strip("\n")})
def code(s): cells.append({"cell_type":"code","metadata":{},"execution_count":None,"outputs":[],"source":s.strip("\n")})

md("""
# 온기 LLM 학습 v3.7 → 병합 → 제출 (Colab T4)
**순서대로 위에서부터 한 칸씩 실행하세요.** 처음부터 끝까지 약 30~40분.

| 단계 | 하는 일 |
|---|---|
| 0 | 런타임 → 런타임 유형 변경 → **T4 GPU** |
| 1 | 설치, Hugging Face 로그인 (Llama-3.2 사용 허가 받은 토큰) |
| 2 | 구글 드라이브 연결, 데이터 2개 확인 |
| 3 | 토크나이저 + 새 토큰 4개 |
| 4 | LoRA 학습 (3 epoch) |
| 5 | 평가 183문장 채점 |
| 6 | **LoRA를 베이스와 병합 → fp16 모델 저장** |
| 7 | 병합 모델 다시 불러 확인 |
| 8 | 팀 폴더에 복사 |

학습 설정 = 11/2 3차와 같음: Llama-3.2-1B-Instruct, LoRA r=16 (모든 선형층), 새 토큰 4개 임베딩만 학습, 3 epoch, 배치 8, LR 2e-4, 5% warmup.
""")
code("""
!nvidia-smi --query-gpu=name,memory.total --format=csv
!pip -q install -U "transformers>=4.46,<5" "peft>=0.15" accelerate datasets
!pip -q uninstall -y torchao   # Colab 기본 torchao가 옛 버전이라 peft와 충돌 → 지움. 그다음 런타임 > 세션 다시 시작
""")
code("""
from huggingface_hub import login
login()   # Llama-3.2-1B-Instruct 사용 허가를 받은 계정의 토큰 (Read)
""")
md("## 2. 드라이브 연결 + 데이터\n`DATA_DIR`에 `온기_학습데이터_v3.7_최종.csv`, `온기_평가데이터_v3.7.csv` 두 개를 넣어 두세요. `OUT_DIR`은 결과가 저장될 곳(내 드라이브)입니다.")
code("""
from google.colab import drive
drive.mount('/content/drive')

DATA_DIR = '/content/drive/MyDrive/온기_학습'          # ← 데이터 넣은 폴더
OUT_DIR  = '/content/drive/MyDrive/온기_학습/결과_v3.7'  # ← 결과 저장 폴더
TRAIN_CSV = f'{DATA_DIR}/온기_학습데이터_v3.7_최종.csv'
EVAL_CSV  = f'{DATA_DIR}/온기_평가데이터_v3.7.csv'

import os, pandas as pd
os.makedirs(OUT_DIR, exist_ok=True)
tr = pd.read_csv(TRAIN_CSV); ev = pd.read_csv(EVAL_CSV)
print('학습', len(tr), '(원본', (tr['구분']=='원본').sum(), '/ 띄어쓰기변형', (tr['구분']!='원본').sum(), ')  평가', len(ev))
assert len(tr) == 1061 and len(ev) == 183, '파일이 맞는지 확인'
assert not (set(tr['Query(한글)']) & set(ev['Query(한글)'])), '학습·평가 겹침'
""")
md("## 3. 토크나이저 + 새 토큰\n프롬프트는 보드 앱(GenieLlm)과 **똑같아야** 합니다. 앞머리 `<|im_start|>`도 앱 Config와 같게 둡니다.")
code("""
import torch, re
from transformers import AutoTokenizer, AutoModelForCausalLM
BASE = 'meta-llama/Llama-3.2-1B-Instruct'   # 허가 없으면 'unsloth/Llama-3.2-1B-Instruct' (같은 가중치 공개 사본)
NEW_TOKENS = ['<maum_0>', '<maum_1>', '<maum_sep>', '<maum_end>']
PREFIX = '<|im_start|>'
HEAD = ('Below is the query from the users, please choose the correct function '
        'and generate the parameters to call the function. Query: ')
TAIL = ' Response:'
def prompt(q): return PREFIX + HEAD + q + TAIL

tok = AutoTokenizer.from_pretrained(BASE)
tok.add_special_tokens({'additional_special_tokens': NEW_TOKENS})
tok.pad_token = tok.eos_token
NEW_IDS = tok.convert_tokens_to_ids(NEW_TOKENS)
END_ID = NEW_IDS[3]
print('새 토큰 id', dict(zip(NEW_TOKENS, NEW_IDS)))
print(tok.tokenize(prompt('나 오늘 시험 망쳤어'))[:12], '...')
""")
code("""
from datasets import Dataset
def encode(q, out):
    p = tok(prompt(q), add_special_tokens=True)['input_ids']          # <|begin_of_text|> + 프롬프트
    o = tok(out, add_special_tokens=False)['input_ids']               # 출력은 <maum_end>로 끝남
    assert o[-1] == END_ID
    return {'input_ids': p + o, 'labels': [-100]*len(p) + o}          # 프롬프트 부분은 정답에서 뺌
ds = Dataset.from_list([encode(q, o) for q, o in zip(tr['Query(한글)'], tr['LLM Output'])]).shuffle(seed=37)
print('최대 길이', max(len(x) for x in ds['input_ids']))

def collate(b):
    n = max(len(x['input_ids']) for x in b)
    ids = [x['input_ids'] + [tok.pad_token_id]*(n-len(x['input_ids'])) for x in b]
    lab = [x['labels'] + [-100]*(n-len(x['labels'])) for x in b]
    att = [[1]*len(x['input_ids']) + [0]*(n-len(x['input_ids'])) for x in b]
    return {'input_ids': torch.tensor(ids), 'labels': torch.tensor(lab), 'attention_mask': torch.tensor(att)}
""")
md("## 4. LoRA 학습")
code("""
from peft import LoraConfig, get_peft_model
model = AutoModelForCausalLM.from_pretrained(BASE, dtype=torch.float32).cuda()
model.resize_token_embeddings(len(tok))
# 새 토큰 임베딩은 비슷한 기존 토큰 평균으로 시작
with torch.no_grad():
    E = model.get_input_embeddings().weight
    E[NEW_IDS] = E[:-len(NEW_IDS)].mean(0, keepdim=True)

cfg = LoraConfig(r=16, lora_alpha=32, lora_dropout=0.05, task_type='CAUSAL_LM',
                 target_modules=['q_proj','k_proj','v_proj','o_proj','gate_proj','up_proj','down_proj'],
                 trainable_token_indices={'embed_tokens': NEW_IDS})   # 새 토큰 4줄만 학습
model = get_peft_model(model, cfg)
model.print_trainable_parameters()
""")
code("""
from transformers import Trainer, TrainingArguments
args = TrainingArguments(output_dir='/content/ckpt', num_train_epochs=3, per_device_train_batch_size=8,
    learning_rate=2e-4, warmup_ratio=0.05, lr_scheduler_type='cosine', weight_decay=0.0,
    fp16=True, logging_steps=20, save_strategy='no', report_to='none', seed=37)
trainer = Trainer(model=model, args=args, train_dataset=ds, data_collator=collate)
trainer.train()
model.save_pretrained(f'{OUT_DIR}/lora_adapter')   # 혹시 몰라 어댑터도 보관
tok.save_pretrained(f'{OUT_DIR}/lora_adapter')
""")
md("## 5. 평가 183문장 채점\n형식 / 상황 맞힘 / 일반 맞힘 / 공감 규칙(25자 이하, 물음표 없음)을 봅니다.")
code("""
P = re.compile(r'^<maum_0>\\(situation=(\\d+), feeling=(-?\\d+)\\)<maum_sep>(.+)<maum_end>$')
G = re.compile(r'^<maum_1>\\(\\)<maum_end>$')
def gold_sit(o):
    m = P.match(o); return int(m[1]) if m else 0

@torch.no_grad()
def gen(m, qs, bs=16):
    tok.padding_side = 'left'; outs = []
    for i in range(0, len(qs), bs):
        enc = tok([prompt(q) for q in qs[i:i+bs]], return_tensors='pt', padding=True).to(m.device)
        g = m.generate(**enc, max_new_tokens=40, do_sample=False, eos_token_id=[END_ID, tok.eos_token_id],
                       pad_token_id=tok.pad_token_id)
        outs += [tok.decode(x[enc['input_ids'].shape[1]:], skip_special_tokens=False)
                   .replace(tok.eos_token, '').replace(tok.pad_token, '').strip() for x in g]
    return outs

def score(m, name):
    m.eval(); outs = gen(m, list(ev['Query(한글)']))
    rows = []; c = dict(형식=0, 상황=0, 상황n=0, 일반=0, 일반n=0, 규칙위반=0)
    for q, o, y in zip(ev['Query(한글)'], ev['LLM Output'], outs):
        ok = bool(P.match(y) or G.match(y)); c['형식'] += ok
        g = gold_sit(o); p = gold_sit(y)
        if g: c['상황n'] += 1; c['상황'] += (p == g)
        else: c['일반n'] += 1; c['일반'] += bool(G.match(y))
        if p:
            e = P.match(y)[3]
            if len(e.replace(' ', '')) > 25 or '?' in e: c['규칙위반'] += 1
        rows.append(dict(Query=q, 정답=o, 출력=y, 맞음=(p == g and ok)))
    print(f"[{name}] 형식 {c['형식']}/183  상황 {c['상황']}/{c['상황n']}  일반 {c['일반']}/{c['일반n']}  공감 규칙 위반 {c['규칙위반']}")
    df = pd.DataFrame(rows); df.to_csv(f'{OUT_DIR}/평가결과_{name}.csv', index=False, encoding='utf-8-sig')
    return df
r1 = score(model, 'LoRA')
r1[~r1['맞음']].head(20)
""")
md("## 6. 병합 → fp16 저장 (제출본)\n멘토 요청: LoRA 어댑터는 반드시 베이스와 **병합**해서 제출.")
code("""
merged = model.merge_and_unload()
merged = merged.to(torch.float16)
merged.generation_config.eos_token_id = [END_ID, tok.eos_token_id]
merged.generation_config.pad_token_id = tok.pad_token_id
merged.generation_config.do_sample = False
merged.generation_config.temperature = None; merged.generation_config.top_p = None
MERGED = '/content/ongi_llama3.2-1b_v3.7_merged'
merged.save_pretrained(MERGED, safe_serialization=True)
tok.padding_side = 'right'
tok.save_pretrained(MERGED)
!ls -la {MERGED}; du -sh {MERGED}
""")
md("## 7. 병합 모델을 새로 불러서 다시 채점\nLoRA 결과와 거의 같아야 정상입니다. (fp16이라 1~2개 차이는 괜찮음)")
code("""
del model, merged, trainer; torch.cuda.empty_cache()
tok = AutoTokenizer.from_pretrained(MERGED)
m2 = AutoModelForCausalLM.from_pretrained(MERGED, dtype=torch.float16).cuda()
assert tok.convert_tokens_to_ids(NEW_TOKENS) == NEW_IDS
r2 = score(m2, '병합fp16')
for q in ['나 오늘 시험 망쳤어', '친 구랑 싸웠어', '엄마 보고 싶어', '그림 대회에서 상 받았어', '온기야 오늘 뭐 먹지']:
    print(q, '→', gen(m2, [q])[0])
""")
md("## 8. 팀 폴더에 복사\n공유 드라이브 팀 폴더 경로를 `TEAM_DIR`에 넣으세요. (드라이브 왼쪽 '공유 드라이브' 아래)")
code("""
TEAM_DIR = '/content/drive/Shareddrives/<공유드라이브 이름>/<팀 폴더>'   # ← 바꾸기
import shutil
shutil.copytree(MERGED, f'{TEAM_DIR}/ongi_llama3.2-1b_v3.7_merged', dirs_exist_ok=True)
os.makedirs(f'{TEAM_DIR}/학습데이터', exist_ok=True)
for f in ['온기_학습데이터_v3.7_최종.csv', '온기_학습데이터_v3.7_최종.json', '온기_평가데이터_v3.7.csv',
          '온기_평가데이터_v3.7.json', '제출_안내.md']:
    if os.path.exists(f'{DATA_DIR}/{f}'): shutil.copy(f'{DATA_DIR}/{f}', f'{TEAM_DIR}/학습데이터/')
!ls -R "{TEAM_DIR}" | head -40
""")
nb = {"cells":cells,"metadata":{"accelerator":"GPU","colab":{"gpuType":"T4","provenance":[]},
      "kernelspec":{"display_name":"Python 3","name":"python3"},"language_info":{"name":"python"}},
      "nbformat":4,"nbformat_minor":0}
json.dump(nb, open("ai/notebooks/온기_LLM학습_v3.7_병합제출_Colab.ipynb","w",encoding="utf-8"), ensure_ascii=False, indent=1)
print("ok", len(cells))
