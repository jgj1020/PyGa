import { Controller, Get } from "@nestjs/common";
import { MaintenanceService } from "./maintenance.service.js";

@Controller("maintenance")
export class MaintenanceController {
  constructor(private readonly maintenance: MaintenanceService) {}

  @Get("status")
  status() {
    return this.maintenance.status();
  }
}
