
import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn } from 'typeorm';

@Entity()
export class Users {

  @PrimaryGeneratedColumn()
  id: number;

  @Column({ default: '' })
  title: string;

  @Column({ default: '' })
  firstname: string;

  @Column({ default: '' })
  surname: string;

  @Column()
  email: string;

  @Column({ default: '' })
  phone: string;

  @Column({ default: '' })
  password: string;

  @CreateDateColumn()
  registration_date: Date;

}
