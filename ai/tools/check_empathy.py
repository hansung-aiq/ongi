"""
[온기] 공감 한마디 규칙 검사 (DEV-14)

공통지침 4-9 / 설계변경 v1.1 3장 규칙으로 공감 문장을 검사한다.
- 학습 데이터(v3.4)의 공감 문장 정답 검사에 쓴다.
- 같은 규칙을 보드 respond 모듈(Kotlin)에 옮겨 생성 공감 검사에 쓴다.

규칙
  1. 한 문장, 공백 포함 25자 이내
  2. 한글·공백만 (끝 물음표 하나 허용)
  3. 반말 (존댓말 끝맺음 금지)
  4. 조언·지시 / 약속 / 부모 호칭 금지
  5. 기분 -1이면 감정 단어 금지
  6. 같은 상황·같은 기분 안에서 같은 문장은 3번까지

목록은 같은 폴더의 empathy_rules.json에서 읽는다(석준님이 고치면 바로 반영).

실행
  문장 하나:  python check_empathy.py --text "친구랑 무슨 일이 있었구나" --feeling -1
  파일 전체:  python check_empathy.py 데이터.xlsx          (csv도 됨, xlsx는 pip install openpyxl)
              python check_empathy.py 데이터.xlsx --sheet 학습 --text-col 공감 --feeling-col 기분 --situation-col 상황
  결과:       화면에 요약, 같은 폴더에 <파일이름>_검사결과.csv (어긴 문장만)
"""

import argparse
import csv
import json
import re
import sys
from collections import Counter
from pathlib import Path

RULES_PATH = Path(__file__).with_name("empathy_rules.json")
ALLOWED = re.compile(r"^[가-힣 ]+\??$")

# 열 이름을 따로 안 주면 이 이름들 중 먼저 보이는 것을 쓴다
TEXT_COLS = ["공감", "공감 문장", "공감문장", "empathy", "공감 한마디"]
FEELING_COLS = ["기분", "feeling", "감정"]
SITUATION_COLS = ["상황", "situation", "상황 번호", "situation_id"]


def load_rules(path=RULES_PATH):
    with open(path, encoding="utf-8") as f:
        r = json.load(f)
    for key in ("honorific", "advice", "promise", "parent", "emotion"):
        r[key] = [re.compile(p) for p in r[key]]
    return r


def _hit(patterns, text):
    """패턴에 걸린 부분을 돌려준다. 띄어쓰기를 지운 글에도 한 번 더 본다."""
    nospace = text.replace(" ", "")
    for p in patterns:
        m = p.search(text) or p.search(nospace)
        if m:
            return m.group(0).strip()
    return None


def check(text, feeling, rules):
    """어긴 규칙 목록을 돌려준다. 빈 목록이면 통과."""
    reasons = []
    t = (text or "").strip()
    if not t:
        return ["빈 문장"]
    if len(t) > rules["max_length"]:
        reasons.append(f"길이 {len(t)}자(최대 {rules['max_length']})")
    if not ALLOWED.match(t):
        bad = sorted(set(ch for ch in t if not re.match(r"[가-힣 ]", ch)))
        reasons.append("허용 안 되는 문자 " + " ".join(repr(c) for c in bad))
    for key, name in (("honorific", "존댓말"), ("advice", "조언·지시"),
                      ("promise", "약속"), ("parent", "부모 호칭")):
        w = _hit(rules[key], t)
        if w:
            reasons.append(f"{name}({w})")
    if str(feeling).strip() in ("-1", "-1.0"):
        w = _hit(rules["emotion"], t)
        if w:
            reasons.append(f"기분 -1인데 감정 단어({w})")
    return reasons


CATEGORIES = ["빈 문장", "길이", "허용 안 되는 문자", "존댓말", "조언·지시", "약속",
              "부모 호칭", "기분 -1인데 감정 단어", "같은 문장"]


def _category(reason):
    for c in CATEGORIES:
        if reason.startswith(c):
            return c
    return reason


def _pick(header, wanted, given):
    if given:
        if given not in header:
            sys.exit(f"열 '{given}'이 없습니다. 있는 열: {header}")
        return given
    for name in wanted:
        if name in header:
            return name
    return None


