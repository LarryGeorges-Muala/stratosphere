import { IsEnum, IsNumber, IsString, IsDate } from "class-validator";

export class CreateUserDto {
  @IsString()
  title: string = '';

  @IsString()
  firstname: string = '';

  @IsString()
  surname: string = '';

  @IsString()
  email: string;

  @IsString()
  phone: string = '';

  @IsString()
  password: string = '';
}
