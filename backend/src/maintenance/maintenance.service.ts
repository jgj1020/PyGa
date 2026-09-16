import { Injectable } from "@nestjs/common";
import { DataSource } from "typeorm";

export type MaintenanceStatus = {
  active: boolean;
  id?: number;
  title?: string;
  message?: string;
  startedAt?: string;
};

@Injectable()
export class MaintenanceService {
  private cached: { value: MaintenanceStatus; expiresAt: number } | null = null;

  constructor(private readonly db: DataSource) {}

  invalidate() {
    this.cached = null;
  }

  async status(force = false): Promise<MaintenanceStatus> {
    if (!force && this.cached && this.cached.expiresAt > Date.now()) {
      return this.cached.value;
    }

    const [row] = await this.db.query(
      `SELECT id,title,message,created_at AS "startedAt"
       FROM announcements
       WHERE active=true
         AND kind='maintenance'
         AND (expires_at IS NULL OR expires_at > NOW())
       ORDER BY id DESC
       LIMIT 1`,
    );

    const value: MaintenanceStatus = row
      ? {
          active: true,
          id: Number(row.id),
          title: String(row.title ?? "PyGa 점검 중"),
          message: String(row.message ?? "서비스 점검이 진행 중입니다."),
          startedAt: row.startedAt ? new Date(row.startedAt).toISOString() : undefined,
        }
      : { active: false };

    // 요청마다 DB를 두드리지 않되 점검 시작/종료는 최대 1초 안에 반영합니다.
    this.cached = { value, expiresAt: Date.now() + 1000 };
    return value;
  }
}
