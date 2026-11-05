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


# 1 학교 가기 싫은 날 (기분 4)
for i in ["", "너무 ", "진짜 "]:
    core(1, forms(f"학교 가기 {i}싫"), ["{t}학교 가기 싫은 날이구나", "{t}학교에 가고 싶지 않구나", "{t}학교 가는 게 싫구나", "학교 가기 많이 싫구나", "{t}학교 가는 게 힘든 날이구나", "학교 가기 싫을 만큼 지쳤구나"])
core(1, forms("학교 안 가고 싶"), ["{t}학교에 안 가고 싶구나", "{t}학교 가기 싫은 날이구나", "학교에 가고 싶지 않구나", "{t}학교 쉬고 싶은 마음이구나", "학교 가기 많이 싫구나"])
core(1, forms("학교 쉬고 싶"), ["{t}학교를 쉬고 싶구나", "하루 쉬고 싶은 마음이구나", "{t}학교 쉬고 싶은 날이구나", "{t}좀 쉬고 싶구나", "학교 가기 지친 날이구나"])

# 2 혼났을 때 (기분 1)
for w in ["", "엄마한테 ", "아빠한테 ", "선생님한테 "]:
    pre = P_ALL if not w or "선생님" in w else [p for p in P_ALL if "엄마" not in p and "아빠" not in p]
    for i in ["", "엄청 "]:
        core(2, forms(f"{w}{i}혼났"), ["{t}{w}혼났구나", "{t}{w}혼이 났구나", "혼나서 속상했구나", "{t}혼난 날이구나"], pre, w=w)
    core(2, forms(f"{w}야단맞았"), ["{t}{w}야단을 맞았구나", "야단맞아서 속상했구나", "{t}혼난 날이구나"], pre, w=w)
    core(2, forms(f"{w}꾸중 들었"), ["{t}{w}꾸중을 들었구나", "꾸중 들어서 속상했구나", "{t}꾸중 들은 날이구나"], pre, w=w)

# 3 시험을 망친 날 (기분 1)
for w, o in [("시험 ", "시험을 "), ("수학 시험 ", "수학 시험을 "), ("받아쓰기 ", "받아쓰기를 ")]:
    core(3, forms(f"{w}망쳤") + forms(f"{w}망했"), ["{t}{o}망쳤구나", "{t}{o}망친 날이구나", "{o}망쳐서 속상했구나"], o=o)
core(3, forms("시험 못 봤") + forms("수학 시험 못 봤"), ["{t}시험을 잘 못 봤구나", "시험을 못 봐서 속상했구나", "{t}시험이 잘 안 됐구나"])
core(3, forms("시험 점수 낮게 나왔"), ["{t}시험 점수가 낮게 나왔구나", "점수가 낮아서 속상했구나", "{t}점수가 생각보다 낮았구나"])

# 4 친구와 싸운 날 (기분 1)
for w in ["친구랑 ", "짝꿍이랑 ", "친구들이랑 "]:
    for i in ["", "크게 "]:
        core(4, forms(f"{w}{i}싸웠"), ["{t}{w}싸웠구나", "{t}{w}싸운 날이구나", "{w}싸워서 속상했구나", "{t}{w}다퉜구나"], w=w)
        core(4, forms(f"{w}{i}다퉜"), ["{t}{w}다퉜구나", "{w}다퉈서 속상했구나", "{t}{w}다툰 날이구나"], w=w)
    core(4, forms(f"{w}싸움 났"), ["{t}{w}싸움이 났구나", "{w}싸워서 속상했구나", "{t}{w}싸운 날이구나"], w=w)
    core(4, forms(f"{w}말다툼했"), ["{t}{w}말다툼을 했구나", "{w}다퉈서 속상했구나", "{t}{w}다툰 날이구나"], w=w)

