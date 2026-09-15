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

  async register(registerDto: RegisterDto) {
    const { nickname, email, password } = registerDto;
    if (Buffer.byteLength(password, "utf8") > 72) {
      throw new BadRequestException(
        "비밀번호는 UTF-8 기준 72바이트 이내로 입력해주세요.",
      );
    }

    const existingUser = await this.usersService.findByEmail(email);
    if (existingUser) {
      throw new ConflictException("이미 가입된 이메일입니다.");
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const user = await this.usersService.createUser(
      nickname,
      email,
      hashedPassword,
    );

    communityEvents.emit("admin:update", { type: "user_created", userId: user.id });

    return {
      message: "회원가입이 완료되었습니다.",
      user: {
        id: user.id,
        nickname: user.nickname,
        email: user.email,
        createdAt: user.createdAt,
      },
    };
  }

  private async validate(loginDto: LoginDto) {
    const { email, password } = loginDto;
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
