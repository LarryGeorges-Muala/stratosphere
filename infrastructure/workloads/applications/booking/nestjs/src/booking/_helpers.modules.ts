import { getName, getCode } from 'country-list';
import { Injectable } from '@nestjs/common';

/*
Sample Blocked Calendar Entries
*/
const blockedCalendarEntriesArray = [
  new Date("2026-04-24T00:00:00"),
  new Date("2026-04-25T00:00:00"),
  new Date("2026-04-27T00:00:00"),
  new Date("2026-04-29T00:00:00"),
  new Date("2026-05-01T00:00:00"),
  new Date("2026-05-02T00:00:00"),
  new Date("2026-05-03T00:00:00"),
  new Date("2026-05-04T00:00:00"),
  new Date("2026-05-05T00:00:00"),
  new Date("2026-06-01T00:00:00"),
  new Date("2026-06-02T00:00:00"),
  new Date("2026-06-03T00:00:00"),
  new Date("2026-06-04T00:00:00"),
  new Date("2026-06-05T00:00:00"),
  new Date("2026-01-01T00:00:00")
];
blockedCalendarEntriesArray.sort((a: any, b: any) => a - b);

@Injectable()
export class HelpersModules {

  /*
  Loggers
  */
  async LoggerError(msg) {
    try {
      const ENV = (process.env.ENV || 'uat').toString().toLowerCase();
      const PROD = ["prod", "production"];
      if (!PROD.includes(ENV)) {
        console.log('\n............................');
        console.error(`${msg}`);
        console.log(new Error().stack);
        console.log('............................\n');
      }
      throw new Error(`${msg}`);
    } catch (err) {
      console.log('');
    }
  };

  async LoggerInfo(msg) {
    const ENV = (process.env.ENV || 'dev').toString().toLowerCase();
    const PROD = ["prod", "production"];
    if (!PROD.includes(ENV)) {
      console.log('\n............................');
      console.log(msg);
      console.log('............................\n');
    }
  };

  /*
  Visual Aid 
  */
  async improveLogReadability() {
    console.log('\n...................\n');
  }

  /*
  Calendar
  */
  async loadCalendar(payload) {
    try {
      if (typeof payload !== 'object') {
        payload = JSON.parse(payload);
      }
      payload.calendar = blockedCalendarEntriesArray;
    } catch (err) {
      this.LoggerError(err);
    }
    return payload;
  }

  /*
  Test Each Booking Field
  */
  async testBookingFields(bookingData, bookingField) {
    try {
      // Check passed key in obj
      await this.LoggerInfo(`Checking field '${bookingField}'...`);
      const check = bookingData.hasOwnProperty(bookingField);
      if (check) {
        console.log(`'${bookingField}' valid...`);
      } else {
        await this.LoggerError(`'${bookingField}' missing...`);
        // process.exit(1);
      }
    } catch (err) {
      this.LoggerError(err);
    }
  }

  /*
  Validate Email
  */
  async isEmailValid(email) {
    try {
      const pattern = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
      const emailValidation = pattern.test(email);
      if (emailValidation) {
        await this.LoggerInfo(`Email address '${email}' validated...`);
        return true;
      } else {
        await this.LoggerError(`Email address '${email}' invalid...`);
        // process.exit(1);
      }
    } catch (err) {
      this.LoggerError(err);
    }
  }

  /*
  Validate Origin Country
  */
  async isCountryValid(country) {
    try {
      let code = getCode(country);
      if (!code) {
        code = getName(country);
      }
      // Convert code response to validation boolean
      const countryValidation = !!code;
      if (countryValidation) {
        await this.LoggerInfo(`Country '${country}' validated...`);
        return true;
      } else {
        await this.LoggerError(`Country '${country}' invalid...`);
        // process.exit(1);
      }
    } catch (err) {
      this.LoggerError(err);
    }
    return false;
  }

