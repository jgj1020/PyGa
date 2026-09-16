import { Injectable } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { User } from "./user.entity.js";

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly usersRepository: Repository<User>,
  ) {}

  findByEmail(email: string): Promise<User | null> {
    return this.usersRepository
      .createQueryBuilder("u")
      .where("lower(trim(u.email)) = lower(trim(:email))", {
        email: email.trim(),
      })
      .getOne();
  }

  findByNickname(nickname: string): Promise<User | null> {
    return this.usersRepository
      .createQueryBuilder("u")
      .where("lower(trim(u.nickname)) = lower(trim(:nickname))", {
        nickname: nickname.trim(),
      })
      .getOne();
  }

  findByEmailExact(email: string): Promise<User | null> {
    return this.usersRepository.findOne({
      where: { email: email.trim() },
    });
  }

  findById(id: number): Promise<User | null> {
    return this.usersRepository.findOne({ where: { id } });
  }

  async createUser(
    nickname: string,
    email: string,
    password: string,
  ): Promise<User> {
    const cleanNickname = nickname.trim();
    const cleanEmail = email.trim().toLowerCase();
    const adminEmail = process.env.ADMIN_EMAIL?.trim().toLowerCase();

    const user = this.usersRepository.create({
      nickname: cleanNickname,
      email: cleanEmail,
      password,
      isAdmin: adminEmail != null && cleanEmail === adminEmail,
    });

    return this.usersRepository.save(user);
  }
}
