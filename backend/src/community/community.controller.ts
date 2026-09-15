import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from "@nestjs/common";
import { SessionGuard } from "../auth/session.guard.js";
import { CommunityService, positiveId } from "./community.service.js";
@Controller("community")
@UseGuards(SessionGuard)
export class CommunityController {
  constructor(private readonly service: CommunityService) {}
  @Get("me") me(@Req() r: any) {
    return this.service.me(r.session.sub);
  }
  @Patch("me") profile(@Req() r: any, @Body() b: any) {
    return this.service.profile(r.session.sub, b);
  }
  @Get("teams") teams(@Req() r: any, @Query("mine") m: string) {
    return this.service.teams(r.session.sub, m === "true");
  }
  @Post("teams") create(@Req() r: any, @Body() b: any) {
    return this.service.create(r.session.sub, b);
  }
  @Post("teams/:id/join") join(@Req() r: any, @Param("id") id: string) {
    return this.service.join(r.session.sub, positiveId(id));
  }
  @Get("teams/:id/messages") history(
    @Req() r: any,
    @Param("id") id: string,
    @Query("before") before?: string,
  ) {
    return this.service.history(
      r.session.sub,
      positiveId(id),
      before ? positiveId(before) : undefined,
    );
  }
}
