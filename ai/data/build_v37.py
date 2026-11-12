"""
[온기] 학습·평가 데이터 v3.6 (한정판) 만들기 — 2026-11-04

v3.6 원칙 (11/4 지현 결정: "변수는 다 없앤다, 정한 말 안의 공감에만 집중")
  1. 상황마다 '정한 말'(핵심 말)만 쓴다. 장소·이유·특정 인물(관장님·사촌·모기·천둥·명절 등) 없음
  2. 바뀌는 것은 말투만: 앞말(나 / 오늘 / 온기야 / 엄마 나 …), 말끝(-어 / -어요 / -거든 / -잖아 / -단 말이야 / -다), 강조(진짜 / 너무 / 크게)
  3. 기분 번호는 상황마다 하나로 고정(situations.json의 default_feeling). 감정 말을 붙인 문장(싸워서 속상해 등)은 넣지 않음
  4. 공감 한마디는 아이가 한 말을 그대로 받아 주는 문장(정한 틀 안에서만)
  5. 평가 = 대표 문장 시험지: 같은 '정한 말'을 학습에 없는 말투 조합으로. 학습과 겹침 0
  6. 애매한 말(책·만화 보다가 운 것 등)은 학습·평가 모두 넣지 않음. 일반 대화는 '비슷하지만 상황이 아닌 말' 위주로 남김

실행: python3 build_v36.py <v3.5.2 xlsx> <출력 폴더>
"""
import json
import random
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

import openpyxl
from openpyxl.styles import Font

random.seed(36)

FEEL = {1: 4, 2: 1, 3: 1, 4: 1, 5: 1, 6: 1, 7: 1, 8: 4, 9: 3, 10: 5, 11: 6, 12: 6}
NAMES = {1: "학교 가기 싫은 날", 2: "실수해서 혼났을 때", 3: "시험을 망친 날", 4: "친구와 싸운 날",
         5: "친구가 날 싫어하는 것 같을 때", 6: "남들과 비교될 때", 7: "울고 싶은 날", 8: "아무것도 하기 싫은 날",
         9: "잠이 안 오는 밤", 10: "부모님이 보고 싶을 때", 11: "자랑하고 싶은 날", 12: "생일"}

# 말끝: 줄기 + 끝 (싫·싶·같·없·었/았 줄기에 그대로 붙음)
E = ["어", "어요", "거든", "잖아", "단 말이야", "다"]
EA = ["아", "아요", "거든", "잖아", "단 말이야", "다"]  # 같·귀찮 줄기

P_ALL = ["", "나 ", "오늘 ", "나 오늘 ", "온기야 ", "엄마 나 ", "아빠 나 ", "있잖아 "]
P_NOPARENT = ["", "나 ", "오늘 ", "나 오늘 ", "온기야 ", "있잖아 ", "지금 "]
P_NOTODAY = ["", "나 ", "온기야 ", "엄마 ", "아빠 ", "있잖아 "]


def forms(stem, ends=E):
    return [stem + e for e in ends]


def F(*pairs):
    """명시한 말끝 목록"""
    return list(pairs)


# 정한 말: (본문 목록, 공감 틀 목록, 앞말 목록)
#   공감 틀의 {t} = 아이 말에 '오늘'이 있으면 "오늘 ", 없으면 ""
#   {w} 등은 본문마다 정한 값
CORES = defaultdict(list)


def core(sid, bodies, emp, prefixes=P_ALL, **slots):
    CORES[sid].append(dict(bodies=bodies, emp=emp, prefixes=prefixes, slots=slots))


# ===== v3.7: 시연 4개 상황만 (3 · 4 · 10 · 11). 설계는 12개 유지 =====
DEMO = [3, 4, 10, 11]
E2 = E + ["거든요", "잖아요"]
EA2 = EA + ["거든요", "잖아요"]
P_D = ["", "나 ", "오늘 ", "나 오늘 ", "아까 ", "나 아까 ", "온기야 ", "온기야 나 ", "엄마 나 ", "아빠 나 ", "엄마 ", "아빠 ", "있잖아 ", "있잖아 나 ", "있잖아 오늘 "]
P_D10 = ["", "나 ", "오늘 ", "나 오늘 ", "온기야 ", "온기야 나 ", "있잖아 ", "있잖아 나 ", "지금 ", "나 지금 ", "갑자기 ", "오늘따라 ", "밤 되니까 "]

