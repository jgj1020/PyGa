import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import { DataSource } from "typeorm";

function suspensionMessage(user: any): string {
  const reason = user?.suspensionReason ? ` 사유: ${user.suspensionReason}` : "";
  if (user?.suspensionPermanent) return `영구 정지된 계정입니다.${reason}`;
  if (user?.suspendedUntil) {
    const until = new Date(user.suspendedUntil);
    if (until.getTime() > Date.now()) {
      return `이 계정은 ${until.toLocaleString("ko-KR")}까지 이용 정지 상태입니다.${reason}`;
    }
  }
  return "";
}

@Injectable()
export class SessionGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly db: DataSource,
  ) {}

  async verify(token: unknown) {
    if (typeof token !== "string") {
      throw new UnauthorizedException("다시 로그인해주세요.");
    }

    let payload: any;
    try {
      payload = await this.jwt.verifyAsync(token);
    } catch {
      throw new UnauthorizedException("다시 로그인해주세요.");
    }

    if (!Number.isSafeInteger(payload.sub) || !Number.isInteger(payload.exp)) {
      throw new UnauthorizedException("다시 로그인해주세요.");
    }

    const [user] = await this.db.query(
      `SELECT id,
        suspended_until AS "suspendedUntil",
        suspension_permanent AS "suspensionPermanent",
        suspension_reason AS "suspensionReason"
       FROM users WHERE id=$1`,
      [payload.sub],
    );
    if (!user) throw new UnauthorizedException("다시 로그인해주세요.");

    const suspension = suspensionMessage(user);
    if (suspension) throw new ForbiddenException(suspension);

    return payload as { sub: number; exp: number };
  }

  async canActivate(context: ExecutionContext) {
    const req = context.switchToHttp().getRequest();
    req.session = await this.verify(
      req.headers.authorization?.replace(/^Bearer /, ""),
    );
    return true;
  }
}
