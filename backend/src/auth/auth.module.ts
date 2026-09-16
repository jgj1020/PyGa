import { Module } from "@nestjs/common";
import { JwtModule } from "@nestjs/jwt";
import { UsersModule } from "../users/users.module.js";
import { AuthController } from "./auth.controller.js";
import { AuthService } from "./auth.service.js";
import { SessionGuard } from "./session.guard.js";
import { MaintenanceModule } from "../maintenance/maintenance.module.js";
@Module({
  imports: [
    UsersModule,
    MaintenanceModule,
    JwtModule.registerAsync({
      useFactory: () => {
        const secret = process.env.JWT_SECRET;
        if (!secret || secret.length < 32)
          throw new Error("JWT_SECRET must have at least 32 characters");
        return { secret, signOptions: { expiresIn: "1d" } };
      },
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, SessionGuard],
  exports: [JwtModule, SessionGuard],
})
export class AuthModule {}