# 3 시험을 망친 날 (기분 1)
for w, o in [("시험 ", "시험을 "), ("수학 시험 ", "수학 시험을 "), ("받아쓰기 ", "받아쓰기를 "), ("영어 시험 ", "영어 시험을 "), ("단원평가 ", "단원평가를 ")]:
    core(3, forms(f"{w}망쳤", E2) + forms(f"{w}망했", E2) + forms(f"{w}완전 망쳤", E2),
         ["{t}{o}망쳤구나", "{t}{o}망친 날이구나", "{o}망쳐서 속상했구나", "{t}{o}망쳐서 마음이 무겁구나", "{t}{o}잘 못 봐서 속상하구나"], P_D, o=o)
for w, o in [("시험 ", "시험을 "), ("수학 시험 ", "수학 시험을 "), ("영어 시험 ", "영어 시험을 ")]:
    core(3, forms(f"{w}못 봤", E2) + forms(f"{w}잘 못 봤", E2),
         ["{t}{o}잘 못 봤구나", "{o}못 봐서 속상했구나", "{t}{o}잘 못 본 날이구나", "{t}시험이 잘 안 됐구나"], P_D, o=o)
for w in ["시험 ", "수학 ", "받아쓰기 ", "영어 "]:
    core(3, forms(f"{w}점수 낮게 나왔", E2) + forms(f"{w}점수가 낮게 나왔", E2),
         ["{t}{w}점수가 낮게 나왔구나", "점수가 낮아서 속상했구나", "{t}점수가 생각보다 낮았구나", "{t}{w}점수 때문에 속상하구나"], P_D, w=w)
core(3, forms("시험 빵점 맞았", E2) + forms("받아쓰기 빵점 맞았", E2),
     ["{t}점수가 많이 낮게 나왔구나", "점수 때문에 많이 속상했구나", "{t}시험을 망친 날이구나"], P_D)

# 4 친구와 싸운 날 (기분 1)
for w in ["친구랑 ", "짝꿍이랑 ", "친구들이랑 ", "반 친구랑 ", "제일 친한 친구랑 "]:
    for i in ["", "크게 ", "또 "]:
        core(4, forms(f"{w}{i}싸웠", E2), ["{t}{w}싸웠구나", "{t}{w}싸운 날이구나", "{w}싸워서 속상했구나", "{t}{w}다퉈서 마음이 안 좋구나"], P_D, w=w)
        core(4, forms(f"{w}{i}다퉜", E2), ["{t}{w}다퉜구나", "{w}다퉈서 속상했구나", "{t}{w}다툰 날이구나", "{t}{w}다퉈서 마음이 무겁구나"], P_D, w=w)
    core(4, forms(f"{w}싸움 났", E2), ["{t}{w}싸움이 났구나", "{w}싸워서 속상했구나", "{t}{w}싸운 날이구나"], P_D, w=w)
    core(4, forms(f"{w}말다툼했", E2), ["{t}{w}말다툼을 했구나", "{w}다퉈서 속상했구나", "{t}{w}다툰 날이구나"], P_D, w=w)

# 10 부모님이 보고 싶을 때 (기분 5)
for w, n in [("엄마 ", "엄마가 "), ("아빠 ", "아빠가 "), ("엄마 아빠 ", "엄마 아빠가 "), ("우리 엄마 ", "엄마가 "), ("우리 아빠 ", "아빠가 ")]:
    for i in ["", "너무 ", "진짜 ", "많이 "]:
        core(10, forms(f"{w}{i}보고 싶", E2), ["{t}{n}많이 보고 싶구나", "{t}{n}보고 싶은 날이구나", "{t}{n}많이 그립구나", "{t}{n}보고 싶어서 마음이 허전하구나", "{t}{n}곁에 있으면 좋겠구나", "{t}{n}생각이 많이 나는구나", "{t}그리운 마음이 드는구나"], P_D10, n=n)
    core(10, forms(f"{w}목소리 듣고 싶", E2), ["{t}{w}목소리가 듣고 싶구나", "{t}{n}많이 그립구나", "{t}{n}보고 싶은 날이구나", "{t}{w}목소리가 그리운 날이구나", "{t}{n}곁에 있으면 좋겠구나"], P_D10, w=w, n=n)
    core(10, F(f"{w}그리워", f"{w}그리워요", f"{w}그립거든", f"{w}그립잖아", f"{w}그립단 말이야", f"{w}너무 그리워", f"{w}그립다"),
         ["{t}{n}많이 그립구나", "{t}{n}많이 보고 싶구나", "그리운 마음이 크구나", "{t}{n}그리운 날이구나", "{t}그리운 마음이 드는구나", "{t}{n}생각이 많이 나는구나"], P_D10, n=n)
    core(10, F(f"{w}생각나", f"{w}생각나요", f"{w}생각나거든", f"{w}자꾸 생각나", f"{w}생각난단 말이야"),
         ["{t}{n}자꾸 생각나는구나", "{t}{n}많이 보고 싶구나", "{t}{n}그리운 날이구나", "{t}{n}생각이 많이 나는구나", "{t}그리운 마음이 드는구나"], P_D10, n=n)

