"""[온기] v3.4 학습 데이터 만들기: v3.3 + 공감 정답 + 보강 문장
실행: cd ai/data && python3 build_v34.py   (pip3 install openpyxl)
고칠 곳: empathy_pools.py(공감 문장 묶음), additions.py(보강 문장)
"""
import openpyxl, re, collections, sys, json, os
HERE = os.path.dirname(os.path.abspath(__file__))
os.chdir(HERE)
sys.path.insert(0, HERE)
from empathy_pools import POOLS
from additions import GENERAL, FEELING_ONLY, FEELING_ONLY_EMPATHY
sys.path.insert(0, os.path.join(HERE, '..', 'tools'))
from check_empathy import load_rules, check

rules = load_rules(os.path.join(HERE, '..', 'tools', 'empathy_rules.json'))
MAX = 3

def parse(entry):
    if '|' in entry:
        cue, text = entry.rsplit('|', 1); return re.compile(cue.replace(' ', '')), text
    return None, entry

pools = {k: [parse(e) for e in v] for k, v in POOLS.items()}

def pick(sit, feel, query, used, limit=True):
    cands = pools.get((sit, feel))
    if not cands:
        raise SystemExit(f'묶음 없음 {(sit, feel)}')
    q = query.replace(' ', '')
    def ok(t): return (not limit) or used[(sit, feel, t)] < MAX
    # 형제 이야기에는 '친구'가 들어간 문장을 쓰지 않는다
    sibling = re.search('동생|형|누나|언니|오빠', q) and '친구' not in q
    def fit(t): return not (sibling and '친구' in t)
    cue_hit = [t for c, t in cands if c and c.search(q) and ok(t) and fit(t)]
    generic = [t for c, t in cands if c is None and ok(t) and fit(t)]
    pool = cue_hit or generic
    if not pool:   # 엉뚱한 단서 문장은 쓰지 않는다. 일반 문장을 3번 넘겨 쓰고 알린다
        pool = [t for c, t in cands if (c is None or c.search(q)) and fit(t)] or [t for c, t in cands if c is None]; print('  ! 3번 초과', sit, feel, query)
    t = min(pool, key=lambda x: used[(sit, feel, x)])
    used[(sit, feel, t)] += 1
    return t

def label(r):
    m = re.search(r'<maum_(\d)>\((.*?)\)<maum_end>', r)
    if m.group(1) == '1': return None
    a = m.group(2)
    return int(re.search(r'situation=(-?\d+)', a).group(1)), int(re.search(r'feeling=(-?\d+)', a).group(1))

def out(sit, feel, emp): return f'<maum_0>(situation={sit}, feeling={feel})<maum_sep>{emp}<maum_end>'
GEN = '<maum_1>()<maum_end>'

src = openpyxl.load_workbook('00_온기_학습데이터_v3.3.xlsx')
wb = openpyxl.Workbook(); wb.remove(wb.active)
review = []          # 검수용
problems = []

for sheet, limit in [('Function_Data_싱글턴', True), ('Eval_Set', False)]:
    rows = list(src[sheet].iter_rows(values_only=True))
    ws = wb.create_sheet(sheet); ws.append(list(rows[0]))
    used = collections.Counter(); n = 0
    data = []
    for r in rows[1:]:
        if r[3] is None: continue
        lab = label(r[2])
        if lab is None:
            data.append(('일반 대화', GEN, r[3], None, None, None))
        else:
            sit, feel = lab
            emp = pick(sit, feel, r[3], used, limit)
            data.append(('상황 말하기', out(sit, feel, emp), r[3], sit, feel, emp))
    if sheet == 'Function_Data_싱글턴':
        for q in GENERAL: data.append(('일반 대화', GEN, q, None, None, None))
        for f, qs in FEELING_ONLY.items():
            for q, e in zip(qs, FEELING_ONLY_EMPATHY[f]):
                data.append(('상황 말하기', out(-1, f, e), q, -1, f, e))
    for kind, o, q, sit, feel, emp in data:
        n += 1; ws.append([n, kind, o, q])
        review.append([sheet, n, sit if sit is not None else '일반', feel if feel is not None else '', q, emp or ''])
        if emp is not None:
            why = check(emp, feel, rules)
            if why: problems.append((sheet, n, sit, feel, emp, why))
    for col, w in zip('ABCD', (6, 12, 70, 40)): ws.column_dimensions[col].width = w
    if limit:
        over = [(k, v) for k, v in used.items() if v > MAX]
        print(sheet, '행', n, '/ 서로 다른 공감 문장', len(used), '/ 3번 초과', len(over))
    else:
        print(sheet, '행', n)

rv = wb.create_sheet('검수용')
rv.append(['시트', 'No', '상황', '기분', '아이 말', '공감 정답', '검수(O/X)', '고친 문장'])
for r in review: rv.append(r + ['', ''])
for col, w in zip('ABCDEFGH', (16, 6, 6, 6, 40, 34, 10, 30)): rv.column_dimensions[col].width = w
rv.freeze_panes = 'A2'
wb.save('00_온기_학습데이터_v3.4.xlsx')
print('규칙 위반', len(problems))
for p in problems[:30]: print(' ', p)
