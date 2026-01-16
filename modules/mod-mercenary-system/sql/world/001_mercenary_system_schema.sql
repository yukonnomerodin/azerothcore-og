-- PR-1: Mercenary hire persistence (world DB)

CREATE TABLE IF NOT EXISTS `mod_mercenary_hire` (
  `owner_guid` BIGINT UNSIGNED NOT NULL,
  `merc_guid`  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `role`       TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `active`     TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`owner_guid`),
  KEY `idx_merc_guid` (`merc_guid`),
  KEY `idx_active` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
