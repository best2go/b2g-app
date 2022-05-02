CREATE TABLE syslog (
    id           INT AUTO_INCREMENT NOT NULL,
    created_at   DATETIME           NOT NULL,
    facility     VARCHAR(16)        NOT NULL,
    level        VARCHAR(16)        NOT NULL,
    message      VARCHAR(256)       NOT NULL,
    context      LONGTEXT    DEFAULT NULL COMMENT '(DC2Type:json)',
    hostname     VARCHAR(32) DEFAULT NULL,
    env          VARCHAR(16) DEFAULT NULL,
    x_request_id VARCHAR(64) DEFAULT NULL,
    PRIMARY KEY (id)
) DEFAULT CHARACTER SET utf8mb4
  COLLATE `utf8mb4_unicode_ci`
  ENGINE = InnoDB
  COMMENT 'trivial syslogd table';
