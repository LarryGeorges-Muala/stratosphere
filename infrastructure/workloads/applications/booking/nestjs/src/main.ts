// IMPORTANT: Make sure to import `instrument.ts` at the top of your file.
// If you're using CommonJS (CJS) syntax, use `require("./instrument.ts");`
import "./instrument";
import * as fs from 'fs/promises';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';

async function convertSentryJStoTS(){
  const SEN = process.env.SENTRY_DNS || '';
  const content = await fs.readFile('./src/instrument.js', 'utf8');
  const updatedContent = content.replace(new RegExp("process.env.SENTRY_DNS", 'g'), SEN.toString());
  await fs.writeFile('./src/instrument.ts', updatedContent, 'utf8');
}
convertSentryJStoTS();

async function bootstrap() {
  const appOptions = { cors: true };
  const app = await NestFactory.create(AppModule, appOptions);
  app.useGlobalPipes(
    new ValidationPipe(
      {
        whitelist: true,
        forbidNonWhitelisted: false,
      }
    ),
  );
  await app.listen(process.env.PORT ?? 4001);
}
bootstrap();
