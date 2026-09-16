import {
  CanActivate,
  ExecutionContext,
  Injectable,
  ServiceUnavailableException,
} from "@nestjs/common";
import { MaintenanceService } from "./maintenance.service.js";

@Injectable()
export class MaintenanceGuard implements CanActivate {
  constructor(private readonly maintenance: MaintenanceService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    if (context.getType() !== "http") return true;

    const request = context.switchToHttp().getRequest<any>();
    const path = String(request.originalUrl ?? request.url ?? "").split("?")[0];

    // 점검 상태 확인과 관리자 복구 동선은 항상 열어 둡니다.
    if (
      path === "/" ||
      path === "/maintenance/status" ||
      path === "/auth/admin/login" ||
      path.startsWith("/admin/") ||
      path === "/admin"
    ) {
      return true;
    }

    const status = await this.maintenance.status();
    if (!status.active) return true;

    throw new ServiceUnavailableException({
      code: "MAINTENANCE",
      message: status.message ?? "현재 PyGa 점검 중입니다. 점검 종료 후 다시 이용해주세요.",
      maintenance: status,
    });
  }
}
