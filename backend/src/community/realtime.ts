import { HttpException, INestApplication } from "@nestjs/common";
import { Server } from "socket.io";
import { SessionGuard } from "../auth/session.guard.js";
import { AdminService } from "../admin/admin.service.js";
import { CommunityService, positiveId } from "./community.service.js";
import { communityEvents } from "./events.js";

type CorsOriginChecker = (
  origin: string | undefined,
  callback: (error: Error | null, allow?: boolean) => void,
) => void;

export function realtime(app: INestApplication, corsOrigin: CorsOriginChecker) {
  const io = new Server(app.getHttpServer(), {
    cors: { origin: corsOrigin },
    maxHttpBufferSize: 16384,
  });
  const auth = app.get(SessionGuard);
  const service = app.get(CommunityService);
  const adminService = app.get(AdminService);

  communityEvents.on("admin:update", (event) => {
    io.to("admins").emit("admin:update", event);
  });

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
        socket.data.session = s;
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

    const runAdmin = async (
      ack: any,
      action: (uid: number) => Promise<any>,
    ) =>
      run(ack, async (uid) => {
        await adminService.requireAdmin(uid);
        return action(uid);
      });

    socket.on("admin:watch", (_data, ack) =>
      void runAdmin(ack, async () => {
        await socket.join("admins");
        return { watching: true };
      }),
    );

    socket.on("team:join", (data, ack) =>
      void run(ack, async (uid) => {
        const id = positiveId(data?.teamId);
        await service.member(uid, id);
        for (const room of socket.rooms) {
          if (room.startsWith("team:")) await socket.leave(room);
        }
        await socket.join("team:" + id);
        socket.to("team:" + id).emit("team:members_changed", { teamId: id });
        return { teamId: id };
      }),
    );

    socket.on("message:send", (data, ack) =>
      void run(ack, async (uid) => {
        if (Date.now() - lastSend < 300) {
          throw new HttpException("잠시 후 보내주세요.", 429);
        }
        lastSend = Date.now();
        const m = await service.send(uid, data);
        io.to("team:" + m.teamId).emit("message:new", m);
        io.to("admins").emit("admin:message_new", m);
        io.to("admins").emit("admin:update", { type: "message", teamId: m.teamId });
        return m;
      }),
    );

    socket.on("message:read", (data, ack) =>
      void run(ack, async (uid) => {
        const teamId = positiveId(data?.teamId);
        const messageId = positiveId(data?.messageId);
        const update = await service.markRead(uid, teamId, messageId);
        io.to("team:" + teamId).emit("message:read", update);
        return update;
      }),
    );

    socket.on("team:kick", (data, ack) =>
      void run(ack, async (uid) => {
        const teamId = positiveId(data?.teamId);
        const memberId = positiveId(data?.memberId);
        const result = await service.kick(uid, teamId, memberId);

        const clients = await io.in("team:" + teamId).fetchSockets();
        for (const client of clients) {
          if (client.data.session?.sub === memberId) {
            client.emit("team:kicked", { teamId });
            await client.leave("team:" + teamId);
          }
        }
        io.to("team:" + teamId).emit("team:members_changed", { teamId });
        io.to("admins").emit("admin:update", { type: "membership", teamId });
        return result;
      }),
    );

    socket.on("team:delete", (data, ack) =>
      void run(ack, async (uid) => {
        const teamId = positiveId(data?.teamId);
        const result = await service.deleteTeam(uid, teamId);
        io.to("team:" + teamId).emit("team:deleted", { teamId });
        const clients = await io.in("team:" + teamId).fetchSockets();
        for (const client of clients) {
          await client.leave("team:" + teamId);
        }
        io.to("admins").emit("admin:update", { type: "team_deleted", teamId });
        return result;
      }),
    );

    socket.on("admin:message_delete", (data, ack) =>
      void runAdmin(ack, async (uid) => {
        const result = await adminService.deleteMessage(uid, data?.messageId);
        io.to("team:" + result.teamId).emit("message:deleted", {
          teamId: result.teamId,
          messageId: result.id,
        });
        io.to("admins").emit("admin:update", {
          type: "message_deleted",
          teamId: result.teamId,
          messageId: result.id,
        });
        return result;
      }),
    );

    socket.on("admin:team_delete", (data, ack) =>
      void runAdmin(ack, async (uid) => {
        const result = await adminService.deleteTeam(uid, data?.teamId);
        io.to("team:" + result.id).emit("team:deleted", { teamId: result.id });
        const clients = await io.in("team:" + result.id).fetchSockets();
        for (const client of clients) await client.leave("team:" + result.id);
        io.to("admins").emit("admin:update", { type: "team_deleted", teamId: result.id });
        return result;
      }),
    );

    socket.on("admin:user_delete", (data, ack) =>
      void runAdmin(ack, async (uid) => {
        const result = await adminService.deleteUser(uid, data?.userId);
        for (const teamId of result.deletedTeamIds ?? []) {
          io.to("team:" + teamId).emit("team:deleted", { teamId });
        }
        const clients = await io.fetchSockets();
        for (const client of clients) {
          if (client.data.session?.sub === result.id) {
            client.emit("account:deleted", {});
            client.disconnect(true);
          }
        }
        io.to("admins").emit("admin:update", { type: "user_deleted", userId: result.id });
        return result;
      }),
    );
  });

  return io;
}
