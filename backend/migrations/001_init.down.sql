-- 删除索引
DROP INDEX IF EXISTS idx_user_funds_user_id;
DROP INDEX IF EXISTS idx_token_blacklist_hash;
DROP INDEX IF EXISTS idx_verification_codes_email;
DROP INDEX IF EXISTS idx_users_email;

-- 删除表
DROP TABLE IF EXISTS user_funds;
DROP TABLE IF EXISTS token_blacklist;
DROP TABLE IF EXISTS verification_codes;
DROP TABLE IF EXISTS users;
