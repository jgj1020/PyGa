import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import { DataSource } from "typeorm";

@Injectable()
export class AdminGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly db: DataSource,
  ) {}

  async canActivate(context: ExecutionContext) {
    const req = context.switchToHttp().getRequest();
    const raw = req.headers.authorization?.replace(/^Bearer /, "");
    try {
      if (typeof raw !== "string") throw new Error();
      const payload = await this.jwt.verifyAsync(raw);
      if (!Number.isSafeInteger(payload.sub)) throw new Error();
      const [user] = await this.db.query(
        "SELECT id,nickname,email,is_admin AS \"isAdmin\" FROM users WHERE id=$1",
        [payload.sub],
      );
      if (!user?.isAdmin) throw new Error();
      req.admin = user;
      return true;
    } catch {
      throw new UnauthorizedException("관리자 로그인이 필요합니다.");
    }
  }
}
