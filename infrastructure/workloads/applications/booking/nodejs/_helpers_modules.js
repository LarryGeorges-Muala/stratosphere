const Sentry = require("@sentry/node");
const fs = require('fs');
const { getName, getCode } = require('country-list');

const currentDirectory = __dirname;

/*
Loggers
*/
const LoggerError = async (msg) => {
  Sentry.captureException(msg);
  const ENV = (process.env.ENV).toString().toLowerCase();
  const PROD = ["prod", "production"];
  if (!PROD.includes(ENV)) {
    console.log('\n............................');
    console.error(`${msg}`);
    console.log(new Error().stack);
    console.log('............................\n');
  }
};

const LoggerInfo = async (msg) => {
  const ENV = (process.env.ENV).toString().toLowerCase();
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
const improveLogReadability = async () => {
  console.log('\n...................\n');
};

/*
Test Booking file 
*/
const loadBookingFile = async (bookingFileName) => {
  try {
    if (fs.existsSync(`./samples/${bookingFileName}`)) {
      // Check path
      LoggerInfo(`Booking file '${bookingFileName}' found in ${currentDirectory}/samples`);
      let data = fs.readFileSync(`${currentDirectory}/samples/${bookingFileName}`, 'utf-8');
      LoggerInfo(typeof data);

      // Convert to JSON Obj
      let dataObj = JSON.parse(data);
      LoggerInfo(dataObj);
      return dataObj
    } else {
      LoggerError(`Booking file '${bookingFileName}' missing from ${currentDirectory}/samples... Exiting...`);
      process.exit(1);
    }
  } catch (err) {
    LoggerError(err);
  }
}

/*
Test Each Booking Field
*/
const testBookingFields = async (bookingData, bookingField) => {
  try {
    // Check passed key in obj
    LoggerInfo(`Checking field '${bookingField}'...`);
    if (Object.hasOwn(bookingData, `${bookingField}`)) {
      LoggerInfo(`'${bookingField}' valid...`);
    } else {
      LoggerError(`'${bookingField}' missing...`);
      process.exit(1);
    }
  } catch (err) {
    LoggerError(err);
  }
}

/*
Validate Email
*/
const isEmailValid = async (email) => {
  try {
    const pattern = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
    let emailValidation = pattern.test(email);
    if (emailValidation) {
      LoggerInfo(`Email address '${email}' validated...`)
      return true
    } else {
      LoggerError(`Email address '${email}' invalid...`);
      process.exit(1);
    }
  } catch (err) {
    LoggerError(err);
  }
}

/*
Validate Origin Country
*/
const isCountryValid = async (country) => {
  try {
    let code = getCode(country);
    if (!code) {
      code = getName(country);
    }
    // Convert code response to validation boolean
    let countryValidation = !!code;
    if (countryValidation) {
      LoggerInfo(`Country '${country}' validated...`)
      return true
    } else {
      LoggerError(`Country '${country}' invalid...`);
      process.exit(1);
    }
  } catch (err) {
    LoggerError(err);
  }
  return false;
}

/*
Main Guest Important Fields Validation
*/
const mainGuestValidator = async (bookingData, bookingField) => {
  try {
    switch (bookingField) {
      case 'email':
        await isEmailValid(bookingData.email);
        break;
      case 'phone':
        LoggerInfo('No validation required - Phone number optional...')
        break;
      case 'origin_country':
        await isCountryValid(bookingData.origin_country);
        break;
      default:
        LoggerInfo('No validation required...');
    }
  } catch (err) {
    LoggerError(err);
  }
}

/*
Confirm Booking Main Guest
*/
const confirmBookingMainGuest = async (bookingData, bookingField) => {
  try {
    // Check passed key in obj
    LoggerInfo(`Checking field '${bookingField}'...`);

    // Filtering main guest
    let check = bookingField.toLowerCase().includes('main_guest');
    if (check) {
      if (Object.hasOwn(bookingData, 'main_guest')) {
        LoggerInfo(`${bookingField} - Main guest loaded...`);

        // Parsing
        let mainGuestObj = JSON.parse(bookingField);
        mainGuestObj = mainGuestObj.main_guest;

        // Validation Loop
        mainGuestObj.forEach(
          async (field, index) => {
            LoggerInfo(`\nMain Entry No. ${index}`);
            await testBookingFields(bookingData.main_guest, field);
            await mainGuestValidator(bookingData.main_guest, field);
          }
        );
      } else {
        LoggerError(`${bookingField} - Main guest missing...`);
        process.exit(1);
      }
    } else {
      LoggerError(`Main guest details missing from field \n'${bookingField}'...`);
      process.exit(1);
    }
  } catch (err) {
    LoggerError(err);
  }
}

/*
Validate Booking Fields
*/
const validateBookingFields = async (bookingData) => {
  try {
    // Hardcoded fields to validate - Main Guest
    const bookingMainGuest = [
      '{"main_guest": ["title", "firstname", "surname", "email", "phone", "origin_country"]}'
    ];
    // Hardcoded fields to validate - Booking Details
    const bookingFields = [
      'guests_number',
      'breakfast',
      'check_in',
      'check_out',
      'check_in_time',
      'check_out_time'
    ];

    // Validation Main Guest
    await confirmBookingMainGuest(
      bookingData,
      bookingMainGuest[0]
    );

    // Validation Details Loop
    bookingFields.forEach(
      async (field, index) => {
        LoggerInfo(`\nEntry No. ${index}`);
        await testBookingFields(bookingData, field);
      }
    );
  } catch (err) {
    LoggerError(err);
  }
}

/*
Generate Earliest Validation Date
*/
const earliestDate = async () => {
  try {
    let today = new Date();
    let currentYear = today.getFullYear();
    let currentMonth = today.getMonth();
    let generatedMonth = '';
    let generatedDay = '';
    if ((currentMonth.toString()).length == 1) {
      currentMonth = currentMonth + 1;
      if (currentMonth.toString() === '10') {
        generatedMonth = `${currentMonth}`;
      } else {
        generatedMonth = `0${currentMonth}`;
      }
    } else {
      generatedMonth = `${currentMonth}`;
    }
    let currentDay = today.getDate();
    if ((currentDay.toString()).length == 1) {
      generatedDay = `0${currentDay}`;
    } else {
      generatedDay = `${currentDay}`;
    }
    let dateFromString = new Date(`${currentYear}-${generatedMonth}-${generatedDay}T00:00:00Z`);
    return dateFromString;
  } catch (err) {
    LoggerError(err);
  }
}

/*
Validate Date Format
*/
const validateBookingDatesFormat = async (dateEntry, dateEntryName) => {
  try {
    let check = dateEntry.toLowerCase().includes('-');
    if (check) {
      check = dateEntry.toLowerCase().includes(' ');
      if (check) {
        LoggerError(`Invalid date format from '${dateEntryName}' - '${dateEntry}' - Please use format 'YYYY-MM-DD'...`);
        process.exit(1);
      } else {
        LoggerInfo(`'${dateEntryName}' - '${dateEntry}' valid...`);
      }
    } else {
      LoggerError(`Invalid date format from '${dateEntryName}' - '${dateEntry}' - Please use format 'YYYY-MM-DD'...`);
      process.exit(1);    
    }
  } catch (err) {
    LoggerError(err);
  }
}

/*
Read Booking Dates
*/
const readBookingDates = async (dateEntry, dateEntryName) => {
  try {
    if (dateEntry) {
      await validateBookingDatesFormat(dateEntry, dateEntryName);

      let dateObject = new Date(dateEntry);
      LoggerInfo(dateObject);

      let today = await earliestDate();

      if (today <= dateObject) {
        if (dateEntryName == 'check-out') {
          if (dateObject <= today) {
            LoggerError(`Invalid date from '${dateEntryName}' - '${dateEntry}' - Please set an upcoming date...`);
            process.exit(1);
          }
        }
        return dateObject;
      } else {
        LoggerError(`Invalid date from '${dateEntryName}' - '${dateEntry}' - Please set a recent date...`);
        process.exit(1);
      }
    } else {
      LoggerError(`Invalid date from '${dateEntryName}' - '${dateEntry}'...`);
      process.exit(1);
    }
  } catch (err) {
    LoggerError(err);
  }
}

/*
Calculate Booking Duration
*/
const calculateBookingDuration = async (checkin, checkout) => {
  try {
    // The number of milliseconds in one day
    let oneDay = 1000 * 60 * 60 * 24; // 86400000 milliseconds

    // Convert both dates to UTC timestamps to avoid local timezone issues
    let start = Date.UTC(checkin.getFullYear(), checkin.getMonth(), checkin.getDate());
    let end = Date.UTC(checkout.getFullYear(), checkout.getMonth(), checkout.getDate());

    // Calculate the difference in milliseconds and convert to days
    // Math.floor() or Math.round() can be used depending on desired behavior
    return Math.floor(Math.abs((end - start) / oneDay));
  } catch (err) {
    LoggerError(err);
  }
  return 0;
}

/*
Compare Booking Dates
*/
const compareBookingDates = async (checkin, checkout) => {
  try {
    // Check-Out After Check-In
    if (checkin < checkout) {
      if (checkin.getTime() < checkout.getTime()) {
        // Difference in days
        let daysDifference = await calculateBookingDuration(checkin, checkout);
        LoggerInfo(`Duration: ${daysDifference} night(s)`);
        return daysDifference;
      } else {
        LoggerError(`Invalid Check-Out Date from '${checkout}' compared to '${checkin}'...`);
        process.exit(1);
      }
    } else {
      LoggerError(`Invalid Check-Out Date from '${checkout}' compared to '${checkin}'...`);
      process.exit(1);
    }
  } catch (err) {
    LoggerError(err);
  }
  return 0;
}

/*
Generate Booking Times
*/
const generateBookingTimes = async (dateEntry, timeEntry, description) => {
  try {
    let timeArray = timeEntry.split(':');
    if ((timeArray[0].toString()).length == 1) {
      timeEntry = `0${timeEntry}`;
    }
    let year = dateEntry.getFullYear();
    let month = dateEntry.getMonth();
    let generatedMonth;
    let generatedDay;
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
    let dateFromString = new Date(`${year}-${generatedMonth}-${generatedDay}T${timeEntry}:00`);
    let validation = dateFromString instanceof Date;
    LoggerInfo(`'${description} time': '${timeEntry}' / ${dateFromString}...`);
    if (validation) {
      return dateFromString;
    } else {
      process.exit(1);
    }
  } catch (err) {
    LoggerError(err);
  }
  return null;
}

/*
Room Availability
*/
const normalizeDate = async (dateEntry) => {
  try {
    let generatedMonth = '';
    let generatedDay = '';
    let month = dateEntry.getMonth();
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
    return `${dateEntry.getFullYear()}-${generatedMonth}-${generatedDay}`;
  } catch (err) {
    LoggerError(err);
  }
  return '';
}

const findAvailableDate = async (normalizedDatesList, savedNormalizedDate, alernativeNormalizedDate, searchLimit=360) => {
  try {
    let count = 1;
    LoggerInfo('\nVerifying check-in date...');
    while (count < searchLimit) {
      if (normalizedDatesList.includes(alernativeNormalizedDate)) {
        LoggerInfo(`Date not available... '${alernativeNormalizedDate}'... Adjusting by ${count} day(s)...`);
        savedNormalizedDate = alernativeNormalizedDate;
        alernativeNormalizedDate = new Date(alernativeNormalizedDate);
        alernativeNormalizedDate.setDate(alernativeNormalizedDate.getDate() + 1);
        alernativeNormalizedDate = await normalizeDate(alernativeNormalizedDate);
        LoggerInfo(`New date to check: ${alernativeNormalizedDate}`);
        count++;
      } else {
        LoggerInfo(`\nAvailable date found, check-in possible: ${savedNormalizedDate}`);
        break;
      }
    }
  } catch (err) {
    LoggerError(err);
  }
  return savedNormalizedDate;
}

const confirmStayDuration = async (normalizedDatesList, savedNormalizedDate, alernativeNormalizedDate, searchLimit=360) => {
  try {
    let count = 1;
    LoggerInfo(`\n\nConfirming uninterrupted stay duration from ${savedNormalizedDate}`);
    LoggerInfo(`Nights: ${searchLimit}`);
    while (count < (searchLimit + 1)) {
      LoggerInfo(`\nConfirming night ${count}: ${alernativeNormalizedDate}`);
      if (normalizedDatesList.includes(alernativeNormalizedDate)) {
        LoggerInfo(`Date not available... '${alernativeNormalizedDate}'... Stay interrupted...`);
        savedNormalizedDate = alernativeNormalizedDate;
        break;
      } else {
        LoggerInfo(`Night ${count} confirmed: ${alernativeNormalizedDate}`);
      }
      savedNormalizedDate = alernativeNormalizedDate;
      alernativeNormalizedDate = new Date(alernativeNormalizedDate);
      alernativeNormalizedDate.setDate(alernativeNormalizedDate.getDate() + 1);
      alernativeNormalizedDate = await normalizeDate(alernativeNormalizedDate);
      count++;
    }
  } catch (err) {
    LoggerError(err);
  }
  return savedNormalizedDate;
}

const manageStayInterruptions = async (normalizer, normalizedCheckin, bookingDuration) => {
  try {
    // Confirm viability of check-in
    let savedNormalizedCheckin = normalizedCheckin;
    let generatedAlernativeCheckin = new Date(savedNormalizedCheckin);
    let alernativeNormalizedCheckin = await normalizeDate(generatedAlernativeCheckin);
    savedNormalizedCheckin = await findAvailableDate(
      normalizer,
      savedNormalizedCheckin,
      alernativeNormalizedCheckin
    );

    // Confirm stay duration
    generatedAlernativeCheckin = new Date(savedNormalizedCheckin);
    generatedAlernativeCheckin.setDate(generatedAlernativeCheckin.getDate() + 1);
    alernativeNormalizedCheckin = await normalizeDate(generatedAlernativeCheckin);
    let savedNormalizedCheckout = await confirmStayDuration(
      normalizer,
      savedNormalizedCheckin,
      alernativeNormalizedCheckin,
      bookingDuration
    );

    return [new Date(normalizedCheckin), new Date(savedNormalizedCheckout)];
  } catch (err) {
    LoggerError(err);
  }
  return null;
}

const checkRoomAvailability = async (checkin, checkout, bookingDuration) => {
  try {
    // const roomBlockedCalendar = [
    //   new Date("2026-04-01T00:00:00"),
    //   new Date("2026-04-02T00:00:00"),
    //   new Date("2026-04-03T00:00:00"),
    //   new Date("2026-04-04T00:00:00"),
    //   new Date("2026-04-05T00:00:00"),
    //   new Date("2026-04-06T00:00:00"),
    //   new Date("2026-04-07T00:00:00"),
    //   new Date("2026-04-10T00:00:00"),
    //   new Date("2026-04-13T00:00:00"),
    //   new Date("2026-04-15T00:00:00"),
    //   new Date("2026-05-01T00:00:00"),
    //   new Date("2026-05-02T00:00:00"),
    //   new Date("2026-05-03T00:00:00"),
    //   new Date("2026-05-04T00:00:00"),
    //   new Date("2026-05-05T00:00:00"),
    //   new Date("2026-06-01T00:00:00"),
    //   new Date("2026-06-02T00:00:00"),
    //   new Date("2026-06-03T00:00:00"),
    //   new Date("2026-06-04T00:00:00"),
    //   new Date("2026-06-05T00:00:00")
    // ];

    const roomBlockedCalendar = [];

    let normalizer = [];

    roomBlockedCalendar.forEach(
      async (entry, index) => {
        LoggerInfo(`Entry No. ${index}`);
        normalizer.push(await normalizeDate(entry));
      }
    );

    LoggerInfo('Blocked calendar...');
    LoggerInfo(normalizer);
    let normalizedCheckin = await normalizeDate(checkin);
    let savedNormalizedCheckin = normalizedCheckin;

    // Confirm viability of check-in
    await improveLogReadability();
    let stayManager = await manageStayInterruptions(
      normalizer,
      normalizedCheckin,
      bookingDuration
    );

    let generatedCheckin = stayManager[0];
    let generatedCheckout = stayManager[1];
    let expectedCheckout = generatedCheckin;
    expectedCheckout.setDate(expectedCheckout.getDate() + bookingDuration);

    let normalizedCheckout = await normalizeDate(generatedCheckout);
    let normalizedExpectedCheckout = await normalizeDate(expectedCheckout);

    generatedCheckin.setDate(generatedCheckin.getDate() - bookingDuration);
    let generatedNormalizedCheckin = await normalizeDate(generatedCheckin);

    // Confirm stay duration
    await improveLogReadability();
    if (normalizedCheckout != normalizedExpectedCheckout) {
      LoggerInfo('Re-adjusting check-in to fix uninterrupted stay...');
      while (normalizedCheckout != normalizedExpectedCheckout) {
        generatedNormalizedCheckin = normalizedCheckout;

        stayManager = await manageStayInterruptions(
          normalizer,
          generatedNormalizedCheckin,
          bookingDuration
        );

        generatedCheckin = stayManager[0];
        generatedCheckout = stayManager[1];
        
        expectedCheckout = generatedCheckin;
        expectedCheckout.setDate(expectedCheckout.getDate() + bookingDuration);

        normalizedCheckout = await normalizeDate(generatedCheckout);
        normalizedExpectedCheckout = await normalizeDate(expectedCheckout);

        if (normalizedCheckout == normalizedExpectedCheckout) {
          generatedCheckin.setDate(generatedCheckin.getDate() - bookingDuration);
          generatedNormalizedCheckin = await normalizeDate(generatedCheckin);
          break;
        }
      }
    }

    // Compare initial and new dates
    LoggerInfo('\nConfirming check-in...');
    let stateChanged = false;
    let stateChangedSummary;
    let stateChangedMessage;

    if (generatedNormalizedCheckin == savedNormalizedCheckin){
      LoggerInfo(`Requested check-in of '${generatedNormalizedCheckin}' confirmed...`);
    } else {
      // STATE MSG
      stateChangedMessage = `
  Initial requested check-in of '${savedNormalizedCheckin}' not available...
  Check-in adjusted to '${generatedNormalizedCheckin}' till '${normalizedCheckout}'
      `;
      LoggerInfo(`
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
      LoggerInfo(stateChangedSummary);
    }

    LoggerInfo(`Stay from '${generatedNormalizedCheckin}' to '${normalizedCheckout}' confirmed...`);
    return [
      new Date(generatedNormalizedCheckin),
      new Date(normalizedCheckout),
      {
        'stateChanged': stateChanged,
        'stateChangedSummary': stateChangedSummary
      }
    ];
  } catch (err) {
    LoggerError(err);
  }
  return null;
}

/*
Guests Pricing
*/
const priceGuest = 100;
const breakfastPrice = 30; 
const generateGuestsPrice = async (bookingDuration, guestsNumber, breakfast) => {
  try {
    let total;
    let booHandler = breakfast.toString();

    booHandler = booHandler === "true";
    LoggerInfo(`USD ${priceGuest.toLocaleString()} per guest per night...`);
    if (booHandler) {
      total = Number(bookingDuration) * Number(guestsNumber) * (priceGuest + breakfastPrice);
      LoggerInfo(`
        Including breakfast...
        USD ${breakfastPrice.toLocaleString()} per guest per breakfast...
        For ${guestsNumber} guest(s) with breakfast and ${bookingDuration} night(s): USD ${total.toLocaleString()}...
      `);
    } else {
      total = Number(bookingDuration) * Number(guestsNumber) * priceGuest;
      LoggerInfo(`For ${guestsNumber} guest(s) and ${bookingDuration} night(s): USD ${total.toLocaleString()}...`);
    }

    return total;
  } catch (err) {
    LoggerError(err);
  }
  return null;
}

/*
Format Content
*/
const capitalizeFirstLetter = async (str) => {
  try {
    if (!str) return str;
    return `${str.charAt(0).toUpperCase()}${str.slice(1)}`;
  } catch (err) {
    LoggerError(err);
  }
  return '';
};

const interpretOption = async (handler) => {
  try {
    let booHandler = handler.toString();
    booHandler = booHandler === "true";
    if (booHandler) {
      return await capitalizeFirstLetter('yes');
    }
    return await capitalizeFirstLetter('no');
  } catch (err) {
    LoggerError(err);
  }
  return null;
}

const renderOptionSummary = async (handler) => {
  try {
    let booHandler = handler.toString();
    booHandler = booHandler === "true";
    if (booHandler) {
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
    LoggerError(err);
  }
  return '';
}

const markTime = async (dateEntry) => {
  try {
    return dateEntry.getTime();
  } catch (err) {
    LoggerError(err);
  }
  return null;
}

/*
Save Confirmation
*/
const saveBookingFinalization = async (bookingFinal, bookingId) => {
  try {
    let jsonString = JSON.stringify(bookingFinal, null, 2);
    let filePath = `${currentDirectory}/samples/booking-confirmation-${bookingId}.json`;

    // JSON file
    try {
      fs.writeFileSync(filePath, jsonString, 'utf8');
      LoggerInfo(`Entry saved to ${filePath} synchronously!`);
    } catch (err) {
      LoggerError(`Error creating file ${err}`);
    }
  } catch (err) {
    LoggerError(err);
  }
}

/*
Exports
*/
module.exports = {
  loadBookingFile,
  improveLogReadability,
  validateBookingFields,
  readBookingDates,
  compareBookingDates,
  normalizeDate,
  checkRoomAvailability,
  generateBookingTimes,
  generateGuestsPrice,
  capitalizeFirstLetter,
  interpretOption,
  renderOptionSummary,
  markTime,
  saveBookingFinalization,
  LoggerError,
  LoggerInfo
};
