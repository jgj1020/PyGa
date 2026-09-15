import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import { DataSource } from "typeorm";
@Injectable()
export class SessionGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly db: DataSource,
  ) {}
  async verify(token: unknown) {
    try {
      if (typeof token !== "string") throw new Error();
      const p = await this.jwt.verifyAsync(token);
      if (!Number.isSafeInteger(p.sub) || !Number.isInteger(p.exp))
        throw new Error();
      if (
        !(await this.db.query("SELECT id FROM users WHERE id=$1", [p.sub]))
          .length
      )
        throw new Error();
      return p as { sub: number; exp: number };
    } catch {
      throw new UnauthorizedException("다시 로그인해주세요.");
    }
  }
  async canActivate(context: ExecutionContext) {
    const req = context.switchToHttp().getRequest();
    req.session = await this.verify(
      req.headers.authorization?.replace(/^Bearer /, ""),
    );
    return true;
  }
}
