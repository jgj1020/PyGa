import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { DataSource } from "typeorm";
import { positiveId } from "../community/community.service.js";

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
    const [[counts], users, teams, messages] = await Promise.all([
      this.db.query(`SELECT
        (SELECT COUNT(*)::int FROM users) AS "userCount",
        (SELECT COUNT(*)::int FROM teams) AS "teamCount",
        (SELECT COUNT(*)::int FROM messages) AS "messageCount",
        (SELECT COUNT(*)::int FROM team_members) AS "membershipCount"`),
      this.db.query(`SELECT id,nickname,email,avatar,is_admin AS "isAdmin","createdAt"
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
    ]);
    return { ...counts, users, teams, messages };
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
      await em.query("DELETE FROM messages WHERE team_id=$1", [id]);
      await em.query("DELETE FROM team_members WHERE team_id=$1", [id]);
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
        await em.query("DELETE FROM messages WHERE team_id=$1", [team.id]);
        await em.query("DELETE FROM team_members WHERE team_id=$1", [team.id]);
        await em.query("DELETE FROM teams WHERE id=$1", [team.id]);
      }
      await em.query("DELETE FROM messages WHERE sender_id=$1", [id]);
      await em.query("DELETE FROM team_members WHERE user_id=$1", [id]);
      await em.query("DELETE FROM users WHERE id=$1", [id]);
    });
    return { ...user, deletedTeamIds: ownedTeams.map((t: any) => t.id) };
  }
}