  /*
  Main Guest Important Fields Validation
  */
  async mainGuestValidator(bookingData, bookingField) {
    try {
      switch (bookingField) {
        case 'email':
          await this.isEmailValid(bookingData.email);
          break;
        case 'phone':
          await this.LoggerInfo('No validation required - Phone number optional...');
          break;
        case 'origin_country':
          await this.isCountryValid(bookingData.origin_country);
          break;
        default:
          await this.LoggerInfo('No validation required...');
      }
    } catch (err) {
      this.LoggerError(err);
    }
  }

  /*
  Confirm Booking Main Guest
  */
  async confirmBookingMainGuest(bookingData, bookingField) {
    try {
      // Check passed key in obj
      await this.LoggerInfo(`Checking field '${bookingField}'...`);

      // Filtering main guest
      let check = bookingField.toLowerCase().includes('main_guest');
      if (check) {
        check = bookingData.hasOwnProperty('main_guest');
        if (check) {
          await this.LoggerInfo(`${bookingField} - Main guest loaded...`);

          // Parsing
          let mainGuestObj = JSON.parse(bookingField);
          mainGuestObj = mainGuestObj.main_guest;

          // Validation Loop
          mainGuestObj.forEach(async (field, index) => {
            await this.LoggerInfo(`\nMain Entry No. ${index}`);
            await this.testBookingFields(bookingData.main_guest, field);
            await this.mainGuestValidator(bookingData.main_guest, field);
          });
        } else {
          await this.LoggerError(`${bookingField} - Main guest missing...`);
          // process.exit(1);
        }
      } else {
        await this.LoggerError(`Main guest details missing from field \n'${bookingField}'...`);
        // process.exit(1);
      }
    } catch (err) {
      this.LoggerError(err);
    }
  }

  /*
  Validate Booking Fields
  */
  async validateBookingFields(bookingData) {
    try {
      // Hardcoded fields to validate - Main Guest
      const bookingMainGuest = [
        '{"main_guest": ["title", "firstname", "surname", "email", "phone", "origin_country"]}',
      ];
      // Hardcoded fields to validate - Booking Details
      const bookingFields = [
        'guests_number',
        'breakfast',
        'check_in',
        'check_out',
        'check_in_time',
        'check_out_time',
      ];

      // Validation Main Guest
      await this.confirmBookingMainGuest(bookingData, bookingMainGuest[0]);

      await this.improveLogReadability();

      // Validation Details Loop
      bookingFields.forEach(async (field, index) => {
        await this.LoggerInfo(`\nEntry No. ${index}`);
        await this.testBookingFields(bookingData, field);
      });
    } catch (err) {
      this.LoggerError(err);
    }
  }

  /*
  Generate Earliest Validation Date
  */
  async earliestDate() {
    try {
      const today = new Date();
      const currentYear = today.getFullYear();
      let currentMonth = today.getMonth();
      let generatedMonth = '';
      let generatedDay = '';
      if (currentMonth.toString().length == 1) {
        currentMonth = currentMonth + 1;
        if (currentMonth.toString() === '10') {
          generatedMonth = `${currentMonth}`;
        } else {
          generatedMonth = `0${currentMonth}`;
        }
      } else {
        generatedMonth = `${currentMonth}`;
      }
      const currentDay = today.getDate();
      if (currentDay.toString().length == 1) {
        generatedDay = `0${currentDay}`;
      } else {
        generatedDay = `${currentDay}`;
      }
      const dateFromString = new Date(
        `${currentYear}-${generatedMonth}-${generatedDay}T00:00:00Z`,
      );
      return dateFromString;
    } catch (err) {
      this.LoggerError(err);
    }
    return '';
  }

  /*
  Validate Date Format
  */
  async validateBookingDatesFormat(dateEntry, dateEntryName) {
    try {
      let check = dateEntry.toLowerCase().includes('-');
      if (check) {
        check = dateEntry.toLowerCase().includes(' ');
        if (check) {
          await this.LoggerError(`Invalid date format from '${dateEntryName}' - '${dateEntry}' - Please use format 'YYYY-MM-DD'...`);
          // process.exit(1);
        } else {
          await this.LoggerInfo(`'${dateEntryName}' - '${dateEntry}' valid...`);
        }
      } else {
        await this.LoggerError(`Invalid date format from '${dateEntryName}' - '${dateEntry}' - Please use format 'YYYY-MM-DD'...`);
        // process.exit(1);
      }
    } catch (err) {
      this.LoggerError(err);
    }
  }