# 11 자랑하고 싶은 날 (기분 6)
for w in ["", "학교에서 ", "대회에서 ", "그림 대회에서 ", "글짓기 대회에서 "]:
    core(11, forms(f"{w}상 받았", E2) + forms(f"{w}상장 받았", E2),
         ["{t}{w}상을 받았구나", "상 받아서 정말 기쁘구나", "{t}상을 받은 날이구나", "{t}뿌듯한 날이구나", "{t}{w}상을 받다니 정말 기쁘구나", "{t}열심히 한 보람이 있구나", "{t}자랑하고 싶은 날이구나"], P_D, w=w)
for w in ["", "선생님한테 ", "학교에서 "]:
    core(11, forms(f"{w}칭찬받았", E2) + forms(f"{w}칭찬 많이 받았", E2),
         ["{t}{w}칭찬을 받았구나", "칭찬받아서 뿌듯하구나", "{t}기분 좋은 날이구나", "{t}칭찬받은 날이구나", "{t}열심히 한 보람이 있구나", "{t}자랑하고 싶은 날이구나"], P_D, w=w)
for w in ["", "시험 ", "수학 시험 ", "받아쓰기 "]:
    core(11, forms(f"{w}백 점 맞았", E2) + forms(f"{w}백 점 받았", E2),
         ["{t}{w}백 점을 맞았구나", "백 점이라니 정말 뿌듯하구나", "{t}기분 좋은 날이구나", "{t}{w}백 점이라 기쁘구나", "{t}열심히 한 보람이 있구나", "{t}자랑하고 싶은 날이구나"], P_D, w=w)
for w in ["", "달리기 ", "반에서 ", "대회에서 "]:
    core(11, forms(f"{w}일등 했", E2), ["{t}{w}일등을 했구나", "일등이라니 정말 기쁘구나", "{t}뿌듯한 날이구나", "{t}{w}일등이라 뿌듯하구나", "{t}열심히 한 보람이 있구나", "{t}자랑하고 싶은 날이구나"], P_D, w=w)

# 시연 문장: 반드시 학습에 넣는다
MUST = {"오늘 친구랑 싸웠어", "친구랑 싸웠어", "나 친구랑 싸웠어", "나 오늘 상 받았어", "상 받았어", "오늘 상 받았어", "엄마 보고 싶어", "아빠 보고 싶어", "엄마 너무 보고 싶어", "시험 망쳤어", "오늘 시험 망쳤어", "나 오늘 시험 망쳤어",
        "학교 가기 싫어", "혼났어", "오늘 혼났어", "시험 망쳤어", "애들이 나만 빼고 놀아", "울고 싶어",
        "아무것도 하기 싫어", "잠이 안 와", "오늘 내 생일이야", "나만 못해", "선생님한테 혼났어"}

NEAR = "혼|야단|꾸중|시험|받아쓰기|싸|다퉈|다퉜|울|눈물|생일|상 |상장|칭찬|일등|잠|자고|자러|잘 자|꿈|엄마|아빠|학교|친구|애들|짝꿍|놀|비교|부러|귀찮|하기|싶어|보다|보다가"

# 일반 대화에서 뺄 것(애매한 말)
GEN_DROP = {"만화 보다가 눈물 났어", "드라마 보는데 눈물 나더라", "슬픈 만화 봤어", "영화에서 주인공이 울었어"}

# 평가용 일반 대화: '비슷하지만 상황이 아닌 말' (학습에 없는 것)
EVAL_GEN_NEAR = ["짝꿍이 선생님한테 혼났대", "동생이 시험 망쳤대", "형이 친구랑 싸웠대", "친구들끼리 다퉜대",
                 "누나가 상 받았대", "동생이 상 받았어", "형 생일이야", "엄마 생일 선물 샀어", "친구랑 눈싸움했어",
                 "동생이 울고 있어", "양파 때문에 눈물 나", "엄마 언제 와", "아빠 이거 봐 봐", "오늘 시험 봤어",
                 "학교 끝났어", "친구랑 놀이터에서 놀았어", "잠옷 입었어", "이제 잘게", "숙제 다 했어", "친구랑 화해했어"]


