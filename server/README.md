# 온기 서버 (SRV-10)

부모 앱과 자녀 방 보드 사이에서 메시지·녹음·재생 기록을 **저장하고 내려주는** 서버다. 판단은 하지 않는다.
Python + FastAPI + MySQL. API 14개.

- API 동작 설명: [API.md](API.md)
- 요청·응답 표: `docs/온기_API_규격서_v0.6.xlsx`

> 🔑 표시가 있는 단계는 비밀번호가 필요하다. 직접 실행하고, 비밀번호와 `.env` 내용은 다른 곳에 공유하지 않는다.

---

## 파일 구성

| 파일 | 내용 |
|---|---|
| `main.py` | API 14개 |
| `db.py` | MySQL 접속(`.env`를 읽음), 시각 형식 변환 |
| `errors.py` | 오류 응답을 `{"error":"E-xxx","message":...}` 모양으로 통일 |
| `schema.sql` | DB 테이블 4개 생성 + 상황 12개 입력 (SRV-03) |
| `seed.sql` | 시연 데이터: 가족 1개(민준) + 메시지 4개. 메시지 번호는 보드와 같다 |
| `requirements.txt` | 필요한 Python 패키지와 버전 |
| `.env.example` | 설정 파일 견본. 복사해서 `.env`를 만든다 |
| `API.md` | API 동작 설명 |
| `files/` | 올라온 녹음 파일 저장 폴더(자동 생성) |

git에 올리지 않는 것(`.gitignore`): `.env`(비밀번호), `.venv/`, `__pycache__/`, `files/`(녹음 파일). `.env.example`은 올린다.

---

## 설치 (Windows, 처음 한 번)

### 준비물
- **Python 3.13**
- **MySQL 8.0.16 이상**: CHECK 제약 때문에 이 버전 이상이어야 한다. 개발 PC는 MySQL 26.10을 썼다.
- 이 `server` 폴더. 넣을 위치는 예: `C:\dev\ongi\server`

### 1. Python 설치 확인
```powershell
python --version
```
`Python 3.13.x`가 안 나오면 설치한다.
```powershell
winget install --id Python.Python.3.13 -e --scope user
```
설치 후 터미널을 새로 연다.

### 2. 가상환경 만들고 패키지 설치
가상환경(`.venv`)은 이 프로젝트 전용 Python 패키지 상자다. 다른 프로젝트와 섞이지 않는다.
```powershell
cd C:\dev\ongi\server
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

### 3. DB 만들기 🔑 (사용자가 직접)
MySQL root로 접속한다. root 비밀번호를 물어본다.
```powershell
& "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -p
```
> 경로의 `8.0`은 설치된 버전 폴더 이름으로 바꾼다. 개발 PC에서는 `MySQL Server 26.10`이었다.

`mysql>` 화면에서 아래를 차례로 실행한다.
```sql
CREATE DATABASE IF NOT EXISTS ongi CHARACTER SET utf8mb4;
USE ongi;
SOURCE C:/dev/ongi/server/schema.sql;
SELECT COUNT(*) AS situation_count FROM situation;   -- 12가 나와야 한다
SOURCE C:/dev/ongi/server/seed.sql;                  -- 시연 데이터. 1 / 4가 나와야 한다

