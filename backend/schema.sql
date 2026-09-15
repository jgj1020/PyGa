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

COMMIT;
