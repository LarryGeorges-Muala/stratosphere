import { PartialType } from '@nestjs/mapped-types';
import { CreateBookingDto } from './create-booking.dto';

export class UpdateUserDto extends PartialType(CreateBookingDto) {}
