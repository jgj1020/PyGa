import {
  Body,
  Controller,
  Delete,
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

  @Get("me")
  me(@Req() r: any) {
    return this.service.me(r.session.sub);
  }

  @Patch("me")
  profile(@Req() r: any, @Body() b: any) {
    return this.service.profile(r.session.sub, b);
  }

  @Get("me/games")
  gameProfiles(@Req() r: any) {
    return this.service.myGameProfiles(r.session.sub);
  }

  @Post("me/games")
  saveGameProfile(@Req() r: any, @Body() b: any) {
    return this.service.saveGameProfile(r.session.sub, b);
  }

  @Delete("me/games")
  deleteGameProfile(@Req() r: any, @Query("game") game: string) {
    return this.service.deleteGameProfile(r.session.sub, game);
  }

  @Get("players/:id")
  playerProfile(@Req() r: any, @Param("id") id: string) {
    return this.service.playerProfile(r.session.sub, positiveId(id));
  }

  @Post("reports")
  report(@Req() r: any, @Body() b: any) {
    return this.service.reportUser(r.session.sub, b);
  }

  @Get("announcements")
  announcements() {
    return this.service.announcements();
  }

  @Get("teams")
  teams(@Req() r: any, @Query("mine") m: string) {
    return this.service.teams(r.session.sub, m === "true");
  }

  @Post("teams")
  create(@Req() r: any, @Body() b: any) {
    return this.service.create(r.session.sub, b);
  }

  @Post("teams/:id/join")
  join(@Req() r: any, @Param("id") id: string, @Body() b: any) {
    return this.service.join(r.session.sub, positiveId(id), b?.code);
  }

  @Get("teams/:id/members")
  members(@Req() r: any, @Param("id") id: string) {
    return this.service.members(r.session.sub, positiveId(id));
  }

  @Get("teams/:id/messages")
  history(
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
