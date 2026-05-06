import { IsEnum, IsNumber, IsString, IsDate, IsBoolean } from "class-validator";

export class CreateBookingDto {
  @IsString()
  booking_id: string;

  @IsString()
  user_email: string;

  @IsString()
  origin: string = '';

  @IsNumber()
  guests: number = 0;

  @IsBoolean()
  breakfast: boolean = false;

  @IsDate()
  check_in: Date;

  @IsString()
  check_in_timestamp: string = '';

  @IsDate()
  check_out: Date;

  @IsString()
  check_out_timestamp: string = '';

  @IsNumber()
  duration: number = 0;

  @IsString()
  duration_text: string = '';

  @IsNumber()
  price: number = 0;

  @IsString()
  price_text: string = '';
}
