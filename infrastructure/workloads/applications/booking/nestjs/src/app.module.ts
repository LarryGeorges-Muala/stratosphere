import { Module } from '@nestjs/common';
import { SentryModule } from '@sentry/nestjs/setup';
import { APP_FILTER } from '@nestjs/core';
import { SentryGlobalFilter } from '@sentry/nestjs/setup';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { BookingModule } from './booking/booking.module';
import { ConfigModule } from '@nestjs/config';
import { UsersModule } from './users/users.module';
import { AuthModule } from './auth/auth.module';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Users } from './users/entities/users.entity';
import { Booking } from './booking/entities/booking.entity';

@Module({
  imports: [
    SentryModule.forRoot(),
    BookingModule,
    ConfigModule.forRoot(
      {
        isGlobal: true,
        // ignoreEnvFile: true,
      }
    ),
    UsersModule,
    AuthModule,
    TypeOrmModule.forRoot({
      type: 'mysql',
      // host: 'localhost',
      host: 'mysql',
      port: 3306,
      username: 'booking',
      password: 'booking',
      database: 'booking',
      entities: [Users, Booking],
      synchronize: true,
    }),
  ],
  controllers: [AppController],
  providers: [{provide: APP_FILTER, useClass: SentryGlobalFilter,}, AppService],
})
export class AppModule {}
