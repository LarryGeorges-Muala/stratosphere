import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  NotImplementedException,
  Param,
  Patch,
  Post,
  Request,
  UseGuards
} from '@nestjs/common';
import { UsersService } from './users.service';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { AuthGuard } from './guards/auth.guard';

@Controller('users')
export class UsersController {

  constructor(private readonly usersService: UsersService) {}

  @Post()
  async create(@Body() CreateUserDto: CreateUserDto) {
    return await this.usersService.create(CreateUserDto);
  }

  @Get()
  findAll() {
    return this.usersService.findAll();
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.usersService.findOne(+id);
  }

  @Post('verify')
  findOneByEmail(@Body() input: { email: string }) {
    return this.usersService.findOneByEmail(input.email);
  }

  @Post('reset')
  async resetPassword(@Body() body: any) {
    return this.usersService.resetPassword(body);
  }

  @UseGuards(AuthGuard)
  @Post('profile')
  async updateProfile(@Body() body: any) {
    return this.usersService.updateProfile(body);
  }

  @Post('login')
  async login(@Body() body: any) {
    return this.usersService.login(body);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() UpdateUserDto: UpdateUserDto) {
    return this.usersService.update(+id, UpdateUserDto);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.usersService.remove(+id);
  }

}