  /*
  Read Booking Dates
  */
  async readBookingDates(dateEntry, dateEntryName) {
    try {
      if (dateEntry) {
        await this.validateBookingDatesFormat(dateEntry, dateEntryName);

        const dateObject = new Date(dateEntry);
        await this.LoggerInfo(dateObject);

        const today = await this.earliestDate();

        if (today <= dateObject) {
          return dateObject;
        } else {
          await this.LoggerError(`Invalid date from '${dateEntryName}' - '${dateEntry}' - Please set a recent date...`);
          // process.exit(1);
        }
      } else {
        await this.LoggerError(`Invalid date from '${dateEntryName}' - '${dateEntry}'...`);
        // process.exit(1);
      }
    } catch (err) {
      this.LoggerError(err);
    }
    return null;
  }

  /*
  Calculate Booking Duration
  */
  async calculateBookingDuration(checkin, checkout) {
    try {
      // The number of milliseconds in one day
      const oneDay = 1000 * 60 * 60 * 24; // 86400000 milliseconds

      // Convert both dates to UTC timestamps to avoid local timezone issues
      const start = Date.UTC(
        checkin.getFullYear(),
        checkin.getMonth(),
        checkin.getDate(),
      );
      const end = Date.UTC(
        checkout.getFullYear(),
        checkout.getMonth(),
        checkout.getDate(),
      );

      // Calculate the difference in milliseconds and convert to days
      // Math.floor() or Math.round() can be used depending on desired behavior
      return Math.floor(Math.abs((end - start) / oneDay));
    } catch (err) {
      this.LoggerError(err);
    }
    return 0;
  }

  /*
  Compare Booking Dates
  */
  async compareBookingDates(checkin, checkout) {
    try {
      // Check-Out After Check-In
      if (checkin < checkout) {
        if (checkin.getTime() < checkout.getTime()) {
          // Difference in days
          const daysDifference = await this.calculateBookingDuration(
            checkin,
            checkout,
          );
          await this.LoggerInfo(`Duration: ${daysDifference} night(s)`);
          return daysDifference;
        } else {
          await this.LoggerError(`Invalid Check-Out Date from '${checkout}' compared to '${checkin}'...`);
          // process.exit(1);
        }
      } else {
        await this.LoggerError(`Invalid Check-Out Date from '${checkout}' compared to '${checkin}'...`);
        // process.exit(1);
      }
    } catch (err) {
      this.LoggerError(err);
    }
    return 0;
  }

  /*
  Generate Booking Times
  */
  async generateBookingTimes(dateEntry, timeEntry, description) {
    try {
      const timeArray = timeEntry.split(':');
      if (timeArray[0].toString().length == 1) {
        timeEntry = `0${timeEntry}`;
      }
      const year = dateEntry.getFullYear();
      let month = dateEntry.getMonth();
      let generatedMonth = '';
      let generatedDay = '';
      if ((month.toString()).length == 1) {
        month = month + 1;
        if (month.toString() === '10') {
          generatedMonth = `${month}`;
        } else {
          generatedMonth = `0${month}`;
        }
      } else {
        generatedMonth = `${month}`;
      }
      let day = dateEntry.getDate();
      if ((day.toString()).length == 1) {
        generatedDay = `0${day}`;
      } else {
        generatedDay = `${day}`;
      }
      const dateFromString = new Date(`${year}-${generatedMonth}-${generatedDay}T${timeEntry}:00`);
      const validation = dateFromString instanceof Date;
      await this.LoggerInfo(`'${description} time': '${timeEntry}' / ${dateFromString}...`);
      if (validation) {
        return dateFromString;
      } else {
        // process.exit(1);
      }
    } catch (err) {
      this.LoggerError(err);
    }
    return '';
  }

