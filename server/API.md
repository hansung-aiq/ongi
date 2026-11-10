# 온기 서버 API 동작

- 서버 주소: `http://192.168.0.20:8000`
- 시험 화면: `http://192.168.0.20:8000/docs`
- 인증 없음, 가족 1개.

---

## 1. 공통 규칙

### 1-1. 응답 모양
- 모든 요청·응답은 JSON(UTF-8), 키는 `snake_case`.
  - 예외 두 가지: API-05는 파일을 올리고(multipart/form-data), API-12는 성공하면 녹음 파일 자체가 온다.
- 앱용 목록 응답은 `{"items": [...]}`로 감싼다(API-02·03·09). 보드용 API-11은 `{"server_time", "messages"}` 모양이다.
- `author`는 `mom`/`dad`, `kind`는 `voice`/`text`.
- 앱용 메시지 API(03·04·06·07)는 메시지 칸을 모두 같은 모양으로 준다.
  ```json
  {"id": 1, "family_id": 1, "situation_id": 4, "author": "mom", "kind": "voice",
   "text": null, "audio_path": "3f2a9c1e5b7d4e8fa0c2b4d6e8f01234.m4a", "delivered": false,
   "created_at": "2026-11-02T21:40:07", "updated_at": "2026-11-02T21:40:07", "deleted": false}
  ```

### 1-2. 오류
오류는 항상 아래 모양이다. `message`는 사람이 읽는 설명이고, 코드에서 비교할 때는 `error`를 쓴다.
```json
{"error": "E-404", "message": "메시지를 찾을 수 없어요"}
```

| HTTP | error | 뜻 |
|---|---|---|
| 400 | E-400 | 요청 값이 틀림(형식, 빠진 값, 보낼 수 없는 칸 등) |
| 404 | E-404 | 가족·상황·메시지·파일이 없음, 또는 없는 주소 |
| 409 | E-409 | 중복(가족, 같은 상황의 메시지) |
| 413 | E-413 | 녹음 파일이 10MB를 넘음 |
| 500 | E-500 | 서버 오류 |

- 허용되지 않는 요청 방식(예: `PUT /messages/1`)은 E-400이다.

### 1-3. 시각
- 모든 시각은 `YYYY-MM-DDTHH:mm:ss` 모양(초까지)이고, 시간대 표기가 없다. 값은 한국 시각(+09:00)이다.
- 시각을 보낼 때(API-11의 `since`, API-14의 `played_at`)도 같은 모양으로 보낸다. 예: `2026-11-02T20:00:00`
  - 이 모양과 다르면 E-400이다. 시간대(`+09:00`, `Z`)나 소수초가 붙거나, 날짜만 보내도 E-400이다.
- HTTP 응답 헤더의 `date`는 HTTP 표준상 항상 GMT다. 응답 본문의 시각과는 관계없다.

### 1-4. updated_at과 delivered
- `updated_at`: 서버에서 메시지 **내용이 바뀐 시각**이다(등록·수정·삭제 때만 바뀜). 보드가 받은 시각이 아니다.
  - API-13 전달 확인으로는 바뀌지 않는다.
- `delivered`: "전달됨 / 전달 전" 표시용이다.
  - 등록·수정·삭제하면 `false`가 된다.
  - 보드가 API-13으로 확인을 보내면 `true`가 된다.
  - 보드가 받을 메시지는 이 값이 아니라 API-11의 `since`로 정해진다.

### 1-5. 삭제
- 메시지 삭제는 **소프트 삭제**다. 행을 지우지 않고 `deleted=true`로 표시한다.
  - 보드가 "지워졌다"는 변경을 받아가고, 재생 기록(API-09)도 남는다.
- 한 상황에는 삭제되지 않은 메시지가 1개만 있을 수 있다. 지운 뒤에는 같은 상황에 새로 등록할 수 있다.

---

## 2. 앱에서 부르는 흐름

```
[처음 한 번]  API-01 가족 등록 → 응답 id를 이후 family_id로 사용
[화면 열 때]  API-02 상황 목록 · API-03 메시지 목록 · API-08 추천 진행률 · API-10 개수
[글 메시지]   API-04 (kind=text, text)
[녹음 메시지] API-05 파일 업로드 → 받은 audio_path로 API-04 (kind=voice)
[수정·삭제]   API-06 · API-07
[온기기록]    API-09
```

- 녹음은 **올리기(05)와 등록(04)이 따로**다. 05만 하고 04를 안 하면 메시지는 생기지 않는다.
- 저장 성공은 서버에 들어간 순간 바로 온다. 보드가 받을 때까지 기다리지 않는다.
  - 저장 직후 `delivered`는 `false`이고, 보드가 받아가면 `true`가 된다.

## 3. 보드에서 부르는 흐름

