import * as Sentry from "@sentry/nestjs";
import querystring from 'querystring';
import { createClient } from 'redis';
import amqp from 'amqplib';
import { HelpersModules } from './_helpers.modules';

import { Injectable } from '@nestjs/common';
import { Repository } from 'typeorm';
import { InjectRepository } from '@nestjs/typeorm';
import { Booking } from "./entities/booking.entity";

@Injectable()
export class BookingService {
  constructor(
    @InjectRepository(Booking)
    private readonly bookingRepository: Repository<Booking>,
    private readonly helpersModules: HelpersModules,
  ) {}

  /*
  Health Endpoint
  */
  async health() {
    return JSON.stringify({
      status: 'up',
      current_time: new Date(),
    });
  }

  /*
  Query all from DB
  */
  findAll() {
    return this.bookingRepository.find();
  }

  async findOneSet(body: any) {
    const user_email = body.email;

    return this.bookingRepository.find(
      {
        where:{user_email}
      }
    );
  }

  /*
  Save to Redis and Record Session
  */
  async redisHandler(packageName, payload) {
    try {
      const client = createClient({
        socket: {
          host: 'redis',
          // host: 'localhost',
          port: 6379,
        },
      });
      try {
        client.on('error', async (err) => await this.helpersModules.LoggerError(`Redis Client ${err}`));
        await client.connect();
        await client.hSet(`${packageName}`, payload);

        const userSession = await client.hGetAll(`${packageName}`);
        await client.expire(`${packageName}`, (3600 * 24)); // Expires in 24 hours
        await this.helpersModules.improveLogReadability();
        await this.helpersModules.LoggerInfo(`Redis Session ${packageName}`);
        await this.helpersModules.LoggerInfo(JSON.stringify(userSession, null, 2));
        await this.helpersModules.improveLogReadability();
      } catch (err) {
        await this.helpersModules.LoggerError(err);
      }
      await client.quit();
    } catch (err) {
      await this.helpersModules.LoggerError(err);
    }
  }

  /*
  Fetch from Redis
  */
  async fetchFromRedis(key) {
    let payload: string = '';
    try {
      const client = createClient({
        socket: {
          host: 'redis',
          // host: 'localhost',
          port: 6379
        }
      });
      try {
        client.on('error', err => this.helpersModules.LoggerError(`Redis Client Error ${err}`));
        await client.connect();

        let userSession = await client.hGetAll(`${key}`);
        let sessionPayload = JSON.stringify(userSession, null, 2);
        sessionPayload = JSON.parse(sessionPayload);
        payload = sessionPayload;

        await this.helpersModules.LoggerInfo(`Redis Session - ${key}`);
        await this.helpersModules.LoggerInfo(typeof sessionPayload);
        await this.helpersModules.LoggerInfo(sessionPayload);

      } catch (err) {
        await this.helpersModules.LoggerError(err);
      }
      await client.quit();
    } catch (err) {
      await this.helpersModules.LoggerError(err);
    }
    payload = await this.helpersModules.loadCalendar(payload);
    return payload;
  }

  /*
  Clear from Redis
  */
  async clearFromRedis(key) {
    try {
      const client = createClient({
        socket: {
          host: 'redis',
          // host: 'localhost',
          port: 6379
        }
      });
      try {
        client.on('error', err => this.helpersModules.LoggerError(`Redis Client Error ${err}`));
        await client.connect();
        let userSession = await client.hGetAll(`${key}`);
        await client.del(`${key}`);
        return true;
      } catch (err) {
        await this.helpersModules.LoggerError(err);
      }
      await client.quit();
    } catch (err) {
      await this.helpersModules.LoggerError(err);
    }
    return false;
  }

  /*
  Save to Rabbit Queue
  */
  async rabbitHandler(payload) {
    try {
      let connection;

      // Local Vs Docker Connection
      try {
        await this.helpersModules.improveLogReadability();
        connection = await amqp.connect('amqp://rabbitmq-container');
      } catch (err) {
        await this.helpersModules.LoggerError(err);
        await this.helpersModules.improveLogReadability();
        await this.helpersModules.LoggerInfo('Falling back to localhost');
        connection = await amqp.connect('amqp://localhost');
      }

      const channel = await connection.createChannel();

      const queue = 'booking';
      const msg = payload;

      await channel.assertQueue(queue, {
        durable: true,
        arguments: { 'x-queue-type': 'quorum' },
      });
      channel.sendToQueue(queue, Buffer.from(msg));

      await this.helpersModules.LoggerInfo(` [x] Sent ${msg}`);

      setTimeout(function () {
        connection.close();
      }, 500);
    } catch (err) {
      await this.helpersModules.LoggerError(err);
    }
  }