  /*
  Room Availability
  */
  async normalizeDate(dateEntry) {
    try {
      let generatedMonth = '';
      let generatedDay = '';
      let month = dateEntry.getMonth();
      if (month.toString().length == 1) {
        month = month + 1;
        if (month.toString() === '10') {
          generatedMonth = `${month}`;
        } else {
          generatedMonth = `0${month}`;
        }
      } else {
        generatedMonth = `${month}`;
      }
      const day = dateEntry.getDate();
      if (day.toString().length == 1) {
        generatedDay = `0${day}`;
      } else {
        generatedDay = `${day}`;
      }
      return `${dateEntry.getFullYear()}-${generatedMonth}-${generatedDay}`;
    } catch (err) {
      this.LoggerError(err);
    }
    return '';
  }

  async findAvailableDate(
    normalizedDatesList,
    savedNormalizedDate,
    alernativeNormalizedDate,
    searchLimit = 360,
  ) {
    try {
      let count = 1;
      await this.LoggerInfo('\nVerifying check-in date...');
      while (count < searchLimit) {
        if (normalizedDatesList.includes(alernativeNormalizedDate)) {
          await this.LoggerInfo(`Date not available... '${alernativeNormalizedDate}'... Adjusting by ${count} day(s)...`);
          savedNormalizedDate = alernativeNormalizedDate;
          alernativeNormalizedDate = new Date(alernativeNormalizedDate);
          alernativeNormalizedDate.setDate(
            alernativeNormalizedDate.getDate() + 1,
          );
          alernativeNormalizedDate = await this.normalizeDate(
            alernativeNormalizedDate,
          );
          await this.LoggerInfo(`New date to check: ${alernativeNormalizedDate}`);
          count++;
        } else {
          await this.LoggerInfo(`\nAvailable date found, check-in possible: ${savedNormalizedDate}`);
          break;
        }
      }
      return savedNormalizedDate;
    } catch (err) {
      this.LoggerError(err);
    }
    return null;
  }

  async confirmStayDuration(
    normalizedDatesList,
    savedNormalizedDate,
    alernativeNormalizedDate,
    searchLimit = 360,
  ) {
    try {
      let count = 1;
      await this.LoggerInfo(`\n\nConfirming uninterrupted stay duration from ${savedNormalizedDate}`);
      await this.LoggerInfo(`Nights: ${searchLimit}`);
      while (count < searchLimit + 1) {
        await this.LoggerInfo(`\nConfirming night ${count}: ${alernativeNormalizedDate}`);
        if (normalizedDatesList.includes(alernativeNormalizedDate)) {
          await this.LoggerInfo(`Date not available... '${alernativeNormalizedDate}'... Stay interrupted...`);
          savedNormalizedDate = alernativeNormalizedDate;
          break;
        } else {
          await this.LoggerInfo(`Night ${count} confirmed: ${alernativeNormalizedDate}`);
        }
        savedNormalizedDate = alernativeNormalizedDate;
        alernativeNormalizedDate = new Date(alernativeNormalizedDate);
        alernativeNormalizedDate.setDate(alernativeNormalizedDate.getDate() + 1);
        alernativeNormalizedDate = await this.normalizeDate(
          alernativeNormalizedDate,
        );
        count++;
      }
      return savedNormalizedDate;
    } catch (err) {
      this.LoggerError(err);
    }
    return null;
  }

  async manageStayInterruptions(
    normalizer,
    normalizedCheckin,
    bookingDuration,
  ) {
    try {
      // Confirm viability of check-in
      let savedNormalizedCheckin = normalizedCheckin;
      let generatedAlernativeCheckin = new Date(savedNormalizedCheckin);
      let alernativeNormalizedCheckin = await this.normalizeDate(
        generatedAlernativeCheckin,
      );
      savedNormalizedCheckin = await this.findAvailableDate(
        normalizer,
        savedNormalizedCheckin,
        alernativeNormalizedCheckin,
      );

      // Confirm stay duration
      generatedAlernativeCheckin = new Date(savedNormalizedCheckin);
      generatedAlernativeCheckin.setDate(
        generatedAlernativeCheckin.getDate() + 1,
      );
      alernativeNormalizedCheckin = await this.normalizeDate(
        generatedAlernativeCheckin,
      );
      const savedNormalizedCheckout = await this.confirmStayDuration(
        normalizer,
        savedNormalizedCheckin,
        alernativeNormalizedCheckin,
        bookingDuration,
      );

      return [new Date(normalizedCheckin), new Date(savedNormalizedCheckout)];
    } catch (err) {
      this.LoggerError(err);
    }
    return [];
  }

