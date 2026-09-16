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
      .where("lower(u.email) = lower(:email)", { email: email.trim() })
      .getOne();
  }

  findById(id: number): Promise<User | null> {
    return this.usersRepository.findOne({ where: { id } });
  }

  async createUser(
    nickname: string,
    email: string,
    password: string,
  ): Promise<User> {
    const adminEmail = process.env.ADMIN_EMAIL?.trim().toLowerCase();
    const user = this.usersRepository.create({
      nickname,
      email,
      password,
      isAdmin: adminEmail != null && email.trim().toLowerCase() === adminEmail,
    });
    return this.usersRepository.save(user);
  }
}
