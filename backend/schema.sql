BEGIN;

CREATE TABLE IF NOT EXISTS users(
  id SERIAL PRIMARY KEY,
  nickname VARCHAR(30) NOT NULL,
  email VARCHAR(100) UNIQUE NOT NULL,
  password VARCHAR NOT NULL,
  "createdAt" TIMESTAMP NOT NULL DEFAULT now()
);
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS suspended_until TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN IF NOT EXISTS suspension_permanent BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS suspension_reason TEXT;

-- 이메일/닉네임을 대소문자와 앞뒤 공백을 무시하고 중복 차단합니다.
-- 예: Test@gmail.com == test@gmail.com, KJun == kjun
-- 기존 DB에 이미 중복 데이터가 있으면 배포를 실패시키지 않고 서버 검사로만 차단합니다.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM (
      SELECT lower(trim(email)) AS value
      FROM users
      GROUP BY lower(trim(email))
      HAVING COUNT(*) > 1
    ) duplicates
  ) THEN
    EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS users_email_unique_ci ON users (lower(trim(email)))';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM (
      SELECT lower(trim(nickname)) AS value
      FROM users
      GROUP BY lower(trim(nickname))
      HAVING COUNT(*) > 1
    ) duplicates
  ) THEN
    EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS users_nickname_unique_ci ON users (lower(trim(nickname)))';
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS teams(
  id SERIAL PRIMARY KEY,
  title VARCHAR(80) NOT NULL,
  game VARCHAR(40) NOT NULL,
  mode VARCHAR(40) NOT NULL,
  style VARCHAR(20) NOT NULL,
  mic BOOLEAN NOT NULL,
  capacity INTEGER NOT NULL CHECK(capacity BETWEEN 2 AND 20),
  owner_id INTEGER NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE teams ADD COLUMN IF NOT EXISTS is_private BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE teams ADD COLUMN IF NOT EXISTS access_code VARCHAR(4);
ALTER TABLE teams DROP CONSTRAINT IF EXISTS teams_access_code_format;
ALTER TABLE teams ADD CONSTRAINT teams_access_code_format CHECK (
  (is_private = false AND access_code IS NULL)
  OR
  (is_private = true AND access_code ~ '^[0-9]{4}$')
);

CREATE TABLE IF NOT EXISTS team_members(
  team_id INTEGER NOT NULL REFERENCES teams(id),
  user_id INTEGER NOT NULL REFERENCES users(id),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_read_message_id INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY(team_id,user_id)
);
ALTER TABLE team_members ADD COLUMN IF NOT EXISTS last_read_message_id INTEGER NOT NULL DEFAULT 0;
CREATE INDEX IF NOT EXISTS team_members_user_idx ON team_members(user_id);

CREATE TABLE IF NOT EXISTS messages(
  id SERIAL PRIMARY KEY,
  team_id INTEGER NOT NULL REFERENCES teams(id),
  sender_id INTEGER NOT NULL REFERENCES users(id),
  client_id UUID NOT NULL,
  body TEXT NOT NULL CHECK(length(body) BETWEEN 1 AND 2000),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(sender_id,client_id)
);
CREATE INDEX IF NOT EXISTS messages_team_page_idx ON messages(team_id,id DESC);

-- 방장이 5분 또는 영구 추방을 선택할 수 있도록 파티별 차단 상태를 보관합니다.
CREATE TABLE IF NOT EXISTS team_bans(
  team_id INTEGER NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_by INTEGER NOT NULL REFERENCES users(id),
  permanent BOOLEAN NOT NULL DEFAULT false,
  banned_until TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY(team_id,user_id)
);
CREATE INDEX IF NOT EXISTS team_bans_user_idx ON team_bans(user_id);

-- 게임별 티어/레벨은 게임 수가 늘어나도 확장 가능한 별도 테이블로 관리합니다.
CREATE TABLE IF NOT EXISTS user_game_profiles(
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  game VARCHAR(40) NOT NULL,
  tier VARCHAR(60),
  level VARCHAR(60),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY(user_id,game)
);
CREATE INDEX IF NOT EXISTS user_game_profiles_game_idx ON user_game_profiles(game);

-- 유저 신고 및 관리자 처리 기록입니다.
CREATE TABLE IF NOT EXISTS reports(
  id SERIAL PRIMARY KEY,
  reporter_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reported_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  team_id INTEGER REFERENCES teams(id) ON DELETE SET NULL,
  category VARCHAR(30) NOT NULL,
  details TEXT NOT NULL CHECK(length(details) BETWEEN 2 AND 1000),
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  admin_note TEXT,
  suspension_type VARCHAR(30),
  suspension_until TIMESTAMPTZ,
  resolved_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS reports_status_idx ON reports(status,created_at DESC);
CREATE INDEX IF NOT EXISTS reports_reported_user_idx ON reports(reported_user_id,created_at DESC);

-- 운영 공지/점검 알림. maintenance는 점검 중, maintenance_soon은 점검 예고입니다.
CREATE TABLE IF NOT EXISTS announcements(
  id SERIAL PRIMARY KEY,
  title VARCHAR(80) NOT NULL,
  message TEXT NOT NULL CHECK(length(message) BETWEEN 2 AND 1000),
  kind VARCHAR(30) NOT NULL DEFAULT 'notice',
  active BOOLEAN NOT NULL DEFAULT true,
  created_by INTEGER NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS announcements_active_idx ON announcements(active,created_at DESC);

COMMIT;
