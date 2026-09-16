import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { DataSource } from "typeorm";
import { boundedText, positiveId } from "../community/community.service.js";
import { communityEvents } from "../community/events.js";

function suspensionSpec(value: unknown): { permanent: boolean; until: Date | null; label: string } {
  const key = String(value ?? "").trim();
  const now = Date.now();
  const options: Record<string, [number, string]> = {
    "1m": [60_000, "1분"],
    "1d": [86_400_000, "1일"],
    "7d": [7 * 86_400_000, "7일"],
    "30d": [30 * 86_400_000, "30일"],
    "365d": [365 * 86_400_000, "1년"],
  };
  if (key === "permanent") return { permanent: true, until: null, label: "영구" };
  if (key === "none") return { permanent: false, until: null, label: "정지 없음" };
  const option = options[key];
  if (!option) throw new BadRequestException("정지 기간을 확인해주세요.");
  return { permanent: false, until: new Date(now + option[0]), label: option[1] };
}

@Injectable()
export class AdminService {
  constructor(private readonly db: DataSource) {}

  async requireAdmin(uid: number) {
    const [user] = await this.db.query(
      'SELECT id,nickname,email,is_admin AS "isAdmin" FROM users WHERE id=$1',
      [uid],
    );
    if (!user?.isAdmin) throw new ForbiddenException("관리자 권한이 필요합니다.");
    return user;
  }

  async dashboard() {
    const [[counts], users, teams, messages, reports, announcements] = await Promise.all([
      this.db.query(`SELECT
        (SELECT COUNT(*)::int FROM users) AS "userCount",
        (SELECT COUNT(*)::int FROM teams) AS "teamCount",
        (SELECT COUNT(*)::int FROM messages) AS "messageCount",
        (SELECT COUNT(*)::int FROM team_members) AS "membershipCount",
        (SELECT COUNT(*)::int FROM reports WHERE status='pending') AS "pendingReportCount"`),
      this.db.query(`SELECT id,nickname,email,avatar,is_admin AS "isAdmin","createdAt",
          suspended_until AS "suspendedUntil",suspension_permanent AS "suspensionPermanent",
          suspension_reason AS "suspensionReason"
        FROM users ORDER BY "createdAt" DESC LIMIT 200`),
      this.db.query(`SELECT t.id,t.title,t.game,t.mode,t.style,t.mic,t.capacity,
          t.owner_id AS "ownerId",t.created_at AS "createdAt",
          t.is_private AS "isPrivate",t.access_code AS "accessCode",
          u.nickname AS "ownerName",u.email AS "ownerEmail",
          (SELECT COUNT(*)::int FROM team_members tm WHERE tm.team_id=t.id) AS "memberCount",
          (SELECT COUNT(*)::int FROM messages mm WHERE mm.team_id=t.id) AS "messageCount"
        FROM teams t JOIN users u ON u.id=t.owner_id
        ORDER BY t.id DESC LIMIT 200`),
      this.db.query(`SELECT m.id,m.team_id AS "teamId",m.sender_id AS "senderId",
          m.body,m.created_at AS "createdAt",u.nickname,u.email,
          t.title AS "teamTitle",t.game
        FROM messages m
        JOIN users u ON u.id=m.sender_id
        JOIN teams t ON t.id=m.team_id
        ORDER BY m.id DESC LIMIT 250`),
      this.db.query(`SELECT r.id,r.reporter_id AS "reporterId",r.reported_user_id AS "reportedUserId",
          r.team_id AS "teamId",r.category,r.details,r.status,r.admin_note AS "adminNote",
          r.suspension_type AS "suspensionType",r.suspension_until AS "suspensionUntil",
          r.created_at AS "createdAt",r.resolved_at AS "resolvedAt",
          reporter.nickname AS "reporterName",reporter.email AS "reporterEmail",
          target.nickname AS "reportedName",target.email AS "reportedEmail",
          t.title AS "teamTitle",t.game
        FROM reports r
        JOIN users reporter ON reporter.id=r.reporter_id
        JOIN users target ON target.id=r.reported_user_id
        LEFT JOIN teams t ON t.id=r.team_id
        ORDER BY (r.status='pending') DESC,r.id DESC LIMIT 250`),
      this.db.query(`SELECT a.id,a.title,a.message,a.kind,a.active,
          a.created_at AS "createdAt",a.expires_at AS "expiresAt",u.nickname AS "createdByName"
        FROM announcements a JOIN users u ON u.id=a.created_by
        ORDER BY a.id DESC LIMIT 100`),
    ]);
    return { ...counts, users, teams, messages, reports, announcements };
  }

