import { NestFactory } from "@nestjs/core";
import { ValidationPipe } from "@nestjs/common";
import { json } from "express";
import { AppModule } from "./app.module.js";
import { realtime } from "./community/realtime.js";

function createCorsOriginChecker() {
  const configuredOrigins = (process.env.ALLOWED_ORIGINS ?? "")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);

  return (
    origin: string | undefined,
    callback: (error: Error | null, allow?: boolean) => void,
  ) => {
    if (!origin) {
      callback(null, true);
      return;
    }

    // Flutter web 개발 서버의 랜덤 포트를 모두 허용합니다.
    const isLocalDev = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i.test(
      origin,
    );

    if (isLocalDev || configuredOrigins.includes(origin)) {
      callback(null, true);
      return;
    }

    callback(new Error(`허용되지 않은 Origin입니다: ${origin}`), false);
  };
}

async function bootstrap() {
  if (!process.env.DB_PASSWORD) throw new Error("DB_PASSWORD를 설정해주세요.");

  const app = await NestFactory.create(AppModule, { bodyParser: false });
  const corsOrigin = createCorsOriginChecker();

  app.use(json({ limit: "3mb" }));
  app.enableCors({
    origin: corsOrigin,
    credentials: false,
  });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

  const io = realtime(app, corsOrigin);
  process.on("SIGTERM", () => {
    io.close();
    void app.close();
  });

  const port = Number(process.env.PORT ?? 3000);
  // localhost/127.0.0.1 해석 차이 때문에 웹에서 접속이 막히지 않도록
  // 모든 로컬 인터페이스에서 수신합니다.
  await app.listen(port, process.env.HOST ?? "0.0.0.0");
  console.log(`PyGa backend ready: http://127.0.0.1:${port}`);
}

await bootstrap();
