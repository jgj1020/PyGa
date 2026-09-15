import { INestApplication, HttpException } from "@nestjs/common";
import { Server } from "socket.io";
import { SessionGuard } from "../auth/session.guard.js";
import { CommunityService, positiveId } from "./community.service.js";
export function realtime(app: INestApplication, origins: string[]) {
  const io = new Server(app.getHttpServer(), {
    cors: { origin: origins },
    maxHttpBufferSize: 16384,
  });
  const auth = app.get(SessionGuard),
    service = app.get(CommunityService);
  io.use(async (socket, next) => {
    try {
      socket.data.session = await auth.verify(socket.handshake.auth?.token);
      next();
    } catch {
      next(new Error("다시 로그인해주세요."));
    }
  });
  io.on("connection", (socket) => {
    const expires = setTimeout(
      () => socket.disconnect(true),
      Math.max(0, socket.data.session.exp * 1000 - Date.now()),
    );
    socket.on("disconnect", () => clearTimeout(expires));
    let lastSend = 0;
    const run = async (ack: any, action: (uid: number) => Promise<any>) => {
      if (typeof ack !== "function") return;
      try {
        const s = await auth.verify(socket.handshake.auth?.token);
        ack({ ok: true, data: await action(s.sub) });
      } catch (e) {
        ack({
          ok: false,
          error:
            e instanceof HttpException
              ? e.message
              : "처리하지 못했습니다. 다시 시도해주세요.",
        });
      }
    };
    socket.on(
      "team:join",
      (data, ack) =>
        void run(ack, async (uid) => {
          const id = positiveId(data?.teamId);
          await service.member(uid, id);
          for (const room of socket.rooms)
            if (room.startsWith("team:")) await socket.leave(room);
          await socket.join("team:" + id);
          return { teamId: id };
        }),
    );
    socket.on(
      "message:send",
      (data, ack) =>
        void run(ack, async (uid) => {
          if (Date.now() - lastSend < 300)
            throw new HttpException("잠시 후 보내주세요.", 429);
          lastSend = Date.now();
          const m = await service.send(uid, data);
          io.to("team:" + m.teamId).emit("message:new", m);
          return m;
        }),
    );
  });
  return io;
}