  async deleteMessage(adminId: number, rawId: unknown) {
    await this.requireAdmin(adminId);
    const id = positiveId(rawId);
    const [row] = await this.db.query(
      'SELECT id,team_id AS "teamId",body FROM messages WHERE id=$1',
      [id],
    );
    if (!row) throw new NotFoundException("메시지를 찾을 수 없습니다.");
    await this.db.query("DELETE FROM messages WHERE id=$1", [id]);
    return row;
  }

  async deleteTeam(adminId: number, rawId: unknown) {
    await this.requireAdmin(adminId);
    const id = positiveId(rawId);
    const [team] = await this.db.query(
      'SELECT id,title,owner_id AS "ownerId" FROM teams WHERE id=$1',
      [id],
    );
    if (!team) throw new NotFoundException("파티를 찾을 수 없습니다.");
    await this.db.transaction(async (em) => {
      await em.query("UPDATE reports SET team_id=NULL WHERE team_id=$1", [id]);
      await em.query("DELETE FROM messages WHERE team_id=$1", [id]);
      await em.query("DELETE FROM team_members WHERE team_id=$1", [id]);
      await em.query("DELETE FROM team_bans WHERE team_id=$1", [id]);
      await em.query("DELETE FROM teams WHERE id=$1", [id]);
    });
    return team;
  }

  async deleteUser(adminId: number, rawId: unknown) {
    await this.requireAdmin(adminId);
    const id = positiveId(rawId);
    if (id === adminId) {
      throw new BadRequestException("현재 로그인한 관리자 계정은 삭제할 수 없습니다.");
    }
    const [user] = await this.db.query(
      'SELECT id,nickname,email,is_admin AS "isAdmin" FROM users WHERE id=$1',
      [id],
    );
    if (!user) throw new NotFoundException("회원을 찾을 수 없습니다.");
    if (user.isAdmin) {
      throw new BadRequestException("다른 관리자 계정은 이 화면에서 삭제할 수 없습니다.");
    }

    const ownedTeams = await this.db.query(
      'SELECT id,title FROM teams WHERE owner_id=$1 ORDER BY id',
      [id],
    );
    await this.db.transaction(async (em) => {
      for (const team of ownedTeams) {
        await em.query("UPDATE reports SET team_id=NULL WHERE team_id=$1", [team.id]);
        await em.query("DELETE FROM messages WHERE team_id=$1", [team.id]);
        await em.query("DELETE FROM team_members WHERE team_id=$1", [team.id]);
        await em.query("DELETE FROM team_bans WHERE team_id=$1", [team.id]);
        await em.query("DELETE FROM teams WHERE id=$1", [team.id]);
      }
      await em.query("DELETE FROM reports WHERE reporter_id=$1 OR reported_user_id=$1", [id]);
      await em.query("UPDATE reports SET resolved_by=NULL WHERE resolved_by=$1", [id]);
      await em.query("DELETE FROM user_game_profiles WHERE user_id=$1", [id]);
      await em.query("DELETE FROM team_bans WHERE user_id=$1 OR created_by=$1", [id]);
      await em.query("DELETE FROM messages WHERE sender_id=$1", [id]);
      await em.query("DELETE FROM team_members WHERE user_id=$1", [id]);
      await em.query("DELETE FROM users WHERE id=$1", [id]);
    });
    return { ...user, deletedTeamIds: ownedTeams.map((t: any) => t.id) };
  }

  async createAnnouncement(adminId: number, data: any) {
    await this.requireAdmin(adminId);
    const title = boundedText(data?.title, 80, 2);
    const message = boundedText(data?.message, 1000, 2);
    const kind = String(data?.kind ?? "notice");
    if (!['notice', 'maintenance_soon', 'maintenance', 'maintenance_done'].includes(kind)) {
      throw new BadRequestException("공지 종류를 확인해주세요.");
    }

    const [row] = await this.db.transaction(async (em) => {
      if (kind === 'maintenance' || kind === 'maintenance_done') {
        await em.query(
          "UPDATE announcements SET active=false WHERE active=true AND kind IN ('maintenance_soon','maintenance')",
        );
      }
      const expiresAt = kind === 'maintenance_done' ? new Date(Date.now() + 60 * 60 * 1000) : null;
      const result = await em.query(
        `INSERT INTO announcements(title,message,kind,active,created_by,expires_at)
         VALUES($1,$2,$3,true,$4,$5)
         RETURNING id,title,message,kind,active,created_at AS "createdAt",expires_at AS "expiresAt"`,
        [title, message, kind, adminId, expiresAt],
      );
      return result;
    });
    communityEvents.emit("announcement:update", { type: "created", announcement: row });
    communityEvents.emit("admin:update", { type: "announcement_created", announcementId: row.id });
    return row;
  }