# 5 친구가 날 싫어하는 것 같을 때 (기분 1)
for s, s2 in [("애들이 ", "애들이 "), ("반 애들이 ", "반 애들이 "), ("친구들이 ", "친구들이 ")]:
    core(5, F(f"{s}나만 빼고 놀아", f"{s}나만 빼고 놀아요", f"{s}나만 빼고 놀거든", f"{s}나만 빼고 놀잖아", f"{s}나만 빼고 논단 말이야"),
         ["{t}{s2}너만 빼고 노는구나", "너만 빼고 놀아서 속상했구나", "{t}혼자 남은 것 같았구나"], s2=s2)
    core(5, forms(f"{s}나만 빼고 놀았"), ["{t}{s2}너만 빼고 놀았구나", "너만 빼고 놀아서 속상했구나", "{t}혼자 남은 것 같았구나"], s2=s2)
    core(5, F(f"{s}나랑 안 놀아 줘", f"{s}나랑 안 놀아 줘요", f"{s}나랑 안 놀아 주거든", f"{s}나랑 안 놀아 주잖아", f"{s}나랑 안 놀아 준단 말이야"),
         ["{t}{s2}같이 안 놀아 주는구나", "같이 놀 친구가 없어서 속상하구나", "{t}{s2}너랑 안 놀아 주는구나"], s2=s2)
    core(5, F(f"{s}나 따돌려", f"{s}나 따돌려요", f"{s}나 따돌리거든", f"{s}나 따돌리잖아", f"{s}나 따돌린단 말이야"),
         ["{t}{s2}너를 따돌리는구나", "따돌림 때문에 많이 속상하구나", "{t}{s2}너를 혼자 두는구나"], s2=s2)
for s, s2 in [("친구가 ", "친구가 "), ("애들이 ", "애들이 ")]:
    core(5, forms(f"{s}나 싫어하는 것 같", EA),
         ["{s2}너를 싫어하는 것 같구나", "그렇게 느껴져서 속상하구나", "{t}친구 때문에 마음이 아프구나"], s2=s2)

# 6 남들과 비교될 때 (기분 1)
for s in ["엄마가 ", "아빠가 "]:
    pre = [p for p in P_ALL if "엄마" not in p and "아빠" not in p]
    for o in ["동생이랑 ", "형이랑 ", "친구랑 "]:
        core(6, F(f"{s}자꾸 나랑 {o}비교해", f"{s}자꾸 나랑 {o}비교해요", f"{s}자꾸 나랑 {o}비교하거든", f"{s}자꾸 나랑 {o}비교하잖아", f"{s}자꾸 나랑 {o}비교한단 말이야"),
             ["{t}{o}자꾸 비교돼서 속상하구나", "비교당해서 속상하구나", "{t}{o}비교되는 게 싫구나"], pre, o=o)
for i in ["", "또 ", "친구랑 "]:
    core(6, forms(f"{i}비교당했"), ["{t}비교를 당했구나", "비교당해서 속상했구나", "{t}비교돼서 마음이 아팠구나"])
core(6, F("나만 못해", "나만 못해요", "나만 못하거든", "나만 못하잖아", "나만 못한단 말이야"),
     ["{t}너만 못하는 것 같구나", "너만 못하는 것 같아서 속상하구나", "{t}다른 애들이 더 잘하는 것 같구나"])
core(6, F("친구가 너무 부러워", "친구가 너무 부러워요", "친구가 너무 부럽거든", "친구가 너무 부럽잖아", "친구가 너무 부럽단 말이야"),
     ["{t}친구가 많이 부럽구나", "친구가 부러워서 속상하구나", "{t}부러운 마음이 드는구나"])

