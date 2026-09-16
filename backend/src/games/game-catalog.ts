export type GameCatalogEntry = {
  key: string;
  queries: string[];
  acceptedNames: string[];
  slug?: string;
};

// PyGa 내부 게임명 -> RAWG 검색용 대표/대체 이름.
// 한글/약칭/서비스명 차이 때문에 검색 결과가 누락되는 것을 줄이기 위해
// 외부 ID를 하드코딩하지 않고 여러 공식/대표 이름으로 재검색합니다.
export const gameCatalog: GameCatalogEntry[] = [
  { key: "League of Legends", queries: ["League of Legends"], acceptedNames: ["League of Legends"] },
  { key: "VALORANT", queries: ["VALORANT", "Valorant"], acceptedNames: ["VALORANT", "Valorant"] },
  { key: "배틀그라운드", queries: ["PUBG BATTLEGROUNDS", "PlayerUnknown's Battlegrounds", "PUBG"], acceptedNames: ["PUBG: BATTLEGROUNDS", "PUBG BATTLEGROUNDS", "PLAYERUNKNOWN'S BATTLEGROUNDS", "PlayerUnknown's Battlegrounds"], slug: "pubg-battlegrounds" },
  { key: "FC Online", queries: ["EA SPORTS FC Online", "FC Online", "FIFA Online 4"], acceptedNames: ["FC Online", "EA SPORTS FC Online", "EA SPORTS FC ONLINE", "FIFA Online 4"], slug: "fifa-online-4" },
  { key: "오버워치 2", queries: ["Overwatch 2", "Overwatch"], acceptedNames: ["Overwatch 2", "Overwatch"] },
  { key: "메이플스토리", queries: ["MapleStory", "Maplestory"], acceptedNames: ["MapleStory", "Maplestory"] },
  { key: "로스트아크", queries: ["Lost Ark"], acceptedNames: ["Lost Ark"] },
  { key: "서든어택", queries: ["Sudden Attack", "Sudden Attack 2"], acceptedNames: ["Sudden Attack", "Sudden Attack 2"] },
  { key: "던전앤파이터", queries: ["Dungeon Fighter Online", "Dungeon and Fighter", "Dungeon & Fighter"], acceptedNames: ["Dungeon Fighter Online", "Dungeon & Fighter", "Dungeon and Fighter"] },
  { key: "마인크래프트", queries: ["Minecraft"], acceptedNames: ["Minecraft"] },
  { key: "TFT", queries: ["Teamfight Tactics"], acceptedNames: ["Teamfight Tactics"] },
  { key: "스타크래프트 2", queries: ["StarCraft II", "StarCraft 2"], acceptedNames: ["StarCraft II", "StarCraft 2"], slug: "starcraft-2" },
  { key: "이터널 리턴", queries: ["Eternal Return", "Eternal Return Black Survival"], acceptedNames: ["Eternal Return", "Eternal Return: Black Survival"] },
  { key: "레인보우 식스 시즈", queries: ["Tom Clancy's Rainbow Six Siege", "Rainbow Six Siege"], acceptedNames: ["Tom Clancy's Rainbow Six Siege", "Rainbow Six Siege"] },
  { key: "카운터 스트라이크 2", queries: ["Counter-Strike 2", "Counter Strike 2"], acceptedNames: ["Counter-Strike 2", "Counter Strike 2"] },
  { key: "브롤스타즈", queries: ["Brawl Stars"], acceptedNames: ["Brawl Stars"] },
  { key: "배틀그라운드 모바일", queries: ["PUBG MOBILE", "PUBG Mobile"], acceptedNames: ["PUBG MOBILE", "PUBG Mobile"] },
  { key: "리그 오브 레전드: 와일드 리프트", queries: ["League of Legends Wild Rift", "Wild Rift"], acceptedNames: ["League of Legends: Wild Rift", "League of Legends Wild Rift", "Wild Rift"] },
  { key: "TFT 모바일", queries: ["Teamfight Tactics"], acceptedNames: ["Teamfight Tactics"] },
  { key: "원신", queries: ["Genshin Impact"], acceptedNames: ["Genshin Impact"] },
  { key: "붕괴: 스타레일", queries: ["Honkai Star Rail", "Honkai: Star Rail"], acceptedNames: ["Honkai: Star Rail", "Honkai Star Rail"] },
  { key: "로블록스", queries: ["Roblox"], acceptedNames: ["Roblox"] },
  { key: "쿠키런: 킹덤", queries: ["CookieRun Kingdom", "Cookie Run Kingdom", "Cookie Run: Kingdom"], acceptedNames: ["CookieRun: Kingdom", "Cookie Run: Kingdom", "CookieRun Kingdom"], slug: "cookie-run-kingdom" },
  { key: "클래시 로얄", queries: ["Clash Royale"], acceptedNames: ["Clash Royale"] },
  { key: "포켓몬 GO", queries: ["Pokemon GO", "Pokémon GO"], acceptedNames: ["Pokémon GO", "Pokemon GO"] },
  { key: "카트라이더 러쉬플러스", queries: ["KartRider Rush+", "KartRider Rush Plus", "KartRider Rush"], acceptedNames: ["KartRider Rush+", "KartRider Rush Plus", "KartRider Rush"] },
  { key: "모바일 레전드", queries: ["Mobile Legends Bang Bang", "Mobile Legends: Bang Bang"], acceptedNames: ["Mobile Legends: Bang Bang", "Mobile Legends Bang Bang"] },
];
