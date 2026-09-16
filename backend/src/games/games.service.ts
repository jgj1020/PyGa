import { Injectable } from "@nestjs/common";
import { gameCatalog, type GameCatalogEntry } from "./game-catalog.js";

type RawgGame = {
  id: number;
  name: string;
  slug?: string;
  background_image?: string | null;
  short_screenshots?: Array<{ id?: number; image?: string | null }>;
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

  private imageOf(game: RawgGame): string | null {
    if (game.background_image?.startsWith("http")) return game.background_image;
    const screenshot = game.short_screenshots?.find((item) => item.image?.startsWith("http"))?.image;
    return screenshot ?? null;
  }

  private scoreCandidate(entry: GameCatalogEntry, candidate: RawgGame): number {
    const name = this.normalize(candidate.name);
    const accepted = entry.acceptedNames.map((item) => this.normalize(item));
    const queries = entry.queries.map((item) => this.normalize(item));

    if (accepted.includes(name)) return 1000;
    if (queries.includes(name)) return 980;

    let best = 0;
    for (const alias of [...accepted, ...queries]) {
      if (!alias || !name) continue;
      if (name.startsWith(alias) || alias.startsWith(name)) best = Math.max(best, 850);
      if (name.includes(alias) || alias.includes(name)) best = Math.max(best, 790);
    }
    return best;
  }

  private async search(query: string, apiKey: string, exact: boolean): Promise<RawgGame[]> {
    const url = new URL("https://api.rawg.io/api/games");
    url.searchParams.set("key", apiKey);
    url.searchParams.set("search", query);
    url.searchParams.set("page_size", "15");
    url.searchParams.set("search_exact", exact ? "true" : "false");
    url.searchParams.set("exclude_additions", "true");

    const response = await fetch(url, { signal: AbortSignal.timeout(8000) });
    if (!response.ok) return [];
    const body = (await response.json()) as { results?: RawgGame[] };
    return body.results ?? [];
  }

  private pick(entry: GameCatalogEntry, candidates: RawgGame[]): RawgGame | null {
    const ranked = candidates
      .filter((candidate) => Boolean(this.imageOf(candidate)))
      .map((candidate) => ({ candidate, score: this.scoreCandidate(entry, candidate) }))
      .sort((a, b) => b.score - a.score);

    return ranked.find((row) => row.score >= 790)?.candidate ?? null;
  }

  private async findCover(entry: GameCatalogEntry, apiKey: string): Promise<CoverResult | null> {
    const cached = this.cache.get(entry.key);
    if (cached && cached.expiresAt > Date.now()) return cached.value;

    try {
      let selected: RawgGame | null = null;

      // 1) 대표 이름들을 exact 검색합니다.
      for (const query of entry.queries) {
        const exactCandidates = await this.search(query, apiKey, true);
        selected = this.pick(entry, exactCandidates);
        if (selected) break;
      }

      // 2) exact 결과가 있었더라도 적절한 게임/이미지를 못 찾았으면 일반 검색을 다시 합니다.
      if (!selected) {
        for (const query of entry.queries) {
          const looseCandidates = await this.search(query, apiKey, false);
          selected = this.pick(entry, looseCandidates);
          if (selected) break;
        }
      }

      const coverUrl = selected ? this.imageOf(selected) : null;
      const value = selected && coverUrl
        ? {
            game: entry.key,
            providerName: selected.name,
            providerId: String(selected.id),
            coverUrl,
          }
        : null;

      // 성공 결과는 하루 캐시, 실패 결과는 10분만 캐시해서 RAWG 데이터가 잠시 비었을 때 빨리 재시도합니다.
      this.cache.set(entry.key, {
        value,
        expiresAt: Date.now() + (value ? 24 * 60 * 60 * 1000 : 10 * 60 * 1000),
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

    // 외부 API 과부하/요청 제한을 피하기 위해 3개씩 처리합니다.
    const rows: CoverResult[] = [];
    for (let i = 0; i < gameCatalog.length; i += 3) {
      const batch = gameCatalog.slice(i, i + 3);
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
