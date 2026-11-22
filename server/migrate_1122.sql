-- ================================================================
--  11/22 확장: 부모 목소리 TTS (데이터를 지우지 않고 더한다)
--  사용법: mysql -u root ongi < migrate_1122.sql   (한 번만)
-- ================================================================
SET NAMES utf8mb4;

-- 부모 목소리 견본. 가족·작성자마다 1개(다시 등록하면 덮어씀).
-- 견본 파일은 /audio로 올린 m4a(server/files), 대본은 앱이 보여 준 등록 문장.
CREATE TABLE voice_profile (
    id          BIGINT              NOT NULL AUTO_INCREMENT,
    family_id   BIGINT              NOT NULL,
    author      ENUM('mom', 'dad')  NOT NULL,
    sample_path VARCHAR(512)        NOT NULL,
    ref_text    TEXT                NOT NULL,
    created_at  DATETIME(6)         NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uq_voice_profile (family_id, author),
    CONSTRAINT fk_voice_profile_family FOREIGN KEY (family_id) REFERENCES family (id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

-- 글 메시지를 부모 목소리로 만든 파일. kind/text/audio_path 규칙(chk_message_kind)은 그대로 두고 칸을 따로 둔다.
--   none    : 만들 필요 없음(녹음 메시지, 또는 목소리 미등록)
--   pending : 만들어야 함(작업기가 가져감)
--   ready   : 만들어짐 → 보드가 /device/tts-audio/{id}로 받아 감
--   failed  : 작업기가 실패를 알림 → 보드는 기본 TTS로 읽음
ALTER TABLE message
    ADD COLUMN tts_status ENUM('none', 'pending', 'ready', 'failed') NOT NULL DEFAULT 'none',
    ADD COLUMN tts_audio_path VARCHAR(512) NULL;