CREATE USER 'ongi_app'@'localhost' IDENTIFIED BY '여기에_새_비밀번호';
GRANT SELECT, INSERT, UPDATE, DELETE ON ongi.* TO 'ongi_app'@'localhost';
EXIT;
```
- `SOURCE` 경로는 `server` 폴더의 실제 위치로 바꾸고, 슬래시(`/`)로 쓴다.
- `ongi_app`은 서버 전용 계정이다. 데이터 읽기·쓰기만 할 수 있고, 테이블은 지울 수 없다.
- ⚠️ `schema.sql`은 맨 앞에서 테이블을 지우고 다시 만든다. **이미 데이터가 있는 DB에서 다시 실행하면 데이터가 모두 지워진다.**
- `seed.sql`은 `schema.sql` 바로 다음에 한 번만 실행한다. 두 번 실행하면 번호가 겹쳐 오류가 난다.
- 시연 메시지 1·2번은 녹음이다. 녹음 파일을 `server/files/`에 아래 이름으로 넣어 둔다. (`files/`가 없으면 만든다)
  - `00000000000000000000000000000001.m4a`: 1번, 친구와 싸운 날
  - `00000000000000000000000000000002.m4a`: 2번, 부모님이 보고 싶을 때

### 4. 설정 파일 `.env` 만들기 🔑 (사용자가 직접)
```powershell
Copy-Item .env.example .env
notepad .env
```
`DB_PASSWORD=`에 3단계에서 정한 `ongi_app` 비밀번호를 넣고 저장한다. 나머지 값은 그대로 둔다.

### 5. 서버 켜기
```powershell
.\.venv\Scripts\uvicorn.exe main:app --host 0.0.0.0 --port 8000 --reload
```
- `--host 0.0.0.0`: 같은 공유기에 있는 다른 기기(앱 폰, 보드)도 접속할 수 있게 한다.
- `--reload`: 코드를 고치면 자동으로 다시 켠다. 단, `.env`를 바꿨을 때는 직접 껐다 켜야 한다.

### 6. 확인
1. 이 PC의 브라우저에서 `http://localhost:8000/docs`를 연다.
2. `GET /situations` → Try it out → Execute → **200, 상황 12개**가 나오면 성공.
3. 첫 실행 때 Windows 방화벽 창이 뜨면 **개인 네트워크 허용**을 누른다.
4. 같은 공유기에 연결된 다른 기기(폰 등)에서 `http://<이 PC의 IP>:8000/docs`가 열리는지 확인한다.
   - 이 PC의 IP: `ipconfig` → Wi-Fi의 **IPv4 주소**. 앱과 보드는 이 주소로 접속한다.
   - 팀 공유기(ipTIME, 192.168.0.1)에서는 정범 노트북을 `192.168.0.20`으로 고정해 쓴다(석준님이 설정).

---

## 설치 (Mac, 처음 한 번)

코드는 Windows와 같다. 명령만 다르다. 아래는 저장소를 `~/ongi`에 받았다고 보고 쓴다.

