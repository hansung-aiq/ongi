-- ================================================================
--  온기 DB 생성 스크립트 (SRV-03)
--  대상: MySQL 8.0.16 이상 (로컬 MySQL, AWS RDS 공통)
--  사용법: 빈 DB를 하나 만든 뒤 mysql 접속 화면에서
--      USE ongi;
--      SOURCE C:/dev/ongi/server/schema.sql;
--  결과: 테이블 4개 생성 + situation에 상황 12개 입력
-- ================================================================

-- 한글·이모지가 깨지지 않도록 문자셋을 utf8mb4로 맞춘다.
SET NAMES utf8mb4;

-- ----------------------------------------------------------------
-- 0. 기존 테이블 정리 (개발용)
--    이 파일을 여러 번 실행해도 처음부터 다시 만들어지게 한다.
--    주의: 들어 있던 데이터도 모두 지워진다. 배포 DB에서는 실행 전 확인할 것.
--    FK로 묶인 순서의 반대(자식 → 부모)로 지워야 오류가 나지 않는다.
-- ----------------------------------------------------------------
DROP TABLE IF EXISTS need_log;
DROP TABLE IF EXISTS play_log;
DROP TABLE IF EXISTS message;
DROP TABLE IF EXISTS situation;
DROP TABLE IF EXISTS family;