  async checkRoomAvailability(checkin, checkout, bookingDuration) {
    try {
      // const roomBlockedCalendar = [
      //   new Date('2026-04-01T00:00:00'),
      //   new Date('2026-04-02T00:00:00'),
      //   new Date('2026-04-03T00:00:00'),
      //   new Date('2026-04-04T00:00:00'),
      //   new Date('2026-04-05T00:00:00'),
      //   new Date('2026-04-06T00:00:00'),
      //   new Date('2026-04-07T00:00:00'),
      //   new Date('2026-04-10T00:00:00'),
      //   new Date('2026-04-13T00:00:00'),
      //   new Date('2026-04-15T00:00:00'),
      //   new Date('2026-05-01T00:00:00'),
      //   new Date('2026-05-02T00:00:00'),
      //   new Date('2026-05-03T00:00:00'),
      //   new Date('2026-05-04T00:00:00'),
      //   new Date('2026-05-05T00:00:00'),
      //   new Date('2026-06-01T00:00:00'),
      //   new Date('2026-06-02T00:00:00'),
      //   new Date('2026-06-03T00:00:00'),
      //   new Date('2026-06-04T00:00:00'),
      //   new Date('2026-06-05T00:00:00'),
      // ];
      const roomBlockedCalendar: string[] = [];
      const normalizer: string[] = [];

      roomBlockedCalendar.forEach(async (entry, index) => {
        normalizer.push(await this.normalizeDate(entry));
      });

      await this.LoggerInfo('Blocked calendar...');
      await this.LoggerInfo(normalizer);
      const normalizedCheckin = await this.normalizeDate(checkin);
      let normalizedCheckout = await this.normalizeDate(checkout);

      let savedNormalizedCheckin = normalizedCheckin;
      let savedNormalizedCheckout = normalizedCheckout;

      // Confirm viability of check-in
      await this.improveLogReadability();
      let stayManager = await this.manageStayInterruptions(
        normalizer,
        normalizedCheckin,
        bookingDuration,
      );

      let generatedCheckin = stayManager[0];
      let generatedCheckout = stayManager[1];
      let expectedCheckout = generatedCheckin;
      expectedCheckout.setDate(expectedCheckout.getDate() + bookingDuration);

      normalizedCheckout = await this.normalizeDate(generatedCheckout);
      let normalizedExpectedCheckout = await this.normalizeDate(expectedCheckout);

      generatedCheckin.setDate(generatedCheckin.getDate() - bookingDuration);
      let generatedNormalizedCheckin = await this.normalizeDate(generatedCheckin);

      // Confirm stay duration
      await this.improveLogReadability();
      if (normalizedCheckout != normalizedExpectedCheckout) {
        await this.LoggerInfo('Re-adjusting check-in to fix uninterrupted stay...');
        while (normalizedCheckout != normalizedExpectedCheckout) {
          generatedNormalizedCheckin = normalizedCheckout;

          stayManager = await this.manageStayInterruptions(
            normalizer,
            generatedNormalizedCheckin,
            bookingDuration,
          );

          generatedCheckin = stayManager[0];
          generatedCheckout = stayManager[1];

          expectedCheckout = generatedCheckin;
          expectedCheckout.setDate(expectedCheckout.getDate() + bookingDuration);

          normalizedCheckout = await this.normalizeDate(generatedCheckout);
          normalizedExpectedCheckout = await this.normalizeDate(expectedCheckout);

          if (normalizedCheckout == normalizedExpectedCheckout) {
            generatedCheckin.setDate(
              generatedCheckin.getDate() - bookingDuration,
            );
            generatedNormalizedCheckin =
              await this.normalizeDate(generatedCheckin);
            break;
          }
        }
      }

      // Compare initial and new dates
      await this.LoggerInfo('\nConfirming check-in...');
      let stateChanged = false;
      let stateChangedSummary;
      let stateChangedMessage;

      if (generatedNormalizedCheckin == savedNormalizedCheckin){
        await this.LoggerInfo(`Requested check-in of '${generatedNormalizedCheckin}' confirmed...`);
      } else {
        // STATE MSG
        stateChangedMessage = `
    Initial requested check-in of '${savedNormalizedCheckin}' not available...
    Check-in adjusted to '${generatedNormalizedCheckin}' till '${normalizedCheckout}'
        `;
        await this.LoggerInfo(`
          ${stateChangedMessage}
          Adjusted check-in of '${generatedNormalizedCheckin}' confirmed...
          Adjusted check-out of '${normalizedCheckout}' validated...
        `);

        // SUMMARY
        stateChangedSummary = `
    System Message

    ${stateChangedMessage}

    Would you like to proceed with the new dates?
        `;
        stateChanged = true;
        await this.LoggerInfo(stateChangedSummary);
      }

      await this.LoggerInfo(`Stay from '${generatedNormalizedCheckin}' to '${normalizedCheckout}' confirmed...`);
      return [
        new Date(generatedNormalizedCheckin),
        new Date(normalizedCheckout),
        {
          stateChanged: stateChanged,
          stateChangedSummary: stateChangedSummary,
        },
      ];
    } catch (err) {
      this.LoggerError(err);
    }
    return [];
  }