# 7 울고 싶은 날 (기분 1)
core(7, forms("울고 싶") + forms("진짜 울고 싶"), ["{t}울고 싶은 날이구나", "울고 싶을 만큼 슬프구나", "{t}마음이 많이 슬프구나", "{t}많이 속상한 날이구나", "울고 싶을 만큼 속상하구나"])
core(7, forms("울 것 같", EA) + forms("진짜 울 것 같", EA), ["{t}울 것 같구나", "울 것 같을 만큼 속상하구나", "{t}마음이 많이 슬프구나", "{t}눈물이 날 것 같구나", "{t}많이 속상한 날이구나"])
core(7, forms("울었") + forms("많이 울었"), ["{t}많이 울었구나", "울 만큼 속상했구나", "{t}울고 싶을 만큼 슬펐구나", "{t}눈물이 났구나", "{t}많이 슬픈 날이었구나"])
core(7, F("눈물 나", "눈물 나요", "눈물 나거든", "눈물 나잖아", "눈물 난단 말이야", "자꾸 눈물이 나", "자꾸 눈물이 나요", "자꾸 눈물이 나거든", "자꾸 눈물이 난단 말이야"),
     ["{t}눈물이 나는구나", "눈물이 날 만큼 슬프구나", "{t}마음이 많이 슬프구나", "{t}눈물이 날 만큼 속상하구나", "{t}많이 슬픈 날이구나"])

# 8 아무것도 하기 싫은 날 (기분 4)
core(8, forms("아무것도 하기 싫") + forms("진짜 아무것도 하기 싫"), ["{t}아무것도 하기 싫구나", "{t}많이 지친 날이구나", "많이 지쳤나 보구나", "{t}쉬고 싶은 날이구나", "{t}힘이 하나도 없구나"])
core(8, forms("아무것도 안 하고 싶"), ["{t}아무것도 안 하고 싶구나", "{t}쉬고 싶은 날이구나", "많이 지쳤나 보구나", "{t}많이 지친 날이구나", "{t}힘이 하나도 없구나"])
core(8, forms("다 귀찮", EA) + forms("진짜 다 귀찮", EA), ["{t}다 귀찮은 날이구나", "다 귀찮을 만큼 지쳤구나", "{t}많이 지친 날이구나", "{t}쉬고 싶은 날이구나", "많이 지쳤나 보구나"])
core(8, forms("기운이 없") + forms("기운이 하나도 없"), ["{t}기운이 없구나", "{t}많이 지친 날이구나", "기운이 없을 만큼 지쳤구나", "{t}힘이 하나도 없구나", "{t}쉬고 싶은 날이구나"])

# 9 잠이 안 오는 밤 (기분 3)
P9 = ["", "나 ", "오늘 ", "온기야 ", "엄마 나 ", "아빠 나 ", "있잖아 ", "지금 "]
core(9, F("잠이 안 와", "잠이 안 와요", "잠이 안 오거든", "잠이 안 오잖아", "잠이 안 온단 말이야",
          "잠이 하나도 안 와", "잠이 하나도 안 오거든", "잠이 하나도 안 온단 말이야"),
     ["{t}잠이 잘 안 오는구나", "잠이 안 와서 걱정되는구나", "{t}잠들기가 어렵구나", "{t}쉽게 잠들지 못하는구나", "잠이 안 오는 밤이구나", "{t}뒤척이는 밤이구나"], P9)
core(9, forms("못 자겠") + forms("진짜 못 자겠"), ["{t}잠들기가 어렵구나", "{t}잠이 잘 안 오는구나", "잠이 안 와서 걱정되는구나", "{t}쉽게 잠들지 못하는구나", "잠이 안 오는 밤이구나", "{t}뒤척이는 밤이구나"], P9)
core(9, forms("무서운 꿈 꿔서 못 자겠") + forms("무서운 꿈 꿨"), ["무서운 꿈 때문에 못 자는구나", "꿈이 무서워서 잠이 안 오는구나", "{t}무서운 꿈을 꿨구나", "꿈 때문에 무서웠구나", "{t}무서운 꿈에 놀랐구나"], P9)

