import { Module } from '@nestjs/common';
import { BookingController } from './booking.controller';
import { BookingService } from './booking.service';
import { HelpersModules } from './_helpers.modules';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Booking } from './entities/booking.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([Booking]),
  ],
  controllers: [BookingController],
  providers: [BookingService, HelpersModules],
})
export class BookingModule {}
