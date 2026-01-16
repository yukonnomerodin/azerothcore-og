-- modules/mod-mercenary-system/sql/world/001_mercenary_system_schema.sql
-- PR-0: schema stub (can be extended later)

CREATE TABLE IF NOT EXISTS mercenary_owner (
    owner_guid BIGINT UNSIGNED NOT NULL,
    mercenary_guid BIGINT UNSIGNED NOT NULL DEFAULT 0,
    role TINYINT UNSIGNED NOT NULL DEFAULT 0,
    active TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (owner_guid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
