import { NestFactory } from "@nestjs/core";
import { ValidationPipe } from "@nestjs/common";
import { json } from "express";
import { AppModule } from "./app.module.js";
import { realtime } from "./community/realtime.js";
async function bootstrap() {
  if (!process.env.DB_PASSWORD) throw new Error("DB_PASSWORD를 설정해주세요.");
  const app = await NestFactory.create(AppModule, { bodyParser: false });
  const origins = (
    process.env.ALLOWED_ORIGINS ?? "http://localhost:5173,http://127.0.0.1:5173"
  ).split(",");
  app.use(json({ limit: "3mb" }));
  app.enableCors({ origin: origins });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  const io = realtime(app, origins);
  process.on("SIGTERM", () => {
    io.close();
    void app.close();
  });
  await app.listen(
    Number(process.env.PORT ?? 3000),
    process.env.HOST ?? "127.0.0.1",
  );
}
await bootstrap();
