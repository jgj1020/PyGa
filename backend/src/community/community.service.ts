import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { DataSource } from "typeorm";
import sharp from "sharp";
export function positiveId(value: unknown): number {
  const n = Number(value);
  if (!Number.isSafeInteger(n) || n < 1)
    throw new BadRequestException("잘못된 번호입니다.");
  return n;
}
export function boundedText(value: unknown, max: number, min = 1): string {
  if (
    typeof value !== "string" ||
    value.trim().length < min ||
    value.trim().length > max
  )
    throw new BadRequestException(min + "~" + max + "자로 입력해주세요.");
  return value.trim();
}
@Injectable()
export class CommunityService {
  constructor(private readonly db: DataSource) {}
  async me(uid: number) {
    const [u] = await this.db.query(
      'SELECT id,nickname,email,avatar,"createdAt" FROM users WHERE id=$1',
      [uid],
    );
    if (!u) throw new NotFoundException();
    return u;
  }
  async profile(uid: number, data: any) {
    const nickname = boundedText(data.nickname, 30, 2);
    let avatar: string | null | undefined;
    if (data.avatar === null) avatar = null;
    else if (data.avatar !== undefined) {
      if (
        typeof data.avatar !== "string" ||
        data.avatar.length > 2800000 ||
        !/^data:image\/(png|jpeg|webp);base64,[A-Za-z0-9+/=]+$/.test(
          data.avatar,
        )
      )
        throw new BadRequestException(
          "2MB 이하 PNG/JPEG/WebP 사진을 선택해주세요.",
        );
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
    if (avatar === undefined)
      await this.db.query("UPDATE users SET nickname=$2 WHERE id=$1", [
        uid,
        nickname,
      ]);
    else
      await this.db.query(
        "UPDATE users SET nickname=$2,avatar=$3 WHERE id=$1",
        [uid, nickname, avatar],
      );
    return this.me(uid);
  }
  teams(uid: number, mine: boolean) {
    return this.db.query(
      `SELECT t.*,u.nickname AS "ownerName",
   (SELECT COUNT(*)::int FROM team_members m WHERE m.team_id=t.id) AS "memberCount",
   EXISTS(SELECT 1 FROM team_members m WHERE m.team_id=t.id AND m.user_id=$1) AS joined
   FROM teams t JOIN users u ON u.id=t.owner_id
   WHERE ($2::boolean=false OR EXISTS(SELECT 1 FROM team_members m WHERE m.team_id=t.id AND m.user_id=$1))
   ORDER BY t.id DESC LIMIT 100`,
      [uid, mine],
    );
  }
  async create(uid: number, data: any) {
    const title = boundedText(data.title, 80),
      game = boundedText(data.game, 40),
      mode = boundedText(data.mode, 40),
      style = boundedText(data.style, 20);
    const capacity = positiveId(data.capacity);
    if (capacity < 2 || capacity > 20 || typeof data.mic !== "boolean")
      throw new BadRequestException();
    return this.db.transaction(async (em) => {
      const [t] = await em.query(
        "INSERT INTO teams(title,game,mode,style,mic,capacity,owner_id) VALUES($1,$2,$3,$4,$5,$6,$7) RETURNING *",
        [title, game, mode, style, data.mic, capacity, uid],
      );
      await em.query(
        "INSERT INTO team_members(team_id,user_id) VALUES($1,$2)",
        [t.id, uid],
      );
      return t;
    });
  }
  async join(uid: number, id: number) {
    return this.db.transaction(async (em) => {
      const [t] = await em.query("SELECT * FROM teams WHERE id=$1 FOR UPDATE", [
        id,
      ]);
      if (!t) throw new NotFoundException("팀을 찾을 수 없습니다.");
      const members = await em.query(
        "SELECT user_id FROM team_members WHERE team_id=$1",
        [id],
      );
      if (members.some((m: any) => m.user_id === uid)) return t;
      if (members.length >= t.capacity)
        throw new BadRequestException("모집 인원이 가득 찼습니다.");
      await em.query(
        "INSERT INTO team_members(team_id,user_id) VALUES($1,$2)",
        [id, uid],
      );
      return t;
    });
  }
  async member(uid: number, id: number) {
    if (
      !(
        await this.db.query(
          "SELECT 1 FROM team_members WHERE team_id=$1 AND user_id=$2",
          [id, uid],
        )
      ).length
    )
      throw new ForbiddenException("가입한 팀에서만 채팅할 수 있습니다.");
  }
  async history(uid: number, id: number, before?: number) {
    await this.member(uid, id);
    const rows = await this.db.query(
      `SELECT m.id,m.team_id AS "teamId",m.sender_id AS "senderId",m.client_id AS "clientId",
   m.body,m.created_at AS "createdAt",u.nickname,u.avatar FROM messages m JOIN users u ON u.id=m.sender_id
   WHERE m.team_id=$1 AND ($2::int IS NULL OR m.id<$2) ORDER BY m.id DESC LIMIT 50`,
      [id, before ?? null],
    );
    return rows.reverse();
  }
  async send(uid: number, data: any) {
    const id = positiveId(data?.teamId),
      body = boundedText(data?.body, 2000);
    if (
      typeof data?.clientId !== "string" ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
        data.clientId,
      )
    )
      throw new BadRequestException();
    await this.member(uid, id);
    await this.db.query(
      `INSERT INTO messages(team_id,sender_id,client_id,body) VALUES($1,$2,$3,$4)
   ON CONFLICT(sender_id,client_id) DO NOTHING`,
      [id, uid, data.clientId, body],
    );
    const [m] = await this.db.query(
      `SELECT m.id,m.team_id AS "teamId",m.sender_id AS "senderId",m.client_id AS "clientId",
   m.body,m.created_at AS "createdAt",u.nickname,u.avatar FROM messages m JOIN users u ON u.id=m.sender_id
   WHERE m.sender_id=$1 AND m.client_id=$2`,
      [uid, data.clientId],
    );
    if (m.teamId !== id || m.body !== body)
      throw new BadRequestException("새 메시지 ID가 필요합니다.");
    return m;
  }
}
