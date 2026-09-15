import { IsEmail, IsString, Length, MinLength } from "class-validator";

export class RegisterDto {
  @IsString()
  @Length(2, 30)
  nickname: string;

  @IsEmail()
  email: string;

  @IsString()
  @MinLength(8, { message: "비밀번호는 최소 8자입니다." })
  password: string;
}
