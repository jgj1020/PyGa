export type GameCatalogEntry = {
  key: string;
  query: string;
  acceptedNames: string[];
};

// PyGa 내부 게임명 -> RAWG 검색용 공식/대표 이름.
// 외부 게임 ID를 하드코딩하지 않고 API 검색 결과 중 이름이 충분히 일치하는 결과만 사용합니다.
export const gameCatalog: GameCatalogEntry[] = [
  { key: "League of Legends", query: "League of Legends", acceptedNames: ["League of Legends"] },
  { key: "VALORANT", query: "VALORANT", acceptedNames: ["VALORANT"] },
  { key: "배틀그라운드", query: "PUBG BATTLEGROUNDS", acceptedNames: ["PUBG: BATTLEGROUNDS", "PUBG BATTLEGROUNDS"] },
  { key: "FC Online", query: "FC Online", acceptedNames: ["FC Online", "EA SPORTS FC Online", "EA SPORTS FC ONLINE"] },
  { key: "오버워치 2", query: "Overwatch 2", acceptedNames: ["Overwatch 2"] },
  { key: "메이플스토리", query: "MapleStory", acceptedNames: ["MapleStory", "MapleStory Worlds"] },
  { key: "로스트아크", query: "Lost Ark", acceptedNames: ["Lost Ark"] },
  { key: "서든어택", query: "Sudden Attack", acceptedNames: ["Sudden Attack"] },
  { key: "던전앤파이터", query: "Dungeon Fighter Online", acceptedNames: ["Dungeon Fighter Online", "Dungeon & Fighter"] },
  { key: "마인크래프트", query: "Minecraft", acceptedNames: ["Minecraft"] },
  { key: "TFT", query: "Teamfight Tactics", acceptedNames: ["Teamfight Tactics"] },
  { key: "스타크래프트 2", query: "StarCraft II", acceptedNames: ["StarCraft II"] },
  { key: "이터널 리턴", query: "Eternal Return", acceptedNames: ["Eternal Return"] },
  { key: "레인보우 식스 시즈", query: "Rainbow Six Siege", acceptedNames: ["Tom Clancy's Rainbow Six Siege", "Rainbow Six Siege"] },
  { key: "카운터 스트라이크 2", query: "Counter-Strike 2", acceptedNames: ["Counter-Strike 2"] },
  { key: "브롤스타즈", query: "Brawl Stars", acceptedNames: ["Brawl Stars"] },
  { key: "배틀그라운드 모바일", query: "PUBG MOBILE", acceptedNames: ["PUBG MOBILE", "PUBG Mobile"] },
  { key: "리그 오브 레전드: 와일드 리프트", query: "League of Legends Wild Rift", acceptedNames: ["League of Legends: Wild Rift"] },
  { key: "TFT 모바일", query: "Teamfight Tactics", acceptedNames: ["Teamfight Tactics"] },
  { key: "원신", query: "Genshin Impact", acceptedNames: ["Genshin Impact"] },
  { key: "붕괴: 스타레일", query: "Honkai Star Rail", acceptedNames: ["Honkai: Star Rail"] },
  { key: "로블록스", query: "Roblox", acceptedNames: ["Roblox"] },
  { key: "쿠키런: 킹덤", query: "CookieRun Kingdom", acceptedNames: ["CookieRun: Kingdom", "Cookie Run: Kingdom"] },
  { key: "클래시 로얄", query: "Clash Royale", acceptedNames: ["Clash Royale"] },
  { key: "포켓몬 GO", query: "Pokemon GO", acceptedNames: ["Pokémon GO", "Pokemon GO"] },
  { key: "카트라이더 러쉬플러스", query: "KartRider Rush", acceptedNames: ["KartRider Rush+", "KartRider Rush Plus"] },
  { key: "모바일 레전드", query: "Mobile Legends Bang Bang", acceptedNames: ["Mobile Legends: Bang Bang", "Mobile Legends Bang Bang"] },
];
