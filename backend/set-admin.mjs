import pg from "pg";
import bcrypt from "bcrypt";

const email = process.env.ADMIN_EMAIL;
const password = process.env.ADMIN_PASSWORD;
const nickname = "PyGa 관리자";

if (!process.env.DB_PASSWORD) {
  throw new Error("DB_PASSWORD를 먼저 설정해주세요.");
}

const client = new pg.Client({
  host: process.env.DB_HOST ?? "localhost",
  port: Number(process.env.DB_PORT ?? 5432),
  user: process.env.DB_USER ?? "postgres",
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME ?? "pyga",
});

await client.connect();

try {
  const hash = await bcrypt.hash(password, 10);

  const existing = await client.query(
    "SELECT id FROM users WHERE lower(email) = lower($1) LIMIT 1",
    [email]
  );

  if (existing.rowCount > 0) {
    await client.query(
      `UPDATE users
       SET password = $1, is_admin = true
       WHERE id = $2`,
      [hash, existing.rows[0].id]
    );
  } else {
    await client.query(
      `INSERT INTO users (nickname, email, password, is_admin)
       VALUES ($1, $2, $3, true)`,
      [nickname, email, hash]
    );
  }

  console.log("관리자 계정 설정 완료:", email);
} finally {
  await client.end();
}
