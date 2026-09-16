import { Module } from "@nestjs/common";
import { APP_GUARD } from "@nestjs/core";
import { MaintenanceController } from "./maintenance.controller.js";
import { MaintenanceGuard } from "./maintenance.guard.js";
import { MaintenanceService } from "./maintenance.service.js";

@Module({
  controllers: [MaintenanceController],
  providers: [
    MaintenanceService,
    { provide: APP_GUARD, useClass: MaintenanceGuard },
  ],
  exports: [MaintenanceService],
})
export class MaintenanceModule {}