서버는 보드에 먼저 보내지 않는다. 보드가 30초마다 서버에 물어보고 가져간다(폴링).

```
매 30초:
 1. 못 보낸 재생 기록이 있으면 API-14
 2. API-11 변경분 받기 (since = 직전 응답의 server_time, 처음엔 생략 또는 아주 이른 시각)
 3. 받은 메시지 반영. voice면 API-12로 녹음 받기, deleted=true면 보드에서 지우기
 4. API-13 전달 확인 (반영한 메시지의 id 목록. 지운 메시지는 넣지 않아도 된다)
 5. 모두 성공하면 server_time을 다음 since로 저장
재생할 때마다:
 - API-14 재생 기록 올리기
```

- 서버의 2xx 응답을 받아야 성공이다. 대답이 없거나 오류가 오면 실패로 보고, `since`를 그대로 둔 채 다음 차례에 다시 한다.
- 같은 요청을 다시 보내도 안전하다.
  - API-13: 이미 전달된 메시지라도 200이다.
  - API-14: 같은 재생 기록이면 새로 만들지 않고 기존 기록을 200으로 준다.
- `deleted=true`인 메시지는 API-12로 받을 수 없다(E-404).
- 서버에 없는 메시지 id로 재생 기록을 보내면 E-404이고, 다시 보내도 계속 E-404다.

---

## 4. API별 동작

### API-01 가족 등록 `POST /families` → 201
- `child_name`은 필수다. 앞뒤 공백을 지우고, 공백뿐이면 E-400이다. 최대 100자.
- `mom_title`, `dad_title`은 선택이다. 안 보내거나 null 또는 빈 값이면 "엄마", "아빠"가 들어간다.
- 가족은 1개만 쓴다. 이미 있으면 **E-409**.

### API-02 상황 목록 `GET /situations` → 200
- 상황 12개를 id 순으로 준다. 고정 데이터다.

### API-03 메시지 목록 `GET /messages?family_id=1` → 200
- 지워지지 않은 메시지만 상황 번호 순으로 준다.
- 가족이 없으면 E-404.

### API-04 메시지 등록 `POST /messages` → 201
- **text**
  - `text`는 1~200자이고, 공백만 있으면 안 된다.
  - `audio_path`는 보내지 않는다.
- **voice**
  - `audio_path`는 API-05가 준 값이어야 하고, 서버에 그 파일이 있어야 한다. 아니면 E-400 "업로드된 녹음 파일이 아니에요".
  - `text`는 보내지 않는다.
- 가족이나 상황이 없으면 E-404. 그 상황에 이미 메시지가 있으면 **E-409**.

### API-05 녹음 업로드 `POST /audio` (form-data `file`) → 201
- **m4a만** 받는다. 확장자가 `.m4a`이고 파일 앞부분이 m4a 모양(`ftyp`)이어야 한다.
- 최대 10MB(10,000,000바이트). 넘으면 **E-413**. 빈 파일은 E-400.
- 파일 이름은 서버가 `<32자리 랜덤>.m4a`로 새로 만든다. 보낸 파일 이름은 쓰지 않는다.
- 응답 예: `{"audio_path": "…m4a", "size_bytes": 318984, "content_type": "audio/mp4"}`
- 파일만 저장한다. 메시지는 API-04로 따로 등록한다.

### API-06 메시지 수정 `PATCH /messages/{id}` → 200
- 바꿀 칸만 보낸다(`author`, `kind`, `text`, `audio_path`). 보내지 않은 칸은 그대로 유지된다.
- `family_id`, `situation_id` 같은 다른 칸을 보내면 E-400이다. 아무 칸도 없으면 E-400이다.
- `author`, `kind`는 null로 보낼 수 없다(E-400). `text`, `audio_path`의 null은 비우기라는 뜻이다.
- `kind`를 바꾸면, 보내지 않은 반대쪽 값은 자동으로 null이 된다.
  - 예: voice → text로 바꾸면서 `text`만 보내면 `audio_path`는 null.
- 저장하면 `updated_at`이 새로 찍히고 `delivered=false`가 된다.
- 없거나 지워진 메시지는 E-404.

### API-07 메시지 삭제 `DELETE /messages/{id}` → 200
- `deleted=true`, `delivered=false`, `updated_at`을 갱신하고 **메시지 전체**를 돌려준다.
- 이미 지워진 메시지면 아무것도 바꾸지 않고 현재 상태를 돌려준다.
- 없는 메시지는 E-404.

### API-08 추천 진행률 `GET /families/{id}/progress` → 200
- `{"completed": 지워지지 않은 메시지 수, "total": 10}`
- 10개를 넘어도 실제 개수를 준다.
- 가족이 없으면 E-404.

