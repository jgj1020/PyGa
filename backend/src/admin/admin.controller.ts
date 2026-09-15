import { Controller, Get, Req, UseGuards } from "@nestjs/common";
import { AdminGuard } from "./admin.guard.js";
import { AdminService } from "./admin.service.js";

@Controller("admin")
@UseGuards(AdminGuard)
export class AdminController {
  constructor(private readonly service: AdminService) {}

  @Get("dashboard")
  dashboard(@Req() _req: any) {
    return this.service.dashboard();
  }
}
