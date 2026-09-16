import { Body, Controller, Delete, Get, Param, Patch, Post, Req, UseGuards } from "@nestjs/common";
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

  @Post("announcements")
  announcement(@Req() req: any, @Body() body: any) {
    return this.service.createAnnouncement(req.admin.id, body);
  }

  @Patch("announcements/:id/close")
  closeAnnouncement(@Req() req: any, @Param("id") id: string) {
    return this.service.closeAnnouncement(req.admin.id, id);
  }

  @Delete("announcements/:id")
  deleteAnnouncement(@Req() req: any, @Param("id") id: string) {
    return this.service.deleteAnnouncement(req.admin.id, id);
  }

  @Delete("announcements")
  clearAnnouncements(@Req() req: any) {
    return this.service.clearAnnouncements(req.admin.id);
  }

  @Patch("reports/:id/resolve")
  resolveReport(@Req() req: any, @Param("id") id: string, @Body() body: any) {
    return this.service.resolveReport(req.admin.id, id, body);
  }

  @Post("users/:id/suspend")
  suspend(@Req() req: any, @Param("id") id: string, @Body() body: any) {
    return this.service.suspendUser(req.admin.id, id, body);
  }

  @Post("users/:id/unsuspend")
  unsuspend(@Req() req: any, @Param("id") id: string) {
    return this.service.unsuspendUser(req.admin.id, id);
  }
}
