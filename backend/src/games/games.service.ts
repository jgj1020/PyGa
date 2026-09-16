import { Injectable } from "@nestjs/common";
import { gameCatalog, type GameCatalogEntry } from "./game-catalog.js";

type RawgGame = {
  id: number;
  name: string;
  slug?: string;
  background_image?: string | null;
};

type CoverResult = {
  game: string;
  providerName: string;
  providerId: string;
  coverUrl: string;
};

type CachedCover = {
  value: CoverResult | null;
  expiresAt: number;
};

@Injectable()
export class GamesService {
  private readonly cache = new Map<string, CachedCover>();

  private normalize(value: string): string {
    return value
      .normalize("NFKD")
      .toLowerCase()
      .replace(/pokémon/g, "pokemon")
      .replace(/[^a-z0-9가-힣]+/g, "")
      .trim();
  }

  private scoreCandidate(entry: GameCatalogEntry, candidate: RawgGame): number {
    const name = this.normalize(candidate.name);
    const accepted = entry.acceptedNames.map((item) => this.normalize(item));
    const query = this.normalize(entry.query);

    if (accepted.includes(name)) return 1000;
    if (name === query) return 980;

    let best = 0;
    for (const alias of accepted) {
      if (name.startsWith(alias) || alias.startsWith(name)) best = Math.max(best, 820);
      if (name.includes(alias) || alias.includes(name)) best = Math.max(best, 760);
    }
    if (name.includes(query) || query.includes(name)) best = Math.max(best, 700);
    return best;
  }

  private async search(entry: GameCatalogEntry, apiKey: string, exact: boolean): Promise<RawgGame[]> {
    const url = new URL("https://api.rawg.io/api/games");
    url.searchParams.set("key", apiKey);
    url.searchParams.set("search", entry.query);
    url.searchParams.set("page_size", "10");
    url.searchParams.set("search_exact", exact ? "true" : "false");
    url.searchParams.set("exclude_additions", "true");

    const response = await fetch(url);
    if (!response.ok) return [];
    const body = (await response.json()) as { results?: RawgGame[] };
    return body.results ?? [];
  }

  private async findCover(entry: GameCatalogEntry, apiKey: string): Promise<CoverResult | null> {
    const cached = this.cache.get(entry.key);
    if (cached && cached.expiresAt > Date.now()) return cached.value;

    try {
      let candidates = await this.search(entry, apiKey, true);

      // RAWG의 exact 검색이 결과를 주지 않는 게임도 있어 한 번만 일반 검색으로 보완합니다.
      // 단, 아래 점수 검증을 통과한 이름만 사용하므로 엉뚱한 커버는 채택하지 않습니다.
      if (candidates.length === 0) {
        candidates = await this.search(entry, apiKey, false);
      }

      const ranked = candidates
        .filter((candidate) => Boolean(candidate.background_image))
        .map((candidate) => ({ candidate, score: this.scoreCandidate(entry, candidate) }))
        .sort((a, b) => b.score - a.score);

      const selected = ranked.find((row) => row.score >= 700)?.candidate;
      const value = selected?.background_image
        ? {
            game: entry.key,
            providerName: selected.name,
            providerId: String(selected.id),
            coverUrl: selected.background_image,
          }
        : null;

      this.cache.set(entry.key, {
        value,
        expiresAt: Date.now() + 24 * 60 * 60 * 1000,
      });
      return value;
    } catch {
      return null;
    }
  }

  async covers() {
    const apiKey = process.env.RAWG_API_KEY?.trim();
    if (!apiKey) {
      return {
        provider: "RAWG",
        configured: false,
        covers: [],
        unresolved: gameCatalog.map((entry) => entry.key),
      };
    }

    // 외부 API에 한 번에 너무 많은 요청을 보내지 않도록 4개씩 처리합니다.
    const rows: CoverResult[] = [];
    for (let i = 0; i < gameCatalog.length; i += 4) {
      const batch = gameCatalog.slice(i, i + 4);
      const resolved = await Promise.all(batch.map((entry) => this.findCover(entry, apiKey)));
      for (const value of resolved) {
        if (value) rows.push(value);
      }
    }

    return {
      provider: "RAWG",
      configured: true,
      covers: rows,
      unresolved: gameCatalog
        .filter((entry) => !rows.some((row) => row.game === entry.key))
        .map((entry) => entry.key),
    };
  }
}
