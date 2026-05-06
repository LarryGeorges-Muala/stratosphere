
import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn } from 'typeorm';

@Entity('Bookings')
export class Booking {

  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  booking_id: string;

  @Column({ default: '' })
  user_id: string;

  @Column()
  user_email: string;

  @CreateDateColumn()
  registration_date: Date;

  @Column({ default: '' })
  origin: string;

  @Column({ default: 0 })
  guests: number;

  @Column({ default: false })
  breakfast: boolean;

  @Column({ type: 'timestamp', precision: 3 })
  check_in: Date;

  @Column({ default: '' })
  check_in_timestamp: string;

  @Column({ type: 'timestamp', precision: 3 })
  check_out: Date;

  @Column({ default: '' })
  check_out_timestamp: string;

  @Column({ default: 0 })
  duration: number;

  @Column({ default: '' })
  duration_text: string;

  @Column({ default: 0 })
  price: number;

  @Column({ default: '' })
  price_text: string;

}
