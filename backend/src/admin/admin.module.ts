import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module.js";
import { AdminController } from "./admin.controller.js";
import { AdminGuard } from "./admin.guard.js";
import { AdminService } from "./admin.service.js";
import { MaintenanceModule } from "../maintenance/maintenance.module.js";

@Module({
  imports: [AuthModule, MaintenanceModule],
  controllers: [AdminController],
  providers: [AdminGuard, AdminService],
  exports: [AdminService],
})
export class AdminModule {}
