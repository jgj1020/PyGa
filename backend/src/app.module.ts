import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { AuthModule } from "./auth/auth.module.js";
import { User } from "./users/user.entity.js";
import { CommunityModule } from "./community/community.module.js";
@Module({
  imports: [
    TypeOrmModule.forRoot({
      type: "postgres",
      host: process.env.DB_HOST ?? "localhost",
      port: Number(process.env.DB_PORT ?? 5432),
      username: process.env.DB_USER ?? "postgres",
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME ?? "pyga",
      entities: [User],
      synchronize: false,
    }),
    AuthModule,
    CommunityModule,
  ],
})
export class AppModule {}
