import pg from "pg";
import { readFile } from "node:fs/promises";

if (!process.env.DB_PASSWORD) {
  throw new Error("DB_PASSWORD 환경변수를 설정해주세요.");
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
  await client.query(
    await readFile(new URL("./schema.sql", import.meta.url), "utf8"),
  );

  const adminEmail = process.env.ADMIN_EMAIL?.trim().toLowerCase();
  if (adminEmail) {
    const result = await client.query(
      "UPDATE users SET is_admin=true WHERE lower(email)=lower($1) RETURNING id,email",
      [adminEmail],
    );
    if (result.rowCount === 0) {
      console.warn(
        `ADMIN_EMAIL(${adminEmail})과 일치하는 회원이 없습니다. 먼저 해당 이메일로 회원가입한 뒤 db:setup을 다시 실행하세요.`,
      );
    } else {
      console.log(`관리자 지정 완료: ${result.rows[0].email}`);
    }
  }

  console.log("DB 준비 완료 (기존 회원/파티/채팅 보존)");
} finally {
  await client.end();
}