-- ----------------------------------------------------------------
-- 1. family (가족)
--    가족 1개만 쓰지만, 다른 테이블이 family_id로 가리키므로 테이블로 둔다.
-- ----------------------------------------------------------------
CREATE TABLE family (
    id          BIGINT        NOT NULL AUTO_INCREMENT,           -- 가족 번호 (자동 증가)
    child_name  VARCHAR(100)  NOT NULL,                          -- 자녀 이름
    mom_title   VARCHAR(100)  NOT NULL DEFAULT '엄마',            -- 엄마 호칭 (미입력 시 '엄마')
    dad_title   VARCHAR(100)  NOT NULL DEFAULT '아빠',            -- 아빠 호칭 (미입력 시 '아빠')
    created_at  DATETIME(6)   NOT NULL DEFAULT CURRENT_TIMESTAMP(6), -- 생성 일시
    device_last_seen_at DATETIME(6) NULL,                        -- 보드가 마지막으로 변경분을 받아 간 시각 (11/11, API-11이 기록)

    PRIMARY KEY (id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;


-- ----------------------------------------------------------------
-- 2. situation (상황)
--    12개 고정. id를 직접 지정해서 넣으므로 AUTO_INCREMENT를 쓰지 않는다.
-- ----------------------------------------------------------------
CREATE TABLE situation (
    id        TINYINT       NOT NULL,                            -- 상황 번호 (1~12)
    name      VARCHAR(100)  NOT NULL,                            -- 상황 이름
    category  VARCHAR(100)  NOT NULL,                            -- 카테고리

    PRIMARY KEY (id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;


-- ----------------------------------------------------------------
-- 3. message (메시지)
-- ----------------------------------------------------------------
CREATE TABLE message (
    id            BIGINT                     NOT NULL AUTO_INCREMENT, -- 메시지 번호
    family_id     BIGINT                     NOT NULL,                -- 가족 번호 (family.id)
    situation_id  TINYINT                    NOT NULL,                -- 상황 번호 (situation.id)
    author        ENUM('mom', 'dad')         NOT NULL,                -- 작성자
    kind          ENUM('voice', 'text')      NOT NULL,                -- 종류
    text          TEXT                       NULL,                    -- 텍스트 (text일 때만, 최대 200자는 API에서 검사)
    audio_path    VARCHAR(512)               NULL,                    -- 오디오 파일 경로 (voice일 때만)
    delivered     BOOLEAN                    NOT NULL DEFAULT FALSE,  -- 전달 여부 (보드 ack 후 TRUE)
    created_at    DATETIME(6)                NOT NULL DEFAULT CURRENT_TIMESTAMP(6), -- 생성 일시
    -- 갱신 일시: ON UPDATE CURRENT_TIMESTAMP를 일부러 쓰지 않는다.
    --   붙이면 ack(API-13)로 delivered만 바꿔도 시각이 바뀌어, 보드가 같은 메시지를 변경분으로 또 받아 간다.
    --   내용 수정·삭제할 때만 서버 코드가 직접 넣는다.
    updated_at    DATETIME(6)                NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    deleted       BOOLEAN                    NOT NULL DEFAULT FALSE,  -- 삭제 여부 (소프트 삭제)

    -- 자동 계산 칸: 삭제 안 된 메시지면 1, 삭제된 메시지면 NULL.
    --   서버 코드에서 직접 넣거나 바꾸지 않는다. (DB가 deleted를 보고 알아서 채움)
    active_flag   TINYINT GENERATED ALWAYS AS (IF(deleted, NULL, 1)) STORED,

    PRIMARY KEY (id),

    -- 같은 가족·상황에 삭제 안 된 메시지는 최대 1개.
    --   UNIQUE는 NULL끼리는 중복으로 보지 않으므로,
    --   삭제된 메시지(NULL)는 여러 개 남아도 되고 살아 있는 메시지(1)는 1개만 허용된다.
    --   위반 시 MySQL 오류 1062가 나므로 서버에서 E-409로 바꿔 돌려준다.
    UNIQUE KEY uq_message_active (family_id, situation_id, active_flag),

    -- API-11(변경분 받기)이 "updated_at 이후"를 자주 찾으므로 인덱스를 둔다.
    KEY idx_message_updated (updated_at),

    -- 종류와 내용이 맞는지 DB가 한 번 더 확인한다.
    --   text면 text 있음 + audio_path 없음, voice면 audio_path 있음 + text 없음.
    CONSTRAINT chk_message_kind CHECK (
        (kind = 'text'  AND text IS NOT NULL AND audio_path IS NULL) OR
        (kind = 'voice' AND audio_path IS NOT NULL AND text IS NULL)
    ),

    -- FK: 존재하지 않는 가족·상황 번호는 넣을 수 없다.
    CONSTRAINT fk_message_family    FOREIGN KEY (family_id)    REFERENCES family (id),
    CONSTRAINT fk_message_situation FOREIGN KEY (situation_id) REFERENCES situation (id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;


-- ----------------------------------------------------------------
-- 4. play_log (재생 기록)
--    삭제된 메시지의 과거 재생 기록도 남긴다. (메시지는 소프트 삭제라 행이 남아 있음)
-- ----------------------------------------------------------------
CREATE TABLE play_log (
    id          BIGINT       NOT NULL AUTO_INCREMENT,            -- 재생기록 번호
    message_id  BIGINT       NOT NULL,                           -- 메시지 번호 (message.id)
    played_at   DATETIME(6)  NOT NULL,                           -- 재생 일시 (보드가 보낸 실제 재생 시각)

    PRIMARY KEY (id),

    -- API-09(재생 기록 조회)가 재생 시각 내림차순으로 정렬하므로 인덱스를 둔다.
    KEY idx_play_log_played (played_at),

    CONSTRAINT fk_play_log_message FOREIGN KEY (message_id) REFERENCES message (id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;


-- ----------------------------------------------------------------
-- 4-1. need_log (필요 기록, 11/11)
--    아이가 말했는데 그 상황에 부모 메시지가 없었던 때. 보드가 API-17로 올린다.
--    아이가 한 말은 저장하지 않고 상황 번호와 시각만 둔다.
-- ----------------------------------------------------------------
CREATE TABLE need_log (
    id            BIGINT       NOT NULL AUTO_INCREMENT,          -- 기록 번호
    family_id     BIGINT       NOT NULL,                         -- 가족 번호
    situation_id  TINYINT      NOT NULL,                         -- 상황 번호
    needed_at     DATETIME(6)  NOT NULL,                         -- 보드가 보낸 시각

    PRIMARY KEY (id),
    KEY idx_need_log_needed (needed_at),
    CONSTRAINT fk_need_log_family    FOREIGN KEY (family_id)    REFERENCES family (id),
    CONSTRAINT fk_need_log_situation FOREIGN KEY (situation_id) REFERENCES situation (id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;


-- ----------------------------------------------------------------
-- 5. 상황 12개 입력 (과제서 1-4 목록 그대로)
-- ----------------------------------------------------------------
INSERT INTO situation (id, name, category) VALUES
    (1,  '학교 가기 싫은 날',             '학교·학업'),
    (2,  '실수해서 혼났을 때',            '학교·학업'),
    (3,  '시험을 망친 날',                '학교·학업'),
    (4,  '친구와 싸운 날',                '관계·비교'),
    (5,  '친구가 날 싫어하는 것 같을 때',  '관계·비교'),
    (6,  '남들과 비교될 때',              '관계·비교'),
    (7,  '울고 싶은 날',                  '감정·일상'),
    (8,  '아무것도 하기 싫은 날',          '감정·일상'),
    (9,  '잠이 안 오는 밤',               '감정·일상'),
    (10, '부모님이 보고 싶을 때',          '가족·기념일'),
    (11, '자랑하고 싶은 날',              '가족·기념일'),
    (12, '생일',                         '가족·기념일');


-- ----------------------------------------------------------------
-- 6. 확인용 (실행 후 12가 나오면 성공 = 과제서 1-4 완료 조건)
-- ----------------------------------------------------------------
SELECT COUNT(*) AS situation_count FROM situation;
