import pg from 'pg';
import { readFile } from 'node:fs/promises';
if (!process.env.DB_PASSWORD) throw new Error('DB_PASSWORD 환경변수가 필요합니다. 기존 .env 설정으로 실행해주세요.');
const client = new pg.Client({
  host: process.env.DB_HOST ?? 'localhost',
  port: Number(process.env.DB_PORT ?? 5432),
  user: process.env.DB_USER ?? 'postgres',
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME ?? 'pyga',
});
try {
  await client.connect();
  await client.query(await readFile(new URL('./migrations/20260930-recruitment.sql', import.meta.url), 'utf8'));
  console.log('모집 상태 컬럼 준비 완료. 기존 파티와 대화는 유지됩니다.');
} finally { await client.end(); }