def fill(tpl, utt, slots):
    t = "오늘 " if "오늘" in utt else ""
    out = tpl.format(t=t, **slots).replace("  ", " ").strip()
    if len(out) > 25:  # 25자 넘으면 '오늘'을 빼 보고, 그래도 길면 이 틀은 안 씀
        out = tpl.format(t="", **slots).replace("  ", " ").strip()
    return out if len(out) <= 25 else "@@긺@@"


def strip_today(prefix, body):
    # 본문에 이미 '오늘'이 있으면 앞말 '오늘'은 쓰지 않는다
    return not ("오늘" in prefix and "오늘" in body)


def expand():
    items = defaultdict(list)  # sid -> [(utt, core_idx, body_idx, prefix)]
    for sid, cs in CORES.items():
        for ci, c in enumerate(cs):
            for bi, b in enumerate(c["bodies"]):
                for p in c["prefixes"]:
                    if not strip_today(p, b):
                        continue
                    if p.startswith("엄마 나") and b.startswith("엄마"):
                        continue
                    if p.startswith("아빠 나") and b.startswith("아빠"):
                        continue
                    if re.search(r"(^|\s)나(만|랑|\s|$)", b) and "나 " in p:
                        p2 = {"엄마 나 ": "엄마 ", "아빠 나 ": "아빠 "}.get(p)
                        if not p2:
                            continue
                        p = p2
                    if "내 " in b and p == "나 ":
                        continue
                    if sid == 12 and "내 " not in b and p in ("엄마 ", "아빠 ") and "생일이" in b:
                        continue  # '아빠 오늘 생일이야'는 아빠 생일로도 들림
                    items[sid].append(((p + b).strip(), ci, bi, p))
    return items


def out_text(sid, emp):
    return f"<maum_0>(situation={sid}, feeling={FEEL[sid]})<maum_sep>{emp}<maum_end>"


OTHER_TR, OTHER_EV = [], []

