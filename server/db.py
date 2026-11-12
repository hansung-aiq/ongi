"""DB 접속 관리.

접속 정보는 .env 에서 읽는다. 코드에 비밀번호를 직접 쓰지 않는다.
"""
import os
from datetime import datetime

import pymysql
import pymysql.cursors
from dotenv import load_dotenv

load_dotenv()


def connect() -> pymysql.connections.Connection:
    return pymysql.connect(
        host=os.environ["DB_HOST"],
        port=int(os.environ.get("DB_PORT", "3306")),
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        database=os.environ["DB_NAME"],
        charset="utf8mb4",
        # 조회 결과를 {"id": 1, "name": ...} 처럼 dict로 받는다.
        cursorclass=pymysql.cursors.DictCursor,
        # 자동 커밋을 끄고, 여러 쿼리를 묶어야 할 때(트랜잭션) 직접 commit 한다.
        autocommit=False,
        # CURRENT_TIMESTAMP 가 접속 환경마다 달라지지 않도록 시간대를 명시한다.
        init_command=f"SET time_zone = '{os.environ.get('DB_TIME_ZONE', '+09:00')}'",
    )


def to_iso(dt: datetime) -> str:
    """시각을 공통지침 형식 YYYY-MM-DDTHH:mm:ss 로 내보낸다. DB에는 소수 6자리로 저장돼 있고, 초 아래는 버린다(내림)."""
    return dt.isoformat(timespec="seconds")


def get_db():
    """FastAPI 의존성: 요청 하나마다 접속을 열고, 끝나면 닫는다."""
    conn = connect()
    try:
        yield conn
    finally:
        conn.close()
