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
import { MaintenanceService } from "../maintenance/maintenance.service.js";

@Injectable()
export class AuthService {
  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
    private readonly maintenance: MaintenanceService,
  ) {}

  private async assertServiceAvailable() {
    const status = await this.maintenance.status();
    if (status.active) {
      throw new ForbiddenException(
        status.message ??
          "현재 PyGa 점검 중입니다. 점검 종료 후 다시 이용해주세요.",
      );
    }
  }

  private assertNotSuspended(user: any) {
    const reason = user.suspensionReason
      ? ` 사유: ${user.suspensionReason}`
      : "";

    if (user.suspensionPermanent) {
      throw new ForbiddenException(`영구 정지된 계정입니다.${reason}`);
    }

    if (
      user.suspendedUntil &&
      new Date(user.suspendedUntil).getTime() > Date.now()
    ) {
      const until = new Date(user.suspendedUntil).toLocaleString("ko-KR");
      throw new ForbiddenException(
        `이 계정은 ${until}까지 이용 정지 상태입니다.${reason}`,
      );
    }
  }

  private duplicateCode(error: any): string | undefined {
    return error?.code ?? error?.driverError?.code;
  }

  private duplicateDetail(error: any): string {
    return String(
      error?.detail ??
        error?.driverError?.detail ??
        error?.constraint ??
        error?.driverError?.constraint ??
        "",
    ).toLowerCase();
  }

  private throwDuplicateError(error: any): never {
    const detail = this.duplicateDetail(error);

    if (detail.includes("email")) {
      throw new ConflictException("이미 가입된 이메일입니다.");
    }

    if (detail.includes("nickname")) {
      throw new ConflictException("이미 사용 중인 닉네임입니다.");
    }

    throw new ConflictException(
      "이미 사용 중인 이메일 또는 닉네임입니다.",
    );
  }

  async register(registerDto: RegisterDto) {
    await this.assertServiceAvailable();

    const nickname = registerDto.nickname.trim();
    const email = registerDto.email.trim().toLowerCase();
    const { password } = registerDto;

    if (Buffer.byteLength(password, "utf8") > 72) {
      throw new BadRequestException(
        "비밀번호는 UTF-8 기준 72바이트 이내로 입력해주세요.",
      );
    }

    const [existingEmail, existingNickname, hashedPassword] =
      await Promise.all([
        this.usersService.findByEmail(email),
        this.usersService.findByNickname(nickname),
        bcrypt.hash(password, Number(process.env.BCRYPT_ROUNDS ?? 10)),
      ]);

    if (existingEmail) {
      throw new ConflictException("이미 가입된 이메일입니다.");
    }

    if (existingNickname) {
      throw new ConflictException("이미 사용 중인 닉네임입니다.");
    }

    let user;
    try {
      user = await this.usersService.createUser(
        nickname,
        email,
        hashedPassword,
      );
    } catch (error: any) {
      if (this.duplicateCode(error) === "23505") {
        this.throwDuplicateError(error);
      }
      throw error;
    }

    communityEvents.emit("admin:update", {
      type: "user_created",
      userId: user.id,
    });

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
    // 로그인은 사용자가 가입할 때 저장된 이메일의 대소문자까지 정확히 일치해야 합니다.
    // 회원가입 중복 검사는 계속 대소문자를 무시하므로 Jang/jang 계정이 따로 생성되지는 않습니다.
    const email = loginDto.email.trim();
    const { password } = loginDto;

    if (Buffer.byteLength(password, "utf8") > 72) {
      throw new BadRequestException(
        "비밀번호는 UTF-8 기준 72바이트 이내로 입력해주세요.",
      );
    }

    const user = await this.usersService.findByEmailExact(email);

    if (!user || !(await bcrypt.compare(password, user.password))) {
      throw new UnauthorizedException(
        "이메일 또는 비밀번호가 올바르지 않습니다.",
      );
    }

    this.assertNotSuspended(user);
    return user;
  }

  async login(loginDto: LoginDto) {
    await this.assertServiceAvailable();
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
