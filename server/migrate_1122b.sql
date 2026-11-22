-- ================================================================
--  11/22 확장 2: 목소리 캐릭터(문장 5개) + 미리 듣기
--  사용법: mysql -u root ongi < migrate_1122b.sql   (migrate_1122.sql 다음에 한 번)
-- ================================================================
SET NAMES utf8mb4;

-- 캐릭터 이름('아빠 지현이')과 견본 목록(JSON: [{"audio_path": "...m4a", "text": "읽은 문장"}, ...]).
-- 견본이 여러 개면 작업기가 이어 붙여 하나의 견본으로 쓴다. 예전 행(견본 1개)은 sample_path·ref_text를 그대로 쓴다.
ALTER TABLE voice_profile
    ADD COLUMN name VARCHAR(100) NULL,
    ADD COLUMN samples TEXT NULL;

-- 미리 듣기: 앱에서 쓴 글을 저장하기 전에 캐릭터 목소리로 들어 본다. 작업기가 메시지보다 먼저 처리한다.
CREATE TABLE tts_preview (
    id          BIGINT              NOT NULL AUTO_INCREMENT,
    family_id   BIGINT              NOT NULL,
    author      ENUM('mom', 'dad')  NOT NULL,
    text        TEXT                NOT NULL,
    status      ENUM('pending', 'ready', 'failed') NOT NULL DEFAULT 'pending',
    audio_path  VARCHAR(512)        NULL,
    created_at  DATETIME(6)         NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY idx_tts_preview_status (status, created_at),
    CONSTRAINT fk_tts_preview_family FOREIGN KEY (family_id) REFERENCES family (id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;