# 10 부모님이 보고 싶을 때 (기분 5) — 부모 호칭은 아이가 말했으니 공감에 써도 됨
P10 = ["", "나 ", "오늘 ", "온기야 ", "있잖아 ", "지금 ", "갑자기 "]
for w, n in [("엄마 ", "엄마가 "), ("아빠 ", "아빠가 "), ("엄마 아빠 ", "엄마 아빠가 ")]:
    for i in ["", "너무 ", "진짜 "]:
        core(10, forms(f"{w}{i}보고 싶"), ["{t}{n}많이 보고 싶구나", "{t}{n}보고 싶은 날이구나", "{t}{n}많이 그립구나"], P10, n=n)
    core(10, forms(f"{w}목소리 듣고 싶"), ["{t}{w}목소리가 듣고 싶구나", "{t}{n}많이 그립구나", "{t}{n}보고 싶은 날이구나"], P10, w=w, n=n)
    core(10, F(f"{w}그리워", f"{w}그리워요", f"{w}그립거든", f"{w}그립잖아", f"{w}그립단 말이야"),
         ["{t}{n}많이 그립구나", "{t}{n}많이 보고 싶구나", "그리운 마음이 크구나"], P10, n=n)

# 11 자랑하고 싶은 날 (기분 6)
for w in ["", "학교에서 "]:
    core(11, forms(f"{w}상 받았"), ["{t}{w}상을 받았구나", "상 받아서 정말 기쁘구나", "{t}상을 받은 날이구나", "{t}뿌듯한 날이구나"], w=w)
core(11, forms("칭찬받았") + forms("선생님한테 칭찬받았"), ["{t}칭찬을 받았구나", "칭찬받아서 뿌듯하구나", "{t}기분 좋은 날이구나"])
core(11, forms("백 점 맞았") + forms("시험 백 점 맞았"), ["{t}백 점을 맞았구나", "백 점이라니 정말 뿌듯하구나", "{t}기분 좋은 날이구나"])
core(11, forms("일등 했") + forms("달리기 일등 했"), ["{t}일등을 했구나", "일등이라니 정말 기쁘구나", "{t}뿌듯한 날이구나"])

# 12 생일 (기분 6)
core(12, F("오늘 내 생일이야", "오늘 내 생일이에요", "오늘 내 생일이거든", "오늘 내 생일이잖아", "오늘 내 생일이란 말이야", "오늘 생일이야", "오늘 생일이거든"),
     ["오늘이 네 생일이구나", "생일 정말 축하해", "생일이라 기쁜 날이구나", "생일을 정말 축하해", "오늘은 특별한 날이구나", "오늘 생일이구나"], P_NOTODAY)
core(12, F("내일 내 생일이야", "내일 내 생일이에요", "내일 내 생일이거든", "내일 내 생일이잖아", "내일 내 생일이란 말이야"),
     ["곧 생일이 다가오는구나", "내일이 네 생일이구나", "생일이 다가와서 기쁘구나", "생일이 기다려지는구나", "곧 생일이구나"], P_NOTODAY)
core(12, forms("생일 선물 받았"), ["{t}생일 선물을 받았구나", "생일 선물 받아서 기쁘구나", "생일 정말 축하해"])
core(12, forms("생일 파티 했"), ["{t}생일 파티를 했구나", "생일 파티가 즐거웠구나", "생일 정말 축하해"])

# 시연 문장: 반드시 학습에 넣는다
MUST = {"오늘 친구랑 싸웠어", "친구랑 싸웠어", "나 오늘 상 받았어", "상 받았어", "엄마 보고 싶어", "아빠 보고 싶어",
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
    return tpl.format(t=t, **slots).replace("  ", " ").strip()


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
    TRAIN_PER, EVAL_PER = 60, 10
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
        tr = must + [r for r in basic if r not in must]
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
                    if local[cand] < 3:
                        emp = cand; break
                rot[ci] += 1
                if emp is None:
                    continue
                local[emp] += 1
                dest.append((sid, utt, emp))
    tr_set = {u for _, u, _ in train}
    evals = [e for e in evals if e[1] not in tr_set]
    gen_eval = [g for g in EVAL_GEN_NEAR if g not in gen_train] + [g for g in gen_eval_old[:20] if g not in gen_train]
    return train, evals, gen_train, gen_eval


def save(train, evals, gen_train, gen_eval, outdir, ver="v3.6"):
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