### 준비물
- **Homebrew**: `brew --version`이 안 나오면 [brew.sh](https://brew.sh)의 설치 명령을 실행한다.
- **Python 3.13**, **MySQL 8.0.16 이상**: 아래 1·3단계에서 설치한다.

### 1. Python 설치 확인
```bash
python3 --version
```
`Python 3.13.x`보다 낮으면 설치한다. 설치한 Python은 `python3.13`으로 부른다.
```bash
brew install python@3.13
```

### 2. 가상환경 만들고 패키지 설치
```bash
cd ~/ongi/server
python3 -m venv .venv          # 1단계에서 새로 설치했다면 python3.13 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

### 3. MySQL 설치하고 DB 만들기 🔑 (사용자가 직접)
```bash
brew install mysql
brew services start mysql
```
`server` 폴더에서 root로 접속한다. 이 폴더에서 접속해야 아래 `SOURCE`에 파일 이름만 써도 된다.
```bash
cd ~/ongi/server
mysql -u root -p
```
- 막 설치한 MySQL은 root 비밀번호가 없다. 비밀번호를 물으면 Enter만 누른다.

`mysql>` 화면에서 아래를 차례로 실행한다.
```sql
CREATE DATABASE IF NOT EXISTS ongi CHARACTER SET utf8mb4;
USE ongi;
SOURCE schema.sql;
SELECT COUNT(*) AS situation_count FROM situation;   -- 12가 나와야 한다
SOURCE seed.sql;                                     -- 시연 데이터. 1 / 4가 나와야 한다

CREATE USER 'ongi_app'@'localhost' IDENTIFIED BY '여기에_새_비밀번호';
GRANT SELECT, INSERT, UPDATE, DELETE ON ongi.* TO 'ongi_app'@'localhost';
EXIT;
```
- ⚠️ `schema.sql`은 테이블을 지우고 다시 만든다. 데이터가 있는 DB에서 다시 실행하면 모두 지워진다.
- `seed.sql`은 `schema.sql` 바로 다음에 한 번만 실행한다.

시연 녹음 파일 두 개를 `files/` 폴더에 넣는다.
```bash
mkdir -p files
cp <받은_1번_녹음>.m4a files/00000000000000000000000000000001.m4a
cp <받은_2번_녹음>.m4a files/00000000000000000000000000000002.m4a
```

### 4. 설정 파일 `.env` 만들기 🔑 (사용자가 직접)
```bash
cp .env.example .env
open -e .env
```
`DB_PASSWORD=`에 3단계에서 정한 `ongi_app` 비밀번호를 넣고 저장한다. 나머지 값은 그대로 둔다.

### 5. 서버 켜기
```bash
.venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```
- 첫 실행 때 "들어오는 네트워크 연결을 허용할까요?" 창이 뜨면 **허용**을 누른다.

### 6. 확인
1. 브라우저에서 `http://localhost:8000/docs` → `GET /situations` → Try it out → Execute → **200, 상황 12개**
2. 이 Mac의 IP: `ipconfig getifaddr en0`. 다른 기기(보드, 폰)는 `http://<이 IP>:8000`으로 접속한다.

---

## 설정 바꾸는 곳

| 바꾸고 싶은 것 | 위치 | 지금 값 |
|---|---|---|
| DB 주소·포트·이름·계정·비밀번호 | `.env` `DB_HOST` `DB_PORT` `DB_NAME` `DB_USER` `DB_PASSWORD` | 127.0.0.1 / 3306 / ongi / ongi_app |
| 시각의 시간대 | `.env` `DB_TIME_ZONE` | `+09:00` (한국 시각) |
| 서버 포트 | 실행 명령의 `--port` | 8000 |
| 녹음 최대 크기 | `main.py` `MAX_AUDIO_BYTES` | 10,000,000 (10MB) |
| 받는 녹음 형식 | `main.py` `AUDIO_TYPES` | m4a만 (`audio/mp4`) |
| 진행률 목표 개수 | `main.py` `PROGRESS_TOTAL` | 10 |
| 녹음 저장 폴더 | `main.py` `FILES_DIR` | `server/files/` |

`.env`를 바꾸면 서버를 껐다 켠다. `main.py`는 `--reload`가 켜져 있으면 저장하는 즉시 반영된다.

---

## 문제가 생기면

| 증상 | 원인·해결 |
|---|---|
| `/situations`가 500, 서버 창에 `Access denied for user 'ongi_app'` | `.env`의 `DB_PASSWORD`가 3단계 비밀번호와 다름. 🔑 `ALTER USER 'ongi_app'@'localhost' IDENTIFIED BY '새_비밀번호';` 실행 후 `.env`를 같은 값으로 고치고 서버를 다시 켠다 |
| `Can't connect to MySQL server` | MySQL이 꺼져 있음. Windows는 `서비스`에서 MySQL을 시작하고, Mac은 `brew services start mysql` |
| 다른 기기에서 접속 안 됨 | `--host 0.0.0.0`으로 켰는지, 방화벽에서 Python이 허용됐는지, 같은 공유기인지 확인한다 |
| `python`을 찾을 수 없음 / Microsoft Store가 열림 | Python 미설치. 1단계 |
| 서버 창에 `cryptography package is required` | MySQL 접속 방식 때문에 패키지가 하나 더 필요함. `.venv/bin/pip install cryptography` (Windows는 `.\.venv\Scripts\python.exe -m pip install cryptography`) 후 서버를 다시 켠다 |
| Mac에서 `mysql: command not found` | 터미널을 새로 열거나 `brew link mysql`을 실행한다 |
| 시각이 9시간 어긋나 보임 | 응답 헤더 `date`는 원래 GMT다. 응답 본문의 시각은 `DB_TIME_ZONE` 기준이다 |
