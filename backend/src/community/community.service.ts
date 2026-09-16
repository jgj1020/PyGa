import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { DataSource } from "typeorm";
import sharp from "sharp";
import { communityEvents } from "./events.js";

export function positiveId(value: unknown): number {
  const n = Number(value);
  if (!Number.isSafeInteger(n) || n < 1) {
    throw new BadRequestException("잘못된 번호입니다.");
  }
  return n;
}

export function boundedText(value: unknown, max: number, min = 1): string {
  if (
    typeof value !== "string" ||
    value.trim().length < min ||
    value.trim().length > max
  ) {
    throw new BadRequestException(`${min}~${max}자로 입력해주세요.`);
  }
  return value.trim();
}

@Injectable()
export class CommunityService {
  constructor(private readonly db: DataSource) {}

  async me(uid: number) {
    const [u] = await this.db.query(
      `SELECT id,nickname,email,avatar,is_admin AS "isAdmin","createdAt",
        suspended_until AS "suspendedUntil",
        suspension_permanent AS "suspensionPermanent"
       FROM users WHERE id=$1`,
      [uid],
    );
    if (!u) throw new NotFoundException();
    return u;
  }

  async profile(uid: number, data: any) {
    const nickname = boundedText(data.nickname, 30, 2);
    let avatar: string | null | undefined;

    const [nicknameOwner] = await this.db.query(
      `SELECT id
       FROM users
       WHERE id<>$1 AND lower(trim(nickname))=lower(trim($2))
       LIMIT 1`,
      [uid, nickname],
    );

    if (nicknameOwner) {
      throw new ConflictException("이미 사용 중인 닉네임입니다.");
    }

    if (data.avatar === null) avatar = null;
    else if (data.avatar !== undefined) {
      if (
        typeof data.avatar !== "string" ||
        data.avatar.length > 2800000 ||
        !/^data:image\/(png|jpeg|webp);base64,[A-Za-z0-9+/=]+$/.test(
          data.avatar,
        )
      ) {
        throw new BadRequestException(
          "2MB 이하 PNG/JPEG/WebP 사진을 선택해주세요.",
        );
      }

      try {
        const input = Buffer.from(data.avatar.split(",")[1], "base64");
        if (input.length > 2 * 1024 * 1024) throw new Error();

        const photo = await sharp(input, { limitInputPixels: 16000000 })
          .rotate()
          .resize(192, 192, { fit: "cover" })
          .jpeg({ quality: 80 })
          .toBuffer();

        avatar = "data:image/jpeg;base64," + photo.toString("base64");
      } catch {
        throw new BadRequestException(
          "사진을 읽을 수 없습니다. 작은 PNG/JPEG/WebP 사진으로 다시 시도해주세요.",
        );
      }
    }

    try {
      if (avatar === undefined) {
        await this.db.query("UPDATE users SET nickname=$2 WHERE id=$1", [
          uid,
          nickname,
        ]);
      } else {
        await this.db.query(
          "UPDATE users SET nickname=$2,avatar=$3 WHERE id=$1",
          [uid, nickname, avatar],
        );
      }
    } catch (error: any) {
      const code = error?.code ?? error?.driverError?.code;
      if (code === "23505") {
        throw new ConflictException("이미 사용 중인 닉네임입니다.");
      }
      throw error;
    }

    return this.me(uid);
  }

  async myGameProfiles(uid: number) {
    return this.db.query(
      `SELECT game,tier,level,updated_at AS "updatedAt"
       FROM user_game_profiles WHERE user_id=$1 ORDER BY updated_at DESC,game`,
      [uid],
    );
  }

  async saveGameProfile(uid: number, data: any) {
    const game = boundedText(data?.game, 40, 2);
    const tier = data?.tier == null || String(data.tier).trim() === ""
      ? null
      : boundedText(String(data.tier), 60, 1);
    const level = data?.level == null || String(data.level).trim() === ""
      ? null
      : boundedText(String(data.level), 60, 1);
    if (!tier && !level) {
      throw new BadRequestException("티어 또는 레벨 중 하나는 입력해주세요.");
    }
    const [row] = await this.db.query(
      `INSERT INTO user_game_profiles(user_id,game,tier,level,updated_at)
       VALUES($1,$2,$3,$4,now())
       ON CONFLICT(user_id,game) DO UPDATE SET tier=EXCLUDED.tier,level=EXCLUDED.level,updated_at=now()
       RETURNING game,tier,level,updated_at AS "updatedAt"`,
      [uid, game, tier, level],
    );
    return row;
  }

  async deleteGameProfile(uid: number, game: unknown) {
    const value = boundedText(game, 40, 2);
    await this.db.query(
      "DELETE FROM user_game_profiles WHERE user_id=$1 AND game=$2",
      [uid, value],
    );
    return { game: value };
  }

