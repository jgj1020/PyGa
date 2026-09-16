import { HttpException, INestApplication } from "@nestjs/common";
import { Server } from "socket.io";
import { SessionGuard } from "../auth/session.guard.js";
import { AdminService } from "../admin/admin.service.js";
import { CommunityService, positiveId } from "./community.service.js";
import { communityEvents } from "./events.js";
import { MaintenanceService } from "../maintenance/maintenance.service.js";

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
  const maintenance = app.get(MaintenanceService);

  communityEvents.on("admin:update", (event) => {
    io.to("admins").emit("admin:update", event);
  });
  communityEvents.on("team:system_message", (message: any) => {
    if (!message?.teamId) return;
    io.to("team:" + message.teamId).emit("message:new", message);
    io.to("admins").emit("admin:message_new", message);
    io.to("admins").emit("admin:update", { type: "message", teamId: message.teamId });
  });
  communityEvents.on("notification:update", (event: any) => {
    if (!event?.userId) return;
    io.to("user:" + event.userId).emit("notification:update", event.notification ?? event);
  });
  communityEvents.on("announcement:update", async (event: any) => {
    io.emit("announcement:update", event);
    io.emit("maintenance:update", event);

    // 점검 시작 시 일반 사용자 실시간 연결도 즉시 끊어 채팅/음성 사용을 막습니다.
    if (event?.type === "created" && event?.announcement?.kind === "maintenance") {
      const clients = await io.fetchSockets();
      for (const client of clients) {
        if (client.data.session?.admin === true) continue;
        client.emit("maintenance:locked", event.announcement);
        client.disconnect(true);
      }
    }
  });
  communityEvents.on("moderation:update", async (event: any) => {
    io.to("admins").emit("admin:update", event);
    if (event?.userId) {
      io.to("user:" + event.userId).emit("moderation:update", event);
      if (event.type === "suspended") {
        const clients = await io.in("user:" + event.userId).fetchSockets();
        for (const client of clients) client.disconnect(true);
      }
    }
  });

  io.use(async (socket, next) => {
    try {
      socket.data.session = await auth.verify(socket.handshake.auth?.token);
      const status = await maintenance.status();
      if (status.active && socket.data.session?.admin !== true) {
        next(new Error(status.message ?? "현재 PyGa 점검 중입니다."));
        return;
      }
      next();
    } catch {
      next(new Error("다시 로그인해주세요."));
    }
  });

  io.on("connection", (socket) => {
    void socket.join("user:" + socket.data.session.sub);
    socket.on("disconnecting", () => {
      const teamId = socket.data.voiceTeamId;
      if (teamId) {
        socket.to("voice:" + teamId).emit("voice:peer_left", {
          teamId,
          socketId: socket.id,
          userId: socket.data.session?.sub,
        });
      }
    });
    const expires = setTimeout(
      () => socket.disconnect(true),
      Math.max(0, socket.data.session.exp * 1000 - Date.now()),
    );
    socket.on("disconnect", () => clearTimeout(expires));

    let lastSend = 0;
    const run = async (ack: any, action: (uid: number) => Promise<any>) => {
      if (typeof ack !== "function") return;
      try {
        // 연결 시 이미 JWT/정지 상태를 검증했습니다. 매 메시지마다 DB를 다시 조회하지
        // 않아 채팅 전송·읽음 처리 지연을 줄입니다. 정지 시 moderation:update로 즉시 연결을 끊습니다.
        const s = socket.data.session;
        if (!s || s.exp * 1000 <= Date.now()) {
          throw new HttpException("다시 로그인해주세요.", 401);
        }
        if (s.admin !== true) {
          const status = await maintenance.status();
          if (status.active) {
            throw new HttpException(
              status.message ?? "현재 PyGa 점검 중입니다.",
              503,
            );
          }
        }
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

    socket.on("team:leave", (data, ack) =>
      void run(ack, async (uid) => {
        const teamId = positiveId(data?.teamId);
        const result = await service.leaveTeam(uid, teamId);

        const clients = await io.in("team:" + teamId).fetchSockets();
        for (const client of clients) {
          if (client.data.session?.sub === uid) {
            if (client.rooms.has("voice:" + teamId)) {
              io.to("voice:" + teamId).except(client.id).emit(
                "voice:peer_left",
                {
                  teamId,
                  socketId: client.id,
                  userId: uid,
                },
              );
              await client.leave("voice:" + teamId);
              client.data.voiceTeamId = undefined;
            }

            await client.leave("team:" + teamId);
          }
        }

        io.to("team:" + teamId).emit("team:members_changed", { teamId });
        if (result.systemMessage) {
          io.to("team:" + teamId).emit("message:new", result.systemMessage);
          io.to("admins").emit("admin:message_new", result.systemMessage);
        }
        io.to("admins").emit("admin:update", {
          type: "membership",
          teamId,
        });

        return result;
      }),
    );

    socket.on("team:kick", (data, ack) =>
      void run(ack, async (uid) => {
        const teamId = positiveId(data?.teamId);
        const memberId = positiveId(data?.memberId);
        const result = await service.kick(uid, teamId, memberId, data?.duration);

        const clients = await io.in("team:" + teamId).fetchSockets();
        for (const client of clients) {
          if (client.data.session?.sub === memberId) {
            client.emit("team:kicked", { teamId, duration: result.duration, bannedUntil: result.bannedUntil });
            if (client.rooms.has("voice:" + teamId)) {
              io.to("voice:" + teamId).except(client.id).emit("voice:peer_left", {
                teamId,
                socketId: client.id,
                userId: memberId,
              });
              await client.leave("voice:" + teamId);
              client.data.voiceTeamId = undefined;
            }
            await client.leave("team:" + teamId);
          }
        }
        io.to("team:" + teamId).emit("team:members_changed", { teamId });
        if (result.systemMessage) {
          io.to("team:" + teamId).emit("message:new", result.systemMessage);
          io.to("admins").emit("admin:message_new", result.systemMessage);
        }
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
          if (client.rooms.has("voice:" + teamId)) {
            io.to("voice:" + teamId).except(client.id).emit("voice:peer_left", {
              teamId,
              socketId: client.id,
              userId: client.data.session?.sub,
            });
            await client.leave("voice:" + teamId);
            client.data.voiceTeamId = undefined;
          }
          await client.leave("team:" + teamId);
        }
        io.to("admins").emit("admin:update", { type: "team_deleted", teamId });
        return result;
      }),
    );

    socket.on("voice:join", (data, ack) =>
      void run(ack, async (uid) => {
        const teamId = positiveId(data?.teamId);
        await service.member(uid, teamId);
        const room = "voice:" + teamId;
        const peers = await io.in(room).fetchSockets();
        await socket.join(room);
        socket.data.voiceTeamId = teamId;
        socket.to(room).emit("voice:peer_joined", {
          teamId,
          socketId: socket.id,
          userId: uid,
        });
        return {
          teamId,
          socketId: socket.id,
          peers: peers
            .filter((peer) => peer.id !== socket.id)
            .map((peer) => ({
              socketId: peer.id,
              userId: peer.data.session?.sub,
            })),
        };
      }),
    );

    socket.on("voice:offer", (data, ack) =>
      void run(ack, async (uid) => {
        const teamId = positiveId(data?.teamId);
        await service.member(uid, teamId);
        const target = String(data?.target ?? "");
        const peer = io.sockets.sockets.get(target);
        if (!peer || !peer.rooms.has("voice:" + teamId)) {
          throw new HttpException("음성 상대를 찾을 수 없습니다.", 404);
        }
        peer.emit("voice:offer", {
          teamId,
          from: socket.id,
          userId: uid,
          sdp: data?.sdp,
        });
        return { sent: true };
      }),
    );

    socket.on("voice:answer", (data, ack) =>
      void run(ack, async (uid) => {
        const teamId = positiveId(data?.teamId);
        await service.member(uid, teamId);
        const target = String(data?.target ?? "");
        const peer = io.sockets.sockets.get(target);
        if (!peer || !peer.rooms.has("voice:" + teamId)) {
          throw new HttpException("음성 상대를 찾을 수 없습니다.", 404);
        }
        peer.emit("voice:answer", {
          teamId,
          from: socket.id,
          userId: uid,
          sdp: data?.sdp,
        });
        return { sent: true };
      }),
    );

    socket.on("voice:ice", (data, ack) =>
      void run(ack, async (uid) => {
        const teamId = positiveId(data?.teamId);
        await service.member(uid, teamId);
        const target = String(data?.target ?? "");
        const peer = io.sockets.sockets.get(target);
        if (!peer || !peer.rooms.has("voice:" + teamId)) {
          throw new HttpException("음성 상대를 찾을 수 없습니다.", 404);
        }
        peer.emit("voice:ice", {
          teamId,
          from: socket.id,
          candidate: data?.candidate,
        });
        return { sent: true };
      }),
    );

    socket.on("voice:leave", (data, ack) =>
      void run(ack, async (uid) => {
        const teamId = positiveId(data?.teamId);
        await service.member(uid, teamId);
        const room = "voice:" + teamId;
        await socket.leave(room);
        socket.data.voiceTeamId = undefined;
        socket.to(room).emit("voice:peer_left", {
          teamId,
          socketId: socket.id,
          userId: uid,
        });
        return { left: true };
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
        for (const client of clients) {
          if (client.rooms.has("voice:" + result.id)) {
            io.to("voice:" + result.id).except(client.id).emit("voice:peer_left", {
              teamId: result.id,
              socketId: client.id,
              userId: client.data.session?.sub,
            });
            await client.leave("voice:" + result.id);
            client.data.voiceTeamId = undefined;
          }
          await client.leave("team:" + result.id);
        }
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
