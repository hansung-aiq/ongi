-- ================================================================
--  11/11 확장: 이미 쓰고 있는 DB에 데이터를 지우지 않고 더한다.
--  사용법: mysql -u root ongi < migrate_1111.sql   (한 번만)
--  새로 만드는 DB는 schema.sql에 이미 들어 있으니 실행하지 않는다.
-- ================================================================
SET NAMES utf8mb4;

ALTER TABLE family ADD COLUMN device_last_seen_at DATETIME(6) NULL;

CREATE TABLE need_log (
    id            BIGINT       NOT NULL AUTO_INCREMENT,
    family_id     BIGINT       NOT NULL,
    situation_id  TINYINT      NOT NULL,
    needed_at     DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    KEY idx_need_log_needed (needed_at),
    CONSTRAINT fk_need_log_family    FOREIGN KEY (family_id)    REFERENCES family (id),
    CONSTRAINT fk_need_log_situation FOREIGN KEY (situation_id) REFERENCES situation (id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;
