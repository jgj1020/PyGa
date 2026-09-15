import pg from "pg";
import { readFile } from "node:fs/promises";
if (!process.env.DB_PASSWORD)
  throw new Error("DB_PASSWORD 환경변수를 설정해주세요.");
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
  console.log("DB 준비 완료 (기존 회원 보존)");
} finally {
  await client.end();
}
