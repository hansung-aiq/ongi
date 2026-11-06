"""온기 서버.

실행: uvicorn main:app --host 0.0.0.0 --port 8000 --reload
확인: http://localhost:8000/docs
"""
import re
import uuid
from datetime import datetime
from pathlib import Path
from typing import Literal

import pymysql
from fastapi import Depends, FastAPI, File, Response, UploadFile
from fastapi.responses import FileResponse
from pydantic import BaseModel, ConfigDict, Field, field_validator

import errors
from db import get_db, to_iso
from errors import ApiError

app = FastAPI(title="온기 서버")
errors.register(app)

# 녹음 파일 저장 위치. audio_path 는 이 폴더 기준 상대 경로(파일 키)다.
FILES_DIR = Path(__file__).parent / "files"
# 서버가 만드는 파일 키 모양: <uuid 32자리>.<확장자>. server/files/ 바로 아래에 저장한다. (과제서 1-5)
AUDIO_KEY_PATTERN = re.compile(r"^[0-9a-f]{32}\.[a-z0-9]{1,5}$")
# 녹음 파일 최대 크기 (10MB)
MAX_AUDIO_BYTES = 10_000_000
# 허용하는 녹음 형식: 확장자 → Content-Type. 앱 과제서대로 m4a만 받는다.
AUDIO_TYPES = {"m4a": "audio/mp4"}


# API-02 상황 목록: 12개, id 오름차순
@app.get("/situations", tags=["앱"])
def list_situations(conn=Depends(get_db)):
    with conn.cursor() as cur:
        cur.execute("SELECT id, name, category FROM situation ORDER BY id")
        return {"items": cur.fetchall()}