def read_rows(path, sheet):
    p = Path(path)
    if p.suffix.lower() == ".csv":
        with open(p, encoding="utf-8-sig", newline="") as f:
            rows = list(csv.reader(f))
    else:
        try:
            import openpyxl
        except ImportError:
            sys.exit("xlsx를 읽으려면 먼저: pip install openpyxl")
        wb = openpyxl.load_workbook(p, read_only=True, data_only=True)
        ws = wb[sheet] if sheet else wb.worksheets[0]
        rows = [["" if v is None else str(v) for v in r] for r in ws.iter_rows(values_only=True)]
    header = [h.strip() for h in rows[0]]
    return header, rows[1:]


def check_file(args, rules):
    header, rows = read_rows(args.file, args.sheet)
    tcol = _pick(header, TEXT_COLS, args.text_col)
    fcol = _pick(header, FEELING_COLS, args.feeling_col)
    scol = _pick(header, SITUATION_COLS, args.situation_col)
    if not tcol:
        sys.exit(f"공감 문장 열을 못 찾았습니다. --text-col로 알려 주세요. 있는 열: {header}")
    ti, fi = header.index(tcol), (header.index(fcol) if fcol else None)
    si = header.index(scol) if scol else None
    print(f"열: 공감={tcol} / 기분={fcol or '(없음, 감정 단어 검사 안 함)'} / 상황={scol or '(없음, 중복 검사는 기분만으로)'}")

    seen = Counter()
    bad, total = [], 0
    reason_count = Counter()
    for n, r in enumerate(rows, start=2):           # 엑셀 줄 번호(머리글이 1)
        text = r[ti].strip() if ti < len(r) else ""
        if not text:
            continue                                # 일반 대화 등 문장 없는 줄은 건너뜀
        total += 1
        feeling = r[fi] if fi is not None and fi < len(r) else ""
        situation = r[si] if si is not None and si < len(r) else ""
        reasons = check(text, feeling, rules)
        key = (situation, feeling, text)
        seen[key] += 1
        if seen[key] > rules["max_same_sentence"]:
            reasons.append(f"같은 문장 {seen[key]}번째(최대 {rules['max_same_sentence']})")
        if reasons:
            bad.append([n, situation, feeling, text, " / ".join(reasons)])
            for x in reasons:
                reason_count[_category(x)] += 1

    ok = total - len(bad)
    rate = ok / total * 100 if total else 0
    print(f"\n검사 {total}문장 / 통과 {ok} / 위반 {len(bad)} / 통과율 {rate:.1f}%")
    for k, v in reason_count.most_common():
        print(f"  {k}: {v}")
    if bad:
        out = Path(args.file).with_name(Path(args.file).stem + "_검사결과.csv")
        with open(out, "w", encoding="utf-8-sig", newline="") as f:
            w = csv.writer(f)
            w.writerow(["줄", "상황", "기분", "공감 문장", "어긴 규칙"])
            w.writerows(bad)
        print(f"\n위반 목록: {out}")


def main():
    ap = argparse.ArgumentParser(description="온기 공감 한마디 규칙 검사")
    ap.add_argument("file", nargs="?", help="검사할 xlsx 또는 csv")
    ap.add_argument("--text", help="문장 하나만 검사")
    ap.add_argument("--feeling", default="", help="--text와 함께: 기분 번호(-1이면 감정 단어 검사)")
    ap.add_argument("--sheet", help="xlsx 시트 이름(기본: 첫 시트)")
    ap.add_argument("--text-col")
    ap.add_argument("--feeling-col")
    ap.add_argument("--situation-col")
    ap.add_argument("--rules", default=str(RULES_PATH), help="목록 파일 경로")
    args = ap.parse_args()
    rules = load_rules(args.rules)

    if args.text is not None:
        reasons = check(args.text, args.feeling, rules)
        print("통과" if not reasons else "위반: " + " / ".join(reasons))
        sys.exit(0 if not reasons else 1)
    if not args.file:
        ap.print_help()
        sys.exit(1)
    check_file(args, rules)


if __name__ == "__main__":
    main()