def build(v352, outdir):
    outdir.mkdir(parents=True, exist_ok=True)
    wb = openpyxl.load_workbook(v352, read_only=True)
    old_train = list(wb["Function_Data_싱글턴"].iter_rows(values_only=True))[1:]
    old_eval = list(wb["Eval_Set"].iter_rows(values_only=True))[1:]
    gen_all = [r[3] for r in old_train if "<maum_1>" in r[2] and r[3] not in GEN_DROP]
    # 일반 대화: '상황과 비슷하지만 아닌 말'은 모두, 나머지 일상 말은 40개만
    near = [g for g in gen_all if re.search(NEAR, g)]
    other = [g for g in gen_all if g not in near]
    random.Random(4).shuffle(other)
    gen_train = near + other[:40]
    gen_eval_old = [r[3] for r in old_eval if "<maum_1>" in r[2]]

    items = expand()
    train, evals = [], []
    TRAIN_PER, EVAL_PER = 160, 30
    for sid in sorted(items):
        rows = list(dict.fromkeys(items[sid]))
        seen = set()
        uniq = []
        for r in rows:
            if r[0] not in seen:
                seen.add(r[0]); uniq.append(r)
        random.shuffle(uniq)
        must = [r for r in uniq if r[0] in MUST]
        rest = [r for r in uniq if r[0] not in MUST]
        # 평가: 정한 말(core)마다 돌아가며 뽑기
        by_core = defaultdict(list)
        for r in rest:
            by_core[r[1]].append(r)
        ev = []
        while len(ev) < EVAL_PER and any(by_core.values()):
            for ci in sorted(by_core):
                if by_core[ci] and len(ev) < EVAL_PER:
                    ev.append(by_core[ci].pop())
        # 학습: 기본 말투(앞말 없음/나/오늘 + 첫 말끝)를 먼저, 그다음 core·말끝이 고르게
        left = [r for ci in sorted(by_core) for r in by_core[ci]]
        basic = [r for r in left if r[3] in ("", "나 ", "오늘 ") and CORES[sid][r[1]]["bodies"].index(r[0][len(r[3]):]) % 6 == 0]
        others = [r for r in left if r not in basic]
        random.shuffle(others)
        rr = defaultdict(list)
        for r in others:
            rr[r[1]].append(r)
        random.shuffle(basic)
        tr = must + [r for r in basic if r not in must][:TRAIN_PER // 3]
        for r in basic[TRAIN_PER // 3:]:
            rr[r[1]].append(r)
        while len(tr) < TRAIN_PER and any(rr.values()):
            for ci in sorted(rr):
                if rr[ci] and len(tr) < TRAIN_PER:
                    tr.append(rr[ci].pop())
        # 공감: 정한 틀을 돌려 쓰고, 같은 문장은 3번까지
        cnt = Counter()
        rot = Counter()
        for dest, lst in ((train, tr), (evals, ev)):
            local = cnt if dest is train else Counter()
            for utt, ci, bi, p in lst:
                c = CORES[sid][ci]
                tpls = c["emp"]
                emp = None
                for k in range(len(tpls)):
                    cand = fill(tpls[(rot[ci] + k) % len(tpls)], utt, c["slots"])
                    if cand != "@@긺@@" and local[cand] < 3:
                        emp = cand; break
                rot[ci] += 1
                if emp is None:
                    continue
                local[emp] += 1
                dest.append((sid, utt, emp))
    tr_set = {u for _, u, _ in train}
    evals = [e for e in evals if e[1] not in tr_set]
    gen_eval = [g for g in EVAL_GEN_NEAR if g not in gen_train] + [g for g in gen_eval_old[:20] if g not in gen_train]
    # 시연 4개가 아닌 8개 상황의 말은 이번 학습에서 '일반 대화'로 둔다 (엉뚱한 4개 상황으로 가지 않게)
    import build_v36 as v36
    oth = v36.expand()
    rnd = random.Random(37)
    used = tr_set | set(gen_train) | set(gen_eval)
    for sid in sorted(oth):
        if sid in DEMO:
            continue
        cand = list(dict.fromkeys(u for u, ci, bi, p in oth[sid] if p in ("", "나 ", "오늘 ", "온기야 ", "있잖아 ") and u not in used))
        rnd.shuffle(cand)
        OTHER_TR.extend(cand[:12]); OTHER_EV.extend(cand[12:15])
    gen_train = gen_train + OTHER_TR
    gen_eval = gen_eval + OTHER_EV
    return train, evals, gen_train, gen_eval


def save(train, evals, gen_train, gen_eval, outdir, ver="v3.7"):
    head = ["No", "기능명", "LLM Output", "Query(한글)"]

    def sheet(ws, sits, gens):
        ws.append(head)
        n = 1
        for sid, utt, emp in sits:
            ws.append([n, "상황 말하기", out_text(sid, emp), utt]); n += 1
        for g in gens:
            ws.append([n, "일반 대화", "<maum_1>()<maum_end>", g]); n += 1
        for c in ws[1]:
            c.font = Font(bold=True)
        ws.column_dimensions["C"].width = 70
        ws.column_dimensions["D"].width = 40

    # 제출용 2개
    sub = outdir / "제출용"
    sub.mkdir(exist_ok=True)
    w1 = openpyxl.Workbook(); sheet(w1.active, train, gen_train); w1.active.title = "Function_Data_싱글턴"
    w1.save(sub / f"00_온기_학습데이터_{ver}.xlsx")
    w2 = openpyxl.Workbook(); sheet(w2.active, evals, gen_eval); w2.active.title = "Eval_Set"
    w2.save(sub / f"00_온기_평가데이터_{ver}.xlsx")

    # 내부용 (확인 시트 포함)
    w = openpyxl.Workbook()
    ws = w.active; ws.title = "Function_Data_싱글턴"; sheet(ws, train, gen_train)
    ws = w.create_sheet("Eval_Set"); sheet(ws, evals, gen_eval)
    ws = w.create_sheet("정한 말")
    ws.append(["상황", "이름", "기분(고정)", "정한 말(본문 예)", "공감 틀"])
    for sid in sorted(CORES):
        for c in CORES[sid]:
            ws.append([sid, NAMES[sid], FEEL[sid], " / ".join(c["bodies"][:2]), " / ".join(c["emp"])])
    ws = w.create_sheet("설명")
    for line in __doc__.strip().splitlines():
        ws.append([line])
    w.save(outdir / f"00_온기_학습데이터_{ver}.xlsx")


if __name__ == "__main__":
    v352, outdir = Path(sys.argv[1]), Path(sys.argv[2])
    train, evals, gen_train, gen_eval = build(v352, outdir)
    save(train, evals, gen_train, gen_eval, outdir)
    print("학습 상황", len(train), "일반", len(gen_train), "/ 평가 상황", len(evals), "일반", len(gen_eval))
    print("상황별 학습", Counter(s for s, _, _ in train))
    print("상황별 평가", Counter(s for s, _, _ in evals))
