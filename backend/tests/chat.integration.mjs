// Isolated PostgreSQL (WASM) + real Nest HTTP and Socket.IO tests.
// Does not connect to or modify the user's PostgreSQL database.
import "reflect-metadata";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { randomUUID } from "node:crypto";
import { PGlite } from "@electric-sql/pglite";
import { Test } from "@nestjs/testing";
import { ValidationPipe } from "@nestjs/common";
import { DataSource } from "typeorm";
import { JwtService } from "@nestjs/jwt";
import { getRepositoryToken } from "@nestjs/typeorm";
import { json } from "express";
import { io as clientIO } from "socket.io-client";
import sharp from "sharp";
import { AuthModule } from "../dist/auth/auth.module.js";
import { User } from "../dist/users/user.entity.js";
import { CommunityModule } from "../dist/community/community.module.js";
import { CommunityService } from "../dist/community/community.service.js";
import { realtime } from "../dist/community/realtime.js";

process.env.JWT_SECRET = randomUUID() + randomUUID();
const pg = new PGlite();
const schema = await readFile(
  new URL("../schema.sql", import.meta.url),
  "utf8",
);
await pg.exec(schema);
await pg.exec(schema); // repeatable additive migration
const facade = {
  query: async (sql, params) => (await pg.query(sql, params)).rows,
  transaction: (fn) =>
    pg.transaction((tx) =>
      fn({ query: async (sql, p) => (await tx.query(sql, p)).rows }),
    ),
};
class DatabaseModule {}
const dbModule = {
  module: DatabaseModule,
  global: true,
  providers: [{ provide: DataSource, useValue: facade }],
  exports: [DataSource],
};
const repository = {
  findOne: async ({ where }) =>
    (
      await facade.query(
        "SELECT * FROM users WHERE " + (where.id ? "id" : "email") + "=$1",
        [where.id ?? where.email],
      )
    )[0] ?? null,
  create: (value) => value,
  save: async (value) =>
    (
      await facade.query(
        "INSERT INTO users(nickname,email,password) VALUES($1,$2,$3) RETURNING *",
        [value.nickname, value.email, value.password],
      )
    )[0],
};
const moduleRef = await Test.createTestingModule({
  imports: [dbModule, AuthModule, CommunityModule],
})
  .overrideProvider(getRepositoryToken(User))
  .useValue(repository)
  .compile();
const app = moduleRef.createNestApplication({ bodyParser: false });
app.use(json({ limit: "3mb" }));
app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
app.useLogger(false);
const io = realtime(app, ["http://localhost:5173"]);
await app.listen(0, "127.0.0.1");
const base = await app.getUrl(),
  sockets = [];
const request = async (method, path, body, token) => {
  const r = await fetch(base + path, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: "Bearer " + token } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  return { status: r.status, data: await r.json() };
};
const connect = (token) =>
  new Promise((resolve, reject) => {
    const s = clientIO(base, {
      transports: ["websocket"],
      auth: { token },
      forceNew: true,
      reconnection: false,
    });
    sockets.push(s);
    const timer = setTimeout(() => reject(new Error("socket timeout")), 4000);
    s.once("connect", () => {
      clearTimeout(timer);
      resolve(s);
    });
    s.once("connect_error", (e) => {
      clearTimeout(timer);
      reject(e);
    });
  });
const ack = (s, event, data) =>
  new Promise((resolve, reject) =>
    s.timeout(4000).emit(event, data, (e, r) => (e ? reject(e) : resolve(r))),
  );
const event = (s) =>
  new Promise((resolve, reject) => {
    const timer = setTimeout(
      () => reject(new Error("broadcast timeout")),
      4000,
    );
    s.once("message:new", (m) => {
      clearTimeout(timer);
      resolve(m);
    });
  });