  async playerProfile(requesterId: number, userId: number) {
    const [user] = await this.db.query(
      `SELECT id,nickname,avatar FROM users WHERE id=$1`,
      [userId],
    );
    if (!user) throw new NotFoundException("플레이어를 찾을 수 없습니다.");
    const gameProfiles = await this.db.query(
      `SELECT game,tier,level,updated_at AS "updatedAt"
       FROM user_game_profiles WHERE user_id=$1 ORDER BY updated_at DESC,game`,
      [userId],
    );
    return { ...user, gameProfiles, isMe: requesterId === userId };
  }

  teams(uid: number, mine: boolean) {
    return this.db.query(
      `SELECT t.id,t.title,t.game,t.mode,t.style,t.mic,t.capacity,t.owner_id,t.created_at,
        t.is_private AS "isPrivate",
        CASE WHEN t.owner_id=$1 THEN t.access_code ELSE NULL END AS "accessCode",
        u.nickname AS "ownerName",u.avatar AS "ownerAvatar",
        gp.tier AS "ownerTier",gp.level AS "ownerLevel",
        (SELECT COUNT(*)::int FROM team_members m WHERE m.team_id=t.id) AS "memberCount",
        EXISTS(SELECT 1 FROM team_members m WHERE m.team_id=t.id AND m.user_id=$1) AS joined,
        (t.owner_id=$1) AS "isOwner",
        CASE WHEN EXISTS(SELECT 1 FROM team_members mm WHERE mm.team_id=t.id AND mm.user_id=$1)
          THEN (SELECT COUNT(*)::int FROM messages msg
            WHERE msg.team_id=t.id
              AND msg.sender_id<>$1
              AND msg.id > COALESCE((SELECT last_read_message_id FROM team_members r WHERE r.team_id=t.id AND r.user_id=$1),0))
          ELSE 0 END AS "unreadCount"
      FROM teams t
      JOIN users u ON u.id=t.owner_id
      LEFT JOIN user_game_profiles gp ON gp.user_id=u.id AND gp.game=t.game
      WHERE ($2::boolean=false OR EXISTS(
        SELECT 1 FROM team_members m WHERE m.team_id=t.id AND m.user_id=$1
      ))
      ORDER BY t.id DESC
      LIMIT 100`,
      [uid, mine],
    );
  }

  async create(uid: number, data: any) {
    const title = boundedText(data.title, 80);
    const game = boundedText(data.game, 40);
    const mode = boundedText(data.mode, 40);
    const style = boundedText(data.style, 20);
    const capacity = positiveId(data.capacity);
    const isPrivate = data.isPrivate === true;
    const accessCode = isPrivate ? String(data.accessCode ?? "").trim() : null;

    if (capacity < 2 || capacity > 20 || typeof data.mic !== "boolean") {
      throw new BadRequestException("파티 설정을 확인해주세요.");
    }
    if (isPrivate && !/^\d{4}$/.test(accessCode ?? "")) {
      throw new BadRequestException("비공개 파티 입장 코드는 숫자 4자리로 설정해주세요.");
    }

    const created = await this.db.transaction(async (em) => {
      const [t] = await em.query(
        `INSERT INTO teams(title,game,mode,style,mic,capacity,owner_id,is_private,access_code)
         VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9)
         RETURNING id,title,game,mode,style,mic,capacity,owner_id,created_at,
           is_private AS "isPrivate",access_code AS "accessCode"`,
        [title, game, mode, style, data.mic, capacity, uid, isPrivate, accessCode],
      );
      await em.query(
        "INSERT INTO team_members(team_id,user_id,last_read_message_id) VALUES($1,$2,0)",
        [t.id, uid],
      );
      return t;
    });
    communityEvents.emit("admin:update", { type: "team_created", teamId: created.id });
    return created;
  }