# API-01 가족 등록
class FamilyCreate(BaseModel):
    child_name: str = Field(min_length=1, max_length=100)
    # 호칭을 안 보내거나 null·빈 문자열이면 기본값을 쓴다.
    mom_title: str | None = Field(default="엄마", max_length=100)
    dad_title: str | None = Field(default="아빠", max_length=100)

    @field_validator("child_name")
    @classmethod
    def strip_name(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("자녀 이름이 비어 있어요")
        return v

    @field_validator("mom_title", "dad_title")
    @classmethod
    def default_title(cls, v: str | None, info) -> str:
        if v is None or not v.strip():
            return "엄마" if info.field_name == "mom_title" else "아빠"
        return v.strip()


@app.post("/families", tags=["앱"], status_code=201)
def create_family(body: FamilyCreate, conn=Depends(get_db)):
    with conn.cursor() as cur:
        # 가족은 1개만 쓴다. 이미 있으면 E-409. (규격서 API-01)
        cur.execute("SELECT 1 FROM family LIMIT 1")
        if cur.fetchone() is not None:
            raise ApiError("E-409", "이미 등록된 가족이 있어요")
        cur.execute(
            "INSERT INTO family (child_name, mom_title, dad_title) VALUES (%s, %s, %s)",
            (body.child_name, body.mom_title, body.dad_title),
        )
        family_id = cur.lastrowid
        cur.execute(
            "SELECT id, child_name, mom_title, dad_title, created_at FROM family WHERE id = %s",
            (family_id,),
        )
        row = cur.fetchone()
    conn.commit()
    row["created_at"] = to_iso(row["created_at"])
    return row


# ---------------------------------------------------------------- 메시지 공통

# 메시지 응답에 들어가는 칸. active_flag 는 DB 내부용이라 내보내지 않는다.
MESSAGE_COLUMNS = (
    "id, family_id, situation_id, author, kind, text, audio_path, "
    "delivered, created_at, updated_at, deleted"
)


def message_out(row: dict) -> dict:
    """DB 행을 응답 모양으로 바꾼다. MySQL BOOLEAN 은 0/1 로 오므로 true/false 로 바꾼다."""
    row["delivered"] = bool(row["delivered"])
    row["deleted"] = bool(row["deleted"])
    row["created_at"] = to_iso(row["created_at"])
    row["updated_at"] = to_iso(row["updated_at"])
    return row


def ensure_family(cur, family_id: int) -> None:
    cur.execute("SELECT 1 FROM family WHERE id = %s", (family_id,))
    if cur.fetchone() is None:
        raise ApiError("E-404", "가족을 찾을 수 없어요")


# API-03 메시지 목록: 삭제 안 된 메시지만, 상황 번호 순
@app.get("/messages", tags=["앱"])
def list_messages(family_id: int, conn=Depends(get_db)):
    with conn.cursor() as cur:
        ensure_family(cur, family_id)
        cur.execute(
            f"SELECT {MESSAGE_COLUMNS} FROM message "
            "WHERE family_id = %s AND deleted = FALSE ORDER BY situation_id",
            (family_id,),
        )
        return {"items": [message_out(r) for r in cur.fetchall()]}


# 목표 메시지 개수 (API-08 진행률의 total)
PROGRESS_TOTAL = 10


def count_active_messages(cur, family_id: int) -> int:
    """삭제 안 된 메시지 개수. 전달 여부(delivered)와는 상관없다."""
    ensure_family(cur, family_id)
    cur.execute(
        "SELECT COUNT(*) AS n FROM message WHERE family_id = %s AND deleted = FALSE",
        (family_id,),
    )
    return cur.fetchone()["n"]


# API-08 진행률: 10개 넘게 써도 실제 개수를 그대로 준다. (진행 막대 상한은 앱에서 처리)
@app.get("/families/{family_id}/progress", tags=["앱"])
def get_progress(family_id: int, conn=Depends(get_db)):
    with conn.cursor() as cur:
        return {"completed": count_active_messages(cur, family_id), "total": PROGRESS_TOTAL}


# API-10 메시지 개수
@app.get("/messages/count", tags=["앱"])
def get_message_count(family_id: int, conn=Depends(get_db)):
    with conn.cursor() as cur:
        return {"count": count_active_messages(cur, family_id)}


def fetch_message(cur, message_id: int) -> dict:
    cur.execute(f"SELECT {MESSAGE_COLUMNS} FROM message WHERE id = %s", (message_id,))
    row = cur.fetchone()
    if row is None:
        raise ApiError("E-404", "메시지를 찾을 수 없어요")
    return row


def check_content(kind: str, text: str | None, audio_path: str | None) -> None:
    """종류와 내용이 맞는지 확인한다. (schema.sql 의 chk_message_kind 와 같은 규칙)"""
    if kind == "text":
        if text is None or not text.strip():
            raise ApiError("E-400", "text 메시지에는 text가 필요해요")
        if len(text) > 200:
            raise ApiError("E-400", "text는 200자까지 쓸 수 있어요")
        if audio_path is not None:
            raise ApiError("E-400", "text 메시지에는 audio_path를 넣을 수 없어요")
    else:  # voice
        if audio_path is None:
            raise ApiError("E-400", "voice 메시지에는 audio_path가 필요해요")
        if text is not None:
            raise ApiError("E-400", "voice 메시지에는 text를 넣을 수 없어요")
        # 실제로 API-05로 올라온 파일 키인지 확인
        if not AUDIO_KEY_PATTERN.match(audio_path) or not (FILES_DIR / audio_path).is_file():
            raise ApiError("E-400", "업로드된 녹음 파일이 아니에요. 먼저 /audio로 올려 주세요")


# API-04 메시지 등록
class MessageCreate(BaseModel):
    family_id: int
    situation_id: int
    author: Literal["mom", "dad"]
    kind: Literal["voice", "text"]
    text: str | None = None
    audio_path: str | None = Field(default=None, max_length=512)


@app.post("/messages", tags=["앱"], status_code=201)
def create_message(body: MessageCreate, conn=Depends(get_db)):
    check_content(body.kind, body.text, body.audio_path)
    with conn.cursor() as cur:
        ensure_family(cur, body.family_id)
        cur.execute("SELECT 1 FROM situation WHERE id = %s", (body.situation_id,))
        if cur.fetchone() is None:
            raise ApiError("E-404", "상황을 찾을 수 없어요")
        try:
            # created_at·updated_at·delivered(false)·deleted(false)는 DB 기본값으로 들어간다.
            cur.execute(
                "INSERT INTO message (family_id, situation_id, author, kind, text, audio_path) "
                "VALUES (%s, %s, %s, %s, %s, %s)",
                (body.family_id, body.situation_id, body.author, body.kind, body.text, body.audio_path),
            )
        except pymysql.err.IntegrityError as e:
            # 1062 = UNIQUE 위반: 이 가족·상황에 삭제 안 된 메시지가 이미 있음
            if e.args[0] == 1062:
                raise ApiError("E-409", "이 상황에는 이미 메시지가 있어요")
            raise
        row = fetch_message(cur, cur.lastrowid)
    conn.commit()
    return message_out(row)


# API-05 녹음 업로드: 파일만 저장하고, 메시지 등록은 API-04에서 따로 한다.
@app.post("/audio", tags=["앱"], status_code=201)
def upload_audio(file: UploadFile = File(...)):
    ext = Path(file.filename or "").suffix.lower().lstrip(".")
    if ext not in AUDIO_TYPES:
        raise ApiError("E-400", "m4a 녹음 파일만 올릴 수 있어요")

    # 파일 이름은 서버가 새로 만든다. 보낸 이름을 쓰면 겹치거나 다른 폴더를 건드릴 수 있다.
    audio_path = f"{uuid.uuid4().hex}.{ext}"
    dest = FILES_DIR / audio_path
    FILES_DIR.mkdir(exist_ok=True)

    size = 0
    header = b""
    try:
        with dest.open("wb") as out:
            # 1MB씩 나눠 쓰다가 10MB를 넘는 순간 멈춘다.
            while chunk := file.file.read(1024 * 1024):
                if not header:
                    header = chunk[:12]
                size += len(chunk)
                if size > MAX_AUDIO_BYTES:
                    raise ApiError("E-413", "파일 크기는 10MB 이하여야 해요")
                out.write(chunk)
        if size == 0:
            raise ApiError("E-400", "빈 파일이에요")
        # m4a 파일은 5~8번째 바이트가 "ftyp"이다. 확장자만 바꾼 다른 파일을 걸러낸다.
        if header[4:8] != b"ftyp":
            raise ApiError("E-400", "m4a 형식의 파일이 아니에요")
    except BaseException:
        dest.unlink(missing_ok=True)  # 실패하면 쓰던 파일을 지운다
        raise

    return {"audio_path": audio_path, "size_bytes": size, "content_type": AUDIO_TYPES[ext]}


# updated_at 새 값: 지금 시각. 단, 같은 메시지의 이전 값보다 반드시 커야 하므로
# 혹시 시계가 같거나 뒤로 가도 이전 값 + 1마이크로초를 쓴다.
NEXT_UPDATED_AT = "GREATEST(NOW(6), updated_at + INTERVAL 1 MICROSECOND)"


# API-06 메시지 수정: 보낸 칸만 바뀐다. family_id·situation_id는 바꿀 수 없다.
class MessageUpdate(BaseModel):
    # 여기 없는 칸(family_id, situation_id 등)을 보내면 E-400으로 거절한다.
    model_config = ConfigDict(extra="forbid")

    author: Literal["mom", "dad"] | None = None
    kind: Literal["voice", "text"] | None = None
    text: str | None = None
    audio_path: str | None = Field(default=None, max_length=512)

    # text·audio_path 의 null 은 "비우기"지만, author·kind 는 비울 수 없으므로 null 을 거절한다.
    @field_validator("author", "kind")
    @classmethod
    def not_null(cls, v):
        if v is None:
            raise ValueError("null은 보낼 수 없어요")
        return v


@app.patch("/messages/{message_id}", tags=["앱"])
def update_message(message_id: int, body: MessageUpdate, conn=Depends(get_db)):
    sent = body.model_fields_set  # 요청에 실제로 들어 있던 칸 이름들
    if not sent:
        raise ApiError("E-400", "바꿀 내용이 없어요")

    with conn.cursor() as cur:
        # FOR UPDATE = 행 잠금. 수정이 끝날 때까지 같은 메시지에 대한 다른 수정·삭제가 끼어들지 못한다.
        cur.execute(f"SELECT {MESSAGE_COLUMNS} FROM message WHERE id = %s FOR UPDATE", (message_id,))
        cur_row = cur.fetchone()
        if cur_row is None or cur_row["deleted"]:
            raise ApiError("E-404", "메시지를 찾을 수 없어요")

        author = body.author if "author" in sent else cur_row["author"]
        kind = body.kind if "kind" in sent else cur_row["kind"]

        def final(field: str):
            # 보낸 값이 있으면 그 값, 안 보냈으면 종류가 그대로일 때만 기존 값을 유지.
            # 종류가 바뀌면 반대쪽 값은 NULL 이 된다.
            if field in sent:
                return getattr(body, field)
            return cur_row[field] if kind == cur_row["kind"] else None

        text, audio_path = final("text"), final("audio_path")
        check_content(kind, text, audio_path)

        cur.execute(
            "UPDATE message SET author = %s, kind = %s, text = %s, audio_path = %s, "
            f"delivered = FALSE, updated_at = {NEXT_UPDATED_AT} WHERE id = %s",
            (author, kind, text, audio_path, message_id),
        )
        row = fetch_message(cur, message_id)
    conn.commit()
    return message_out(row)


# API-07 메시지 삭제: 소프트 삭제. 행은 남기고 deleted=true 로 표시한다.
# 보드가 "삭제됨" 변경을 받아 가도록 delivered=false, updated_at 도 갱신한다.
@app.delete("/messages/{message_id}", tags=["앱"])
def delete_message(message_id: int, conn=Depends(get_db)):
    with conn.cursor() as cur:
        cur.execute(f"SELECT {MESSAGE_COLUMNS} FROM message WHERE id = %s FOR UPDATE", (message_id,))
        row = cur.fetchone()
        if row is None:
            raise ApiError("E-404", "메시지를 찾을 수 없어요")
        # 이미 삭제된 메시지면 아무것도 바꾸지 않고 현재 상태를 돌려준다.
        if not row["deleted"]:
            cur.execute(
                f"UPDATE message SET deleted = TRUE, delivered = FALSE, updated_at = {NEXT_UPDATED_AT} "
                "WHERE id = %s",
                (message_id,),
            )
            row = fetch_message(cur, message_id)
    conn.commit()
    return message_out(row)


# API-12 녹음 내려받기: 성공하면 녹음 파일 자체를, 실패하면 JSON 오류를 돌려준다.
# 지워진 메시지는 보드가 받을 필요가 없으므로 없는 메시지와 같게 E-404.
@app.get("/device/audio/{message_id}", tags=["보드"])
def download_audio(message_id: int, conn=Depends(get_db)):
    with conn.cursor() as cur:
        row = fetch_message(cur, message_id)
    if row["deleted"]:
        raise ApiError("E-404", "메시지를 찾을 수 없어요")
    if row["kind"] != "voice":
        raise ApiError("E-400", "녹음 메시지가 아니에요")
    audio_path = row["audio_path"]
    path = FILES_DIR / audio_path
    if not AUDIO_KEY_PATTERN.match(audio_path) or not path.is_file():
        raise ApiError("E-404", "녹음 파일을 찾을 수 없어요")
    ext = path.suffix.lstrip(".")
    return FileResponse(path, media_type=AUDIO_TYPES.get(ext, "application/octet-stream"), filename=f"{message_id}.{ext}")


# API-11 변경분 받기: since 이후 생기거나 고쳐지거나 지워진 메시지(deleted 포함).
# 응답 모양은 보드 가짜 서버(device/mock_server.py)와 같다. 가족은 1개라 family_id 를 받지 않는다.
# server_time 은 조회 직전 서버 시각. 보드는 이 값을 다음 since 로 쓰고, 보드 시계 보정에도 쓴다.
TIME_EXAMPLE = "2026-11-02T20:00:00"


TIME_PATTERN = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$")


def parse_time(value: str) -> datetime | None:
    """공통지침 형식 YYYY-MM-DDTHH:mm:ss 만 받는다(시간대·소수초 없음). 형식이 틀리면 None."""
    if not TIME_PATTERN.match(value):
        return None
    try:
        return datetime.fromisoformat(value)
    except ValueError:  # 13월, 25시처럼 모양은 맞지만 없는 시각
        return None


@app.get("/device/changes", tags=["보드"])
def list_changes(since: str | None = None, conn=Depends(get_db)):
    since_at = None
    if since is not None:
        since_at = parse_time(since)
        if since_at is None:
            raise ApiError("E-400", f"since 형식이 올바르지 않아요 (예: {TIME_EXAMPLE})")
    with conn.cursor() as cur:
        cur.execute("SELECT NOW(6) AS server_time")
        server_time = cur.fetchone()["server_time"]
        sql = "SELECT id, situation_id, author, kind, text, deleted, updated_at FROM message"
        params = []
        if since_at is not None:
            sql += " WHERE updated_at >= %s"
            params.append(since_at)
        cur.execute(sql + " ORDER BY updated_at, id", params)
        rows = cur.fetchall()
    messages = [{**r, "deleted": bool(r["deleted"]), "updated_at": to_iso(r["updated_at"])} for r in rows]
    return {"server_time": to_iso(server_time), "messages": messages}


# API-13 전달 확인: 보드가 받은 메시지 id 목록을 받아 delivered 를 true 로 바꾼다.
# 이미 delivered=true 여도 성공(응답을 못 받은 보드가 같은 요청을 다시 보낼 수 있음).
# updated_at 은 바꾸지 않는다(바꾸면 보드가 변경분으로 또 받아 간다).
class AckRequest(BaseModel):
    message_ids: list[int] = Field(min_length=1, max_length=100)


@app.post("/device/ack", tags=["보드"])
def ack_messages(body: AckRequest, conn=Depends(get_db)):
    ids = body.message_ids
    if len(set(ids)) != len(ids):
        raise ApiError("E-400", "같은 메시지 id가 두 번 들어 있어요")
    placeholders = ", ".join(["%s"] * len(ids))
    with conn.cursor() as cur:
        cur.execute(f"SELECT id FROM message WHERE id IN ({placeholders})", ids)
        if len(cur.fetchall()) != len(ids):
            raise ApiError("E-404", "메시지를 찾을 수 없어요")
        cur.execute(f"UPDATE message SET delivered = TRUE WHERE id IN ({placeholders})", ids)
    conn.commit()
    return {"acknowledged_ids": ids}


# API-14 재생 기록 올리기: 보드가 실제로 재생한 시각을 저장한다.
# 지워진 메시지도 받는다(보드가 삭제를 알기 전에 재생했거나, 끊겼다가 나중에 올릴 수 있음).
# 같은 (message_id, played_at) 이 이미 있으면 응답을 못 받은 보드의 재전송으로 보고
# 새로 만들지 않고 있던 기록을 200 으로 돌려준다.
class PlayLogCreate(BaseModel):
    message_id: int
    played_at: str


@app.post("/device/play-logs", tags=["보드"], status_code=201)
def create_play_log(body: PlayLogCreate, response: Response, conn=Depends(get_db)):
    played_at = parse_time(body.played_at)
    if played_at is None:
        raise ApiError("E-400", f"played_at 형식이 올바르지 않아요 (예: {TIME_EXAMPLE})")
    with conn.cursor() as cur:
        # 같은 메시지에 대한 동시 재전송이 둘 다 새 기록을 만들지 않도록 메시지 행을 잠근다.
        cur.execute("SELECT id FROM message WHERE id = %s FOR UPDATE", (body.message_id,))
        if cur.fetchone() is None:
            raise ApiError("E-404", "메시지를 찾을 수 없어요")
        cur.execute(
            "SELECT id, message_id, played_at FROM play_log WHERE message_id = %s AND played_at = %s",
            (body.message_id, played_at),
        )
        row = cur.fetchone()
        if row is not None:
            response.status_code = 200
        else:
            cur.execute(
                "INSERT INTO play_log (message_id, played_at) VALUES (%s, %s)",
                (body.message_id, played_at),
            )
            row = {"id": cur.lastrowid, "message_id": body.message_id, "played_at": played_at}
    conn.commit()
    return {"id": row["id"], "message_id": row["message_id"], "played_at": to_iso(row["played_at"])}


# API-09 재생 기록 조회: 자녀 온기기록 화면용. 최근 재생부터, 지워진 메시지의 과거 기록도 포함.
@app.get("/play-logs", tags=["앱"])
def list_play_logs(family_id: int, conn=Depends(get_db)):
    with conn.cursor() as cur:
        ensure_family(cur, family_id)
        cur.execute(
            "SELECT p.id, p.message_id, p.played_at, m.situation_id, m.author "
            "FROM play_log p JOIN message m ON m.id = p.message_id "
            "WHERE m.family_id = %s ORDER BY p.played_at DESC, p.id DESC",
            (family_id,),
        )
        rows = cur.fetchall()
    return {"items": [{**r, "played_at": to_iso(r["played_at"])} for r in rows]}
