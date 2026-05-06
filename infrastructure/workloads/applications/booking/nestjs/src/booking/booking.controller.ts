import { Body, Controller, Get, Post } from '@nestjs/common';
import { BookingService } from './booking.service';

@Controller('booking')
export class BookingController {

  constructor(private readonly bookingService: BookingService) {}

  @Get()
  async health() {
    return await this.bookingService.health();
  }

  @Get('all')
  findAll() {
    return this.bookingService.findAll();
  }

  @Post('dashboard')
  async findOneSet(@Body() body: any) {
    return await this.bookingService.findOneSet(body);
  }

  @Post()
  async createBooking(@Body() body: any) {
    return await this.bookingService.createBooking(body, 'json');
  }

  @Post('session')
  async createSession(@Body() body: any) {
    const clientIP = body.accessClient;
    await this.bookingService.redisHandler(clientIP, body);
    return JSON.stringify({ message: 'Session created' });
  }

  @Post('reload')
  async fetchSession(@Body() body: any) {
    const sessionKey = body.accessClient;
    const userSession = await this.bookingService.fetchFromRedis(sessionKey);
    return JSON.stringify(userSession);
  }

  @Post('reset')
  async clearSession(@Body() body: any) {
    const sessionKey = body.accessClient;
    const userSession = await this.bookingService.clearFromRedis(sessionKey);
    return JSON.stringify(userSession);
  }

}