  async closeAnnouncement(adminId: number, rawId: unknown) {
    await this.requireAdmin(adminId);
    const id = positiveId(rawId);
    const [row] = await this.db.query(
      `UPDATE announcements SET active=false WHERE id=$1
       RETURNING id,title,kind,active`,
      [id],
    );
    if (!row) throw new NotFoundException("공지를 찾을 수 없습니다.");
    communityEvents.emit("announcement:update", { type: "closed", announcementId: id });
    communityEvents.emit("admin:update", { type: "announcement_closed", announcementId: id });
    return row;
  }

  async suspendUser(adminId: number, userIdRaw: unknown, data: any) {
    await this.requireAdmin(adminId);
    const userId = positiveId(userIdRaw);
    if (userId === adminId) throw new BadRequestException("자기 계정은 정지할 수 없습니다.");
    const spec = suspensionSpec(data?.duration);
    const reason = boundedText(data?.reason ?? "운영 정책 위반", 300, 2);
    const [user] = await this.db.query(
      'SELECT id,is_admin AS "isAdmin" FROM users WHERE id=$1',
      [userId],
    );
    if (!user) throw new NotFoundException("회원을 찾을 수 없습니다.");
    if (user.isAdmin) throw new BadRequestException("관리자 계정은 정지할 수 없습니다.");

    await this.db.query(
      `UPDATE users SET suspension_permanent=$2,suspended_until=$3,suspension_reason=$4 WHERE id=$1`,
      [userId, spec.permanent, spec.until, reason],
    );
    communityEvents.emit("moderation:update", {
      type: "suspended",
      userId,
      duration: String(data?.duration),
      label: spec.label,
      until: spec.until,
      reason,
    });
    communityEvents.emit("admin:update", { type: "user_suspended", userId });
    return { userId, duration: data?.duration, label: spec.label, until: spec.until, reason };
  }

  async unsuspendUser(adminId: number, userIdRaw: unknown) {
    await this.requireAdmin(adminId);
    const userId = positiveId(userIdRaw);
    await this.db.query(
      `UPDATE users SET suspension_permanent=false,suspended_until=NULL,suspension_reason=NULL WHERE id=$1`,
      [userId],
    );
    communityEvents.emit("moderation:update", { type: "unsuspended", userId });
    communityEvents.emit("admin:update", { type: "user_unsuspended", userId });
    return { userId };
  }

  async resolveReport(adminId: number, reportIdRaw: unknown, data: any) {
    await this.requireAdmin(adminId);
    const reportId = positiveId(reportIdRaw);
    const [report] = await this.db.query(
      `SELECT id,reported_user_id AS "reportedUserId",status FROM reports WHERE id=$1`,
      [reportId],
    );
    if (!report) throw new NotFoundException("신고를 찾을 수 없습니다.");
    if (report.status === 'resolved') throw new BadRequestException("이미 처리 완료된 신고입니다.");

    const duration = String(data?.duration ?? 'none');
    const adminNote = data?.adminNote == null || String(data.adminNote).trim() === ''
      ? null
      : boundedText(String(data.adminNote), 500, 1);
    const spec = suspensionSpec(duration);

    await this.db.transaction(async (em) => {
      if (duration !== 'none') {
        const reason = `신고 처리: ${adminNote ?? '운영 정책 위반'}`;
        await em.query(
          `UPDATE users SET suspension_permanent=$2,suspended_until=$3,suspension_reason=$4 WHERE id=$1`,
          [report.reportedUserId, spec.permanent, spec.until, reason],
        );
      }
      await em.query(
        `UPDATE reports SET status='resolved',admin_note=$2,suspension_type=$3,
          suspension_until=$4,resolved_by=$5,resolved_at=now() WHERE id=$1`,
        [reportId, adminNote, duration, spec.until, adminId],
      );
    });

    if (duration !== 'none') {
      communityEvents.emit("moderation:update", {
        type: "suspended",
        userId: report.reportedUserId,
        duration,
        label: spec.label,
        until: spec.until,
        reason: adminNote ?? "신고 처리",
      });
    }
    communityEvents.emit("admin:update", { type: "report_resolved", reportId });
    return { reportId, userId: report.reportedUserId, duration, label: spec.label, until: spec.until };
  }
}
