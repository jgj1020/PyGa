import { Controller, Get } from "@nestjs/common";
import { GamesService } from "./games.service.js";

@Controller("games")
export class GamesController {
  constructor(private readonly games: GamesService) {}

  @Get("covers")
  covers() {
    return this.games.covers();
  }
}