  /*
  Handle Booking
  */
  async makeBooking(bookingData) {
    try {
      const bookingId = Date.now();
      const registrationDate = new Date();

      await this.helpersModules.improveLogReadability();
      await this.helpersModules.validateBookingFields(bookingData);
      await this.helpersModules.improveLogReadability();
      const bookingCheckIn = await this.helpersModules.readBookingDates(
        bookingData.check_in,
        'check-in',
      );
      const bookingCheckOut = await this.helpersModules.readBookingDates(
        bookingData.check_out,
        'check-out',
      );
      let bookingState;
      await this.helpersModules.improveLogReadability();
      const bookingDuration = await this.helpersModules.compareBookingDates(
        bookingCheckIn,
        bookingCheckOut,
      );
      await this.helpersModules.improveLogReadability();
      const bookingStayConfirmation =
        await this.helpersModules.checkRoomAvailability(
          bookingCheckIn,
          bookingCheckOut,
          bookingDuration,
        );

      bookingState = bookingStayConfirmation[2];
      await this.helpersModules.improveLogReadability();
      const bookingCheckInTime = await this.helpersModules.generateBookingTimes(
        bookingStayConfirmation[0],
        bookingData.check_in_time,
        'check-in',
      );
      const bookingCheckOutTime = await this.helpersModules.generateBookingTimes(
        bookingStayConfirmation[1],
        bookingData.check_out_time,
        'check-out',
      );
      await this.helpersModules.improveLogReadability();
      const bookingPrice = await this.helpersModules.generateGuestsPrice(
        bookingDuration,
        bookingData.guests_number,
        bookingData.breakfast,
      );
      await this.helpersModules.improveLogReadability();
      const mainGuest = `${await this.helpersModules.capitalizeFirstLetter(bookingData.main_guest.title)} ${await this.helpersModules.capitalizeFirstLetter(bookingData.main_guest.firstname)} ${await this.helpersModules.capitalizeFirstLetter(bookingData.main_guest.surname)}`;

      // Confirmation Payload
      const bookingFinalization = {
        booking_id: `${bookingId}`,
        registration_date: `${registrationDate}`,
        main_guest: `${mainGuest}`,
        title: `${bookingData.main_guest.title}`,
        firstname: `${bookingData.main_guest.firstname}`,
        surname: `${bookingData.main_guest.surname}`,
        origin: `${await this.helpersModules.capitalizeFirstLetter(bookingData.main_guest.origin_country)}`,
        email: `${bookingData.main_guest.email}`,
        phone: `${bookingData.main_guest.phone}`,
        guests: `${bookingData.guests_number}`,
        breakfast: `${await this.helpersModules.interpretOption(bookingData.breakfast)}`,
        breakfast_text: `${await this.helpersModules.renderOptionSummary(bookingData.breakfast)}`,
        check_in: `${bookingCheckInTime}`,
        check_in_timestamp: `${await this.helpersModules.markTime(bookingCheckInTime)}`,
        check_in_form: `${await this.helpersModules.normalizeDate(bookingCheckInTime)}`,
        check_out: `${bookingCheckOutTime}`,
        check_out_timestamp: `${await this.helpersModules.markTime(bookingCheckOutTime)}`,
        check_out_form: `${await this.helpersModules.normalizeDate(bookingCheckOutTime)}`,
        duration: `${bookingDuration}`,
        duration_text: `${bookingDuration} Night(s)`,
        price: `${bookingPrice}`,
        price_text: `USD ${bookingPrice.toLocaleString()}`,
        bookingState: bookingState,
        summary: `
    Dear ${mainGuest},

    Booking #${bookingId} Confirmed 
    For
    ${bookingData.guests_number} guest(s)  
    For
    ${bookingDuration} night(s)
    From 
    ${bookingCheckInTime}
    To 
    ${bookingCheckOutTime}
    At the value of
    USD ${bookingPrice.toLocaleString()}
    ${await this.helpersModules.renderOptionSummary(bookingData.breakfast)}
        `,
      };

      if (!bookingState.stateChanged) {
        // Redid Payload
        const redisPayload = {
          booking_id: `${bookingId}`,
          registration_date: `${registrationDate}`,
          main_guest: `${mainGuest}`,
          title: `${bookingData.main_guest.title}`,
          firstname: `${bookingData.main_guest.firstname}`,
          surname: `${bookingData.main_guest.surname}`,
          origin: `${await this.helpersModules.capitalizeFirstLetter(bookingData.main_guest.origin_country)}`,
          email: `${bookingData.main_guest.email}`,
          phone: `${bookingData.main_guest.phone}`,
          guests: `${bookingData.guests_number}`,
          breakfast: `${await this.helpersModules.interpretOption(bookingData.breakfast)}`,
          breakfast_text: `${await this.helpersModules.renderOptionSummary(bookingData.breakfast)}`,
          check_in: `${bookingCheckInTime}`,
          check_in_timestamp: `${await this.helpersModules.markTime(bookingCheckInTime)}`,
          check_in_form: `${await this.helpersModules.normalizeDate(bookingCheckInTime)}`,
          check_out: `${bookingCheckOutTime}`,
          check_out_timestamp: `${await this.helpersModules.markTime(bookingCheckOutTime)}`,
          check_out_form: `${await this.helpersModules.normalizeDate(bookingCheckOutTime)}`,
          duration: `${bookingDuration}`,
          duration_text: `${bookingDuration} Night(s)`,
          price: `${bookingPrice}`,
          price_text: `USD ${bookingPrice.toLocaleString()}`,
        };

        // Sessions
        this.redisHandler(bookingData.main_guest.email, redisPayload);
        // Unique Bookings
        this.redisHandler(`${bookingId}`, redisPayload);
        //Queue
        this.rabbitHandler(`${bookingId}`);
      }

      return bookingFinalization;
    } catch (err) {
      this.helpersModules.LoggerError(err);
    }
    return {};
  }
        