  async join(uid: number, id: number, code?: unknown) {
    const joined = await this.db.transaction(async (em) => {
      const [t] = await em.query("SELECT * FROM teams WHERE id=$1 FOR UPDATE", [
        id,
      ]);
      if (!t) throw new NotFoundException("파티를 찾을 수 없습니다.");

      const [ban] = await em.query(
        `SELECT permanent,banned_until AS "bannedUntil"
         FROM team_bans WHERE team_id=$1 AND user_id=$2`,
        [id, uid],
      );
      if (ban) {
        if (ban.permanent) {
          throw new ForbiddenException("이 파티에서 영구 추방되었습니다.");
        }
        if (ban.bannedUntil && new Date(ban.bannedUntil).getTime() > Date.now()) {
          const until = new Date(ban.bannedUntil).toLocaleTimeString("ko-KR", {
            hour: "2-digit",
            minute: "2-digit",
          });
          throw new ForbiddenException(`임시 추방 상태입니다. ${until} 이후 다시 참가할 수 있습니다.`);
        }
        await em.query("DELETE FROM team_bans WHERE team_id=$1 AND user_id=$2", [id, uid]);
      }

      const members = await em.query(
        "SELECT user_id FROM team_members WHERE team_id=$1",
        [id],
      );
      if (members.some((m: any) => m.user_id === uid)) return t;
      if (t.is_private) {
        const input = typeof code === "string" ? code.trim() : "";
        if (!/^\d{4}$/.test(input) || input !== t.access_code) {
          throw new ForbiddenException("비공개 파티 입장 코드가 올바르지 않습니다.");
        }
      }
      if (members.length >= t.capacity) {
        throw new BadRequestException("모집 인원이 가득 찼습니다.");
      }

      const [latest] = await em.query(
        "SELECT COALESCE(MAX(id),0)::int AS id FROM messages WHERE team_id=$1",
        [id],
      );
      await em.query(
        "INSERT INTO team_members(team_id,user_id,last_read_message_id) VALUES($1,$2,$3)",
        [id, uid, latest?.id ?? 0],
      );
      return t;
    });
    communityEvents.emit("admin:update", { type: "membership", teamId: id });
    return joined;
  }

  async member(uid: number, id: number) {
    const [membership] = await this.db.query(
      `SELECT tm.team_id AS "teamId",tm.user_id AS "userId",tm.last_read_message_id AS "lastReadMessageId",
        t.owner_id AS "ownerId" FROM team_members tm
       JOIN teams t ON t.id=tm.team_id
       WHERE tm.team_id=$1 AND tm.user_id=$2`,
      [id, uid],
    );
    if (!membership) {
      throw new ForbiddenException("가입한 파티에서만 이용할 수 있습니다.");
    }
    return membership;
  }

  async owner(uid: number, id: number) {
    const [team] = await this.db.query(
      'SELECT id,owner_id AS "ownerId" FROM teams WHERE id=$1',
      [id],
    );
    if (!team) throw new NotFoundException("파티를 찾을 수 없습니다.");
    if (team.ownerId !== uid) {
      throw new ForbiddenException("방장만 사용할 수 있는 기능입니다.");
    }
    return team;
  }

  async members(uid: number, id: number) {
    await this.member(uid, id);
    return this.db.query(
      `SELECT u.id,u.nickname,u.avatar,tm.joined_at AS "joinedAt",
        tm.last_read_message_id AS "lastReadMessageId",
        (t.owner_id=u.id) AS "isOwner",
        gp.tier,gp.level,t.game
       FROM team_members tm
       JOIN users u ON u.id=tm.user_id
       JOIN teams t ON t.id=tm.team_id
       LEFT JOIN user_game_profiles gp ON gp.user_id=u.id AND gp.game=t.game
       WHERE tm.team_id=$1
       ORDER BY (t.owner_id=u.id) DESC,tm.joined_at ASC`,
      [id],
    );
  }

  async history(uid: number, id: number, before?: number) {
    await this.member(uid, id);
    const rows = await this.db.query(
      `SELECT m.id,m.team_id AS "teamId",m.sender_id AS "senderId",m.client_id AS "clientId",
        m.body,m.created_at AS "createdAt",u.nickname,u.avatar
       FROM messages m
       JOIN users u ON u.id=m.sender_id
       WHERE m.team_id=$1 AND ($2::int IS NULL OR m.id<$2)
       ORDER BY m.id DESC
       LIMIT 40`,
      [id, before ?? null],
    );
    return rows.reverse();
  }

  async send(uid: number, data: any) {
    const id = positiveId(data?.teamId);
    const body = boundedText(data?.body, 2000);
    if (
      typeof data?.clientId !== "string" ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
        data.clientId,
      )
    ) {
      throw new BadRequestException("새 메시지 ID가 필요합니다.");
    }

    await this.member(uid, id);
    await this.db.query(
      `INSERT INTO messages(team_id,sender_id,client_id,body) VALUES($1,$2,$3,$4)
       ON CONFLICT(sender_id,client_id) DO NOTHING`,
      [id, uid, data.clientId, body],
    );

