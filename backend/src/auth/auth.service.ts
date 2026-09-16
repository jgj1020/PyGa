import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import * as bcrypt from "bcrypt";
import { UsersService } from "../users/users.service.js";
import { RegisterDto } from "./dto/register.dto.js";
import { LoginDto } from "./dto/login.dto.js";
import { communityEvents } from "../community/events.js";

@Injectable()
export class AuthService {
  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
  ) {}

  private assertNotSuspended(user: any) {
    const reason = user.suspensionReason ? ` 사유: ${user.suspensionReason}` : "";
    if (user.suspensionPermanent) {
      throw new ForbiddenException(`영구 정지된 계정입니다.${reason}`);
    }
    if (user.suspendedUntil && new Date(user.suspendedUntil).getTime() > Date.now()) {
      const until = new Date(user.suspendedUntil).toLocaleString("ko-KR");
      throw new ForbiddenException(`이 계정은 ${until}까지 이용 정지 상태입니다.${reason}`);
    }
  }

  async register(registerDto: RegisterDto) {
    const { nickname, password } = registerDto;
    const email = registerDto.email.trim().toLowerCase();
    if (Buffer.byteLength(password, "utf8") > 72) {
      throw new BadRequestException(
        "비밀번호는 UTF-8 기준 72바이트 이내로 입력해주세요.",
      );
    }

    // DB 중복 확인과 bcrypt 계산을 병렬로 진행해 정상 가입 체감 시간을 줄입니다.
    const [existingUser, hashedPassword] = await Promise.all([
      this.usersService.findByEmail(email),
      bcrypt.hash(password, Number(process.env.BCRYPT_ROUNDS ?? 10)),
    ]);
    if (existingUser) {
      throw new ConflictException("이미 가입된 이메일입니다.");
    }

    const user = await this.usersService.createUser(
      nickname,
      email,
      hashedPassword,
    );

    communityEvents.emit("admin:update", { type: "user_created", userId: user.id });

    // 가입 직후 바로 사용할 수 있도록 토큰을 함께 발급합니다.
    // 별도의 로그인 왕복/비밀번호 비교가 사라져 가입 체감 시간을 줄입니다.
    const accessToken = await this.jwtService.signAsync({
      sub: user.id,
      email: user.email,
    });

    return {
      message: "회원가입이 완료되었습니다.",
      accessToken,
      user: {
        id: user.id,
        nickname: user.nickname,
        email: user.email,
        avatar: user.avatar ?? null,
        isAdmin: user.isAdmin ?? false,
        createdAt: user.createdAt,
      },
    };
  }

  private async validate(loginDto: LoginDto) {
    const email = loginDto.email.trim().toLowerCase();
    const { password } = loginDto;
    if (Buffer.byteLength(password, "utf8") > 72) {
      throw new BadRequestException(
        "비밀번호는 UTF-8 기준 72바이트 이내로 입력해주세요.",
      );
    }

    const user = await this.usersService.findByEmail(email);
    if (!user || !(await bcrypt.compare(password, user.password))) {
      throw new UnauthorizedException(
        "이메일 또는 비밀번호가 올바르지 않습니다.",
      );
    }
    this.assertNotSuspended(user);
    return user;
  }

  async login(loginDto: LoginDto) {
    const user = await this.validate(loginDto);
    const accessToken = await this.jwtService.signAsync({
      sub: user.id,
      email: user.email,
    });

    return {
      message: "로그인되었습니다.",
      accessToken,
      user: {
        id: user.id,
        nickname: user.nickname,
        email: user.email,
        avatar: user.avatar,
        isAdmin: user.isAdmin,
      },
    };
  }

  async adminLogin(loginDto: LoginDto) {
    const user = await this.validate(loginDto);
    if (!user.isAdmin) {
      throw new ForbiddenException("관리자 계정만 로그인할 수 있습니다.");
    }

    const accessToken = await this.jwtService.signAsync({
      sub: user.id,
      email: user.email,
      admin: true,
    });

    return {
      message: "관리자 로그인되었습니다.",
      accessToken,
      user: {
        id: user.id,
        nickname: user.nickname,
        email: user.email,
        isAdmin: true,
      },
    };
  }
}