const pass = (name) => console.log("PASS " + name);
try {
  assert.equal((await request("GET", "/community/teams")).status, 401);
  pass("anonymous HTTP blocked");
  await assert.rejects(connect("invalid"));
  pass("invalid socket token blocked");
  const short = {
    nickname: "tester",
    email: "short@example.test",
    password: "1234567",
  };
  assert.equal((await request("POST", "/auth/register", short)).status, 400);
  assert.equal((await request("POST", "/auth/login", short)).status, 400);
  pass("8 character minimum enforced on server");
  const tokens = [],
    users = [];
  for (let i = 0; i < 3; i++) {
    const data = {
      nickname: "tester" + i,
      email: "test" + i + "@example.test",
      password: "Test1234!",
    };
    const reg = await request("POST", "/auth/register", data);
    assert.equal(reg.status, 201);
    assert.equal(reg.data.user.password, undefined);
    const login = await request("POST", "/auth/login", data);
    assert.equal(login.status, 201);
    tokens.push(login.data.accessToken);
    users.push(login.data.user);
  }
  assert.equal(
    (
      await request("POST", "/auth/login", {
        email: "test0@example.test",
        password: "wrong1234",
      })
    ).status,
    401,
  );
  pass("registration, actual password verification and token login");
  const payload = {
    title: "테스트 팀",
    game: "VALORANT",
    mode: "경쟁전",
    style: "편하게",
    mic: true,
    capacity: 2,
  };
  const team = (await request("POST", "/community/teams", payload, tokens[0]))
    .data;
  assert.ok(team.id);
  assert.equal(
    (await request("GET", "/community/teams?mine=true", null, tokens[1])).data
      .length,
    0,
  );
  assert.equal(
    (
      await request(
        "GET",
        `/community/teams/${team.id}/messages`,
        null,
        tokens[1],
      )
    ).status,
    403,
  );
  const a = await connect(tokens[0]),
    b = await connect(tokens[1]),
    c = await connect(tokens[2]);
  assert.equal((await ack(c, "team:join", { teamId: team.id })).ok, false);
  assert.equal(
    (
      await ack(c, "message:send", {
        teamId: team.id,
        clientId: randomUUID(),
        body: "forbidden",
      })
    ).ok,
    false,
  );
  pass("non-member history, room subscription and message send blocked");
  assert.equal(
    (await request("POST", `/community/teams/${team.id}/join`, {}, tokens[1]))
      .status,
    201,
  );
  assert.equal(
    (await request("POST", `/community/teams/${team.id}/join`, {}, tokens[1]))
      .status,
    201,
  );
  assert.equal(
    (await request("POST", `/community/teams/${team.id}/join`, {}, tokens[2]))
      .status,
    400,
  );
  pass("team join is idempotent, full teams reject new members");
  assert.equal((await ack(a, "team:join", { teamId: team.id })).ok, true);
  assert.equal((await ack(b, "team:join", { teamId: team.id })).ok, true);
  let leaked = 0;
  c.on("message:new", () => leaked++);
  const next = event(b),
    body = { teamId: team.id, clientId: randomUUID(), body: "안녕하세요!" };
  const sent = await ack(a, "message:send", body);
  assert.equal(sent.ok, true);
  assert.equal((await next).body, body.body);
  assert.equal(sent.data.senderId, users[0].id);
  pass("two independent accounts receive live messages");
  await new Promise((r) => setTimeout(r, 350));
  const retried = await ack(a, "message:send", body);
  assert.equal(retried.data.id, sent.data.id);
  assert.equal(
    (
      await request(
        "GET",
        `/community/teams/${team.id}/messages`,
        null,
        tokens[1],
      )
    ).data.length,
    1,
  );
  assert.equal(leaked, 0);
  pass("retry has one DB record and outsider gets no broadcast");
  b.disconnect();
  const b2 = await connect(tokens[1]);
  assert.equal((await ack(b2, "team:join", { teamId: team.id })).ok, true);
  assert.equal(
    (
      await request(
        "GET",
        `/community/teams/${team.id}/messages`,
        null,
        tokens[1],
      )
    ).data[0].body,
    body.body,
  );
  const second = event(a);
  assert.equal(
    (
      await ack(b2, "message:send", {
        teamId: team.id,
        clientId: randomUUID(),
        body: "반가워요",
      })
    ).ok,
    true,
  );
  assert.equal((await second).body, "반가워요");
  pass("reconnect restores history; reply works in reverse direction");
  const service = app.get(CommunityService);
  for (let i = 0; i < 54; i++)
    await service.send(users[0].id, {
      teamId: team.id,
      clientId: randomUUID(),
      body: "message " + i,
    });
  const recent = await service.history(users[0].id, team.id);
  const older = await service.history(users[0].id, team.id, recent[0].id);
  assert.equal(recent.length, 50);
  assert.equal(older.length, 6);
  assert.ok(older.at(-1).id < recent[0].id);
  pass("50-message cursor pagination does not overlap");
  const jpg = await sharp({
    create: { width: 20, height: 20, channels: 3, background: "#00dfce" },
  })
    .jpeg()
    .toBuffer();
  const profile = await request(
    "PATCH",
    "/community/me",
    {
      nickname: "새 닉네임",
      avatar: "data:image/jpeg;base64," + jpg.toString("base64"),
    },
    tokens[0],
  );
  assert.equal(profile.status, 200);
  assert.ok(profile.data.avatar.startsWith("data:image/jpeg;base64,"));
  assert.equal(profile.data.password, undefined);
  assert.equal(
    (
      await request(
        "PATCH",
        "/community/me",
        { nickname: "새 닉네임", avatar: "data:image/jpeg;base64,YWJj" },
        tokens[0],
      )
    ).status,
    400,
  );
  assert.equal(
    (await request("GET", "/community/me", null, tokens[0])).data.nickname,
    "새 닉네임",
  );
  assert.equal(
    (await service.history(users[1].id, team.id))[0].avatar,
    profile.data.avatar,
  );
  pass("photo persists, invalid image rejected, nickname/avatar shown in chat");
  const expired = app
    .get(JwtService)
    .sign({ sub: users[0].id }, { expiresIn: -1 });
  await assert.rejects(connect(expired));
  const shortToken = app
    .get(JwtService)
    .sign({ sub: users[0].id }, { expiresIn: 1 });
  const expiring = await connect(shortToken);
  await new Promise((r) => setTimeout(r, 1200));
  assert.equal(expiring.connected, false);
  pass(
    "expired tokens blocked and active sockets disconnect at token expiration",
  );
  // A fresh service instance has no message memory; the database is authoritative.
  assert.equal(
    (await new CommunityService(facade).history(users[1].id, team.id)).length,
    50,
  );
  pass("new service instance restores DB history");
  console.log("ALL CHAT INTEGRATION CHECKS PASSED");
} finally {
  for (const s of sockets) s.disconnect();
  await new Promise((resolve) => io.close(resolve));
  await app.close();
  await pg.close();
}
