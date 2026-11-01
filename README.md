# 온기 (Ongi)

부모가 미리 남긴 목소리 메시지를, 아이가 말을 걸면 상황에 맞춰 들려주는 온디바이스 AI 기기.

모바일시스템응용프로젝트 7분반 5팀 **AI큐**

## 폴더 구조

| 폴더 | 내용 | 담당 | 개발 도구 |
|---|---|---|---|
| `app/` | 부모·자녀 앱 (Flutter) | 서유정 | VS Code / Android Studio |
| `server/` | 백엔드 API (FastAPI + MySQL) | 황정범 | VS Code |
| `device/` | 보드 안 디바이스 프로그램 (Kotlin, Android) | 공지현 | Android Studio |
| `ai/` | 학습 데이터, 보드 안 AI 서버, 도구 스크립트 | 박석준 | VS Code / Colab |
| `docs/` | 신호 규격서, API 문서, 개발 문서 | 전원 | - |

## 규칙

1. **자기 폴더만 수정한다.** `docs/`는 같이 쓴다. 남의 폴더를 고쳐야 하면 단톡에 먼저 말한다.
2. **브랜치는 파트별로 쓴다.** `app` / `server` / `device` / `ai`
3. 평소에는 자기 브랜치에 올린다(push).
4. **목요일 점검일에 Pull Request로 `main`에 합친다.**
5. `main`에는 직접 올리지 않는다.
6. 비밀번호, AWS 키, `.env` 파일은 올리지 않는다.

## 처음 받을 때

```bash
git clone https://github.com/hansung-aiq/ongi.git
cd ongi
git checkout -b app      # 자기 파트 이름으로 (app / server / device / ai)
```

## 매일 작업할 때

```bash
git pull origin main     # 다른 사람이 합친 것 받기
# ... 작업 ...
git add 내폴더/
git commit -m "무엇을 했는지 한 줄"
git push origin 내브랜치
```

## 주요 문서

- [신호 규격서 (앱 ↔ 디바이스)](docs/신호규격서.txt)
- 가짜 보드: `device/mock_board.py` (앱 개발용, 실행 방법은 신호 규격서 7장)