  /*
  Guests Pricing
  */
  async guestPriceValue() {
    return 100;
  }
  async breakfastPriceValue() {
    return 30;
  }

  async generateGuestsPrice(bookingDuration, guestsNumber, breakfast) {
    try {
      let total = 0;
      let boolHandler = breakfast.toString();

      const priceGuest = await this.guestPriceValue();
      const breakfastPrice = await this.breakfastPriceValue();

      boolHandler = boolHandler === 'true';
      await this.LoggerInfo(`USD ${priceGuest.toLocaleString()} per guest per night...`);
      if (boolHandler) {
        total =
          Number(bookingDuration) *
          Number(guestsNumber) *
          (priceGuest + breakfastPrice);
        await this.LoggerInfo(`
          Including breakfast...
          USD ${breakfastPrice.toLocaleString()} per guest per breakfast...
          For ${guestsNumber} guest(s) with breakfast and ${bookingDuration} night(s): USD ${total.toLocaleString()}...
        `);
      } else {
        total = Number(bookingDuration) * Number(guestsNumber) * priceGuest;
        await this.LoggerInfo(`For ${guestsNumber} guest(s) and ${bookingDuration} night(s): USD ${total.toLocaleString()}...`);
      }

      return total;
    } catch (err) {
      this.LoggerError(err);
    }
    return 0;
  }

  /*
  Format Content
  */
  async capitalizeFirstLetter(str) {
    try {
      if (!str) return str;
      return `${str.charAt(0).toUpperCase()}${str.slice(1)}`;
    } catch (err) {
      this.LoggerError(err);
    }
    return '';
  }

  async interpretOption(handler) {
    try {
      let boolHandler = handler.toString();
      boolHandler = boolHandler === 'true';
      if (boolHandler) {
        return await this.capitalizeFirstLetter('yes');
      }
      return await this.capitalizeFirstLetter('no');
    } catch (err) {
      this.LoggerError(err);
    }
    return null;
  }

  async renderOptionSummary(handler) {
    try {
      const priceGuest = await this.guestPriceValue();
      const breakfastPrice = await this.breakfastPriceValue();
      let boolHandler = handler.toString();
      boolHandler = boolHandler === 'true';
      if (boolHandler) {
        return `
    With breakfast included

    Notes:
    USD ${priceGuest.toLocaleString()} per guest per night
    USD ${breakfastPrice.toLocaleString()} per guest per breakfast

    Enjoy Your Stay!
      `;
      }
      return `
    Notes:
    USD ${priceGuest.toLocaleString()} per guest per night

    Enjoy Your Stay!
      `;
    } catch (err) {
      this.LoggerError(err);
    }
    return '';
  }

  async markTime(dateEntry) {
    try {
      return dateEntry.getTime();
    } catch (err) {
      this.LoggerError(err);
    }
    return null;
  }
}