  /*
  Handle Payload
  */
  async formatRequestParameters(payload, type) {
    try {
      let requestPayload;
      let modifiedQueryString;
      let modifiedQueryObj;

      // URL payload
      if (type === 'url') {
        if (payload.toString().includes('?')) {
          const queryToParse = payload.split('?')[1];
          if (queryToParse) {
            const parsedQuery = querystring.parse(queryToParse);
            parsedQuery.exercise = 'querystring';
            modifiedQueryString = querystring.stringify(parsedQuery);
          }
        } else {
          modifiedQueryString = payload;
        }
        await this.helpersModules.LoggerInfo(modifiedQueryString);

        if (modifiedQueryString) {
          const modifiedQueryObj = Object.fromEntries(
            modifiedQueryString.split('&').map((pair) => pair.split('=')),
          );
          await this.helpersModules.LoggerInfo(modifiedQueryObj);
        }
      }

      // JSON payload
      if (type === 'json') {
        modifiedQueryObj = payload;
        await this.helpersModules.LoggerInfo(modifiedQueryObj);
      }

      requestPayload = {
        main_guest: {
          title: `${decodeURIComponent(modifiedQueryObj.title)}`,
          firstname: `${decodeURIComponent(modifiedQueryObj.firstname)}`,
          surname: `${decodeURIComponent(modifiedQueryObj.surname)}`,
          email: `${decodeURIComponent(modifiedQueryObj.email)}`,
          phone: `${decodeURIComponent(modifiedQueryObj.phone)}`,
          origin_country: `${decodeURIComponent(modifiedQueryObj.countriesfield)}`,
        },
        guests_number: decodeURIComponent(modifiedQueryObj.guests),
        breakfast: decodeURIComponent(modifiedQueryObj.breakfast),
        check_in: `${decodeURIComponent(modifiedQueryObj.checkin)}`,
        check_out: `${decodeURIComponent(modifiedQueryObj.checkout)}`,
        check_in_time: `${decodeURIComponent(modifiedQueryObj.checkintime)}`,
        check_out_time: `${decodeURIComponent(modifiedQueryObj.checkouttime)}`,
      };
      await this.helpersModules.LoggerInfo(requestPayload);

      return requestPayload;
    } catch (err) {
      this.helpersModules.LoggerError(err);
    }
    return null;
  }

  /*
  Booking Service
  */
  async createBooking(payload, type) {
    try {
      const requestPayload = await this.formatRequestParameters(payload, type);

      let bookingFinalization;
      if (requestPayload) {
        bookingFinalization = await this.makeBooking(requestPayload);
      }
      return JSON.stringify(bookingFinalization);
    } catch (err) {
      this.helpersModules.LoggerError(err);
    }
    return JSON.stringify([]);
  }
}
