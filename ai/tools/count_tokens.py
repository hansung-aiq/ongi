"""
온기 LLM 토큰 예산 확인 (보드 Genie context 128 토큰).

  프롬프트 = 앞붙임(<|im_start|>) + 마음AI 템플릿 + 아이 말 + " Response:"
  출력     = <maum_0>(situation=n, feeling=m)<maum_sep>공감<maum_end>
  합계가 128을 넘으면 출력이 잘린다.

토크나이저: 보드의 /data/local/tmp/tokenizer.json (예제 Llama 3.2 1B, 새 토큰 없음).
  <maum_*> 4개는 우리 학습 모델에서 새 토큰(각 1개)이 되므로, 여기서는 1토큰으로 계산한다.

실행:
  adb pull /data/local/tmp/tokenizer.json ~/ongi/_local/
  python3 ai/tools/count_tokens.py _local/tokenizer.json ai/data/제출용/00_온기_학습데이터_v3.5.2.xlsx
"""
import re
import sys

import openpyxl
from tokenizers import Tokenizer

CTX = 128
PREFIX = "<|im_start|>"
HEAD = ("Below is the query from the users, please choose the correct function "
        "and generate the parameters to call the function. Query: ")
TAIL = " Response:"
SPECIAL = re.compile(r"<maum_(?:\d|sep|end)>")


def count(tok, text):
    """<maum_*>는 1토큰씩, 나머지는 토크나이저로"""
    n = len(SPECIAL.findall(text))
    for part in SPECIAL.split(text):
        if part:
            n += len(tok.encode(part, add_special_tokens=False).ids)
    return n


def main(tok_path, xlsx):
    tok = Tokenizer.from_file(tok_path)
    fixed = count(tok, PREFIX + HEAD) + count(tok, TAIL) + 1  # +1 = bos
    ws = openpyxl.load_workbook(xlsx, read_only=True).worksheets[0]
    rows = []
    for r in list(ws.iter_rows(values_only=True))[1:]:
        out, q = str(r[2] or ""), str(r[3] or "")
        if not q:
            continue
        qn, on = count(tok, q), count(tok, out)
        rows.append((fixed + qn + on, qn, on, len(q), q, out))

    rows.sort(reverse=True)
    tot = [r[0] for r in rows]
    print(f"고정 부분(앞붙임+템플릿+bos): {fixed} 토큰")
    print(f"문장 {len(rows)}개 | 합계 평균 {sum(tot)/len(tot):.1f} / 최대 {max(tot)} / context {CTX}")
    print(f"아이 말: 평균 {sum(r[1] for r in rows)/len(rows):.1f} 토큰, 글자당 {sum(r[1] for r in rows)/sum(r[3] for r in rows):.2f}")
    print(f"출력  : 평균 {sum(r[2] for r in rows)/len(rows):.1f} / 최대 {max(r[2] for r in rows)}")
    over = [r for r in rows if r[0] > CTX]
    print(f"128 넘는 문장: {len(over)}개")
    room = CTX - fixed - max(r[2] for r in rows)
    print(f"→ 출력 최대 길이를 남기면 아이 말은 {room} 토큰(약 {room / (sum(r[1] for r in rows)/sum(r[3] for r in rows)):.0f}자)까지 안전")
    print("\n가장 긴 5개:")
    for r in rows[:5]:
        print(f"  {r[0]:3d} (말 {r[1]}, 출력 {r[2]}) {r[4]}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