    const [m] = await this.db.query(
      `SELECT m.id,m.team_id AS "teamId",m.sender_id AS "senderId",m.client_id AS "clientId",
        m.body,m.created_at AS "createdAt",u.nickname,u.avatar
       FROM messages m JOIN users u ON u.id=m.sender_id
       WHERE m.sender_id=$1 AND m.client_id=$2`,
      [uid, data.clientId],
    );
    if (m.teamId !== id || m.body !== body) {
      throw new BadRequestException("새 메시지 ID가 필요합니다.");
    }
    return m;
  }

  async markRead(uid: number, teamId: number, messageId: number) {
    await this.member(uid, teamId);
    const [latest] = await this.db.query(
      "SELECT COALESCE(MAX(id),0)::int AS id FROM messages WHERE team_id=$1",
      [teamId],
    );
    const safeId = Math.min(messageId, latest?.id ?? 0);
    await this.db.query(
      `UPDATE team_members
       SET last_read_message_id=GREATEST(last_read_message_id,$3)
       WHERE team_id=$1 AND user_id=$2`,
      [teamId, uid, safeId],
    );
    return { teamId, userId: uid, messageId: safeId };
  }

  async leaveTeam(uid: number, teamId: number) {
    const membership = await this.member(uid, teamId);

    if (membership.ownerId === uid) {
      throw new BadRequestException(
        "방장은 파티를 나갈 수 없습니다. 파티 삭제를 이용해주세요.",
      );
    }

    await this.db.query(
      "DELETE FROM team_members WHERE team_id=$1 AND user_id=$2",
      [teamId, uid],
    );

    communityEvents.emit("admin:update", {
      type: "membership",
      teamId,
    });

    return { teamId, userId: uid };
  }

  async kick(ownerId: number, teamId: number, memberId: number, duration: unknown) {
    await this.owner(ownerId, teamId);
    if (ownerId === memberId) {
      throw new BadRequestException("방장은 자기 자신을 추방할 수 없습니다.");
    }
    const [member] = await this.db.query(
      "SELECT user_id FROM team_members WHERE team_id=$1 AND user_id=$2",
      [teamId, memberId],
    );
    if (!member) throw new NotFoundException("해당 파티원을 찾을 수 없습니다.");

    const kind = duration === "permanent" ? "permanent" : "5m";
    const bannedUntil = kind === "5m" ? new Date(Date.now() + 5 * 60 * 1000) : null;
    await this.db.transaction(async (em) => {
      await em.query(
        `INSERT INTO team_bans(team_id,user_id,created_by,permanent,banned_until,created_at)
         VALUES($1,$2,$3,$4,$5,now())
         ON CONFLICT(team_id,user_id) DO UPDATE SET
           created_by=EXCLUDED.created_by,permanent=EXCLUDED.permanent,
           banned_until=EXCLUDED.banned_until,created_at=now()`,
        [teamId, memberId, ownerId, kind === "permanent", bannedUntil],
      );
      await em.query("DELETE FROM team_members WHERE team_id=$1 AND user_id=$2", [teamId, memberId]);
    });
    communityEvents.emit("admin:update", { type: "membership", teamId });
    return { teamId, userId: memberId, duration: kind, bannedUntil };
  }

  async reportUser(uid: number, data: any) {
    const reportedUserId = positiveId(data?.reportedUserId);
    if (reportedUserId === uid) throw new BadRequestException("본인은 신고할 수 없습니다.");
    const category = boundedText(data?.category, 30, 2);
    const details = boundedText(data?.details, 1000, 2);
    const teamId = data?.teamId == null ? null : positiveId(data.teamId);
    const [target] = await this.db.query("SELECT id FROM users WHERE id=$1", [reportedUserId]);
    if (!target) throw new NotFoundException("신고할 플레이어를 찾을 수 없습니다.");
    if (teamId != null) await this.member(uid, teamId);

    const [row] = await this.db.query(
      `INSERT INTO reports(reporter_id,reported_user_id,team_id,category,details)
       VALUES($1,$2,$3,$4,$5)
       RETURNING id,status,created_at AS "createdAt"`,
      [uid, reportedUserId, teamId, category, details],
    );
    communityEvents.emit("admin:update", { type: "report_created", reportId: row.id });
    return { ...row, message: "신고가 관리자에게 전달되었습니다." };
  }

  async announcements() {
    return this.db.query(
      `SELECT id,title,message,kind,created_at AS "createdAt",expires_at AS "expiresAt"
       FROM announcements
       WHERE active=true AND (expires_at IS NULL OR expires_at>now())
       ORDER BY id DESC LIMIT 5`,
    );
  }

  async deleteTeam(ownerId: number, teamId: number) {
    await this.owner(ownerId, teamId);
    await this.db.transaction(async (em) => {
      await em.query("DELETE FROM messages WHERE team_id=$1", [teamId]);
      await em.query("DELETE FROM team_members WHERE team_id=$1", [teamId]);
      await em.query("DELETE FROM team_bans WHERE team_id=$1", [teamId]);
      await em.query("DELETE FROM teams WHERE id=$1", [teamId]);
    });
    communityEvents.emit("admin:update", { type: "team_deleted", teamId });
    return { teamId };
  }
}
