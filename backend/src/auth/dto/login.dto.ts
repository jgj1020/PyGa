import { IsEmail, IsString, MinLength } from "class-validator";

export class LoginDto {
  @IsEmail()
  email: string;

  @IsString()
  @MinLength(8, { message: "비밀번호는 최소 8자입니다." })
  password: string;
}