### API-09 재생 기록 조회 `GET /play-logs?family_id=1` → 200
- 최근 재생부터 준다. 항목마다 `situation_id`, `author`를 붙여 준다.
- 지워진 메시지의 옛 기록도 포함한다.
- 가족이 없으면 E-404.

### API-10 메시지 개수 `GET /messages/count?family_id=1` → 200
- `{"count": 지워지지 않은 메시지 수}`. 전달 여부와 관계없다.
- 가족이 없으면 E-404.

보드용 API-11~14는 가족이 1개라 `family_id`를 받지 않는다.

### API-11 변경분 받기 `GET /device/changes?since=…` → 200
```json
{"server_time": "2026-11-03T16:11:09",
 "messages": [{"id": 1, "situation_id": 4, "author": "mom", "kind": "voice",
               "text": null, "deleted": false, "updated_at": "2026-11-03T16:11:09"}]}
```
- `updated_at`이 `since` 이상인 메시지를 `updated_at` 순으로 준다. 생성·수정·삭제(`deleted=true`)를 모두 포함한다.
- `since`를 생략하면 전부 준다.
- `server_time`은 조회 직전 서버 시각이다. 다음 요청의 `since`로 쓴다.
- 이 API는 `delivered`를 바꾸지 않는다.

### API-12 녹음 내려받기 `GET /device/audio/{id}` → 200 (파일)
- 올린 파일을 바이트 그대로 준다.
  - 헤더: `Content-Type: audio/mp4`, `Content-Disposition: attachment; filename="{id}.m4a"`
- text 메시지는 E-400.
- 없는 메시지, 지워진 메시지, 파일이 없는 경우는 E-404. 오류일 때는 JSON이 온다.

### API-13 전달 확인 `POST /device/ack` → 200
```json
{"message_ids": [1, 3]}
→ {"acknowledged_ids": [1, 3]}
```
- 1~100개를 보낸다. 같은 id가 두 번 있으면 E-400.
- 없는 id가 하나라도 있으면 아무것도 바꾸지 않고 E-404.
- 이미 `delivered=true`여도 200이다.
- `updated_at`은 바꾸지 않는다.

### API-14 재생 기록 올리기 `POST /device/play-logs` → 201 / 200
- `{"message_id": 1, "played_at": "2026-11-03T16:00:00"}`
- 새로 저장하면 **201**이다. 같은 `message_id`와 `played_at` 기록이 이미 있으면 새로 만들지 않고 기존 기록을 **200**으로 준다.
- 지워진 메시지의 기록도 저장한다.
- 없는 메시지는 E-404.

---

## 5. 11/11 확장 API (server-ext)
처음 받는 DB는 `schema.sql`에 들어 있다. **이미 쓰던 DB는** `mysql -u root ongi < migrate_1111.sql`을 한 번 실행한다(데이터 그대로).

### API-11 변경분 받기 (바뀐 점)
- 응답에 `family: {child_name, mom_title, dad_title}`가 함께 온다. 보드는 이 이름으로 아이를 부른다.
- 부를 때마다 `family.device_last_seen_at`을 서버 시각으로 남긴다(스피커 마지막 연결).

### API-15 가족 조회 `GET /families/{id}` → 200
- `{id, child_name, mom_title, dad_title, created_at, device_last_seen_at, device_online}`
- `device_online`: 마지막 연결이 90초 안이면 true (보드는 30초마다 동기화)

### API-16 가족 수정 `PATCH /families/{id}` → 200
- 바꿀 칸만 보낸다: `child_name`, `mom_title`, `dad_title` (앞뒤 공백 제거, 빈 값 E-400). 아무것도 없으면 E-400
- 응답은 API-15와 같다

### API-17 필요 기록 올리기 `POST /device/needs` → 201 (보드)
- `{situation_id, needed_at}` — 아이가 말한 상황에 부모 메시지가 없었을 때. **아이가 한 말은 보내지 않는다**
- 없는 상황 E-404, 시각 형식 E-400

### API-18 필요한 상황 조회 `GET /needs?family_id=1` → 200 (앱)
- 최근 14일 동안 찾았는데 **지금도 메시지가 없는** 상황만: `items: [{situation_id, name, category, count, last_needed_at}]`, 최근 순
- 부모가 그 상황에 메시지를 남기면 목록에서 저절로 빠진다

### API-19 기록 지우기 `DELETE /families/{id}/history` → 200 (앱)
- 재생 기록(play_log)과 필요 기록(need_log)을 모두 지운다. 메시지는 그대로
- `{deleted_play_logs, deleted_needs}`

### 시험 (11/11, MariaDB)
API-15·16·17·18·19와 API-11 family·마지막 연결, 기존 API-03·07 함께 확인. `migrate_1111.sql`을 예전 모양 DB에 적용해 확인.
