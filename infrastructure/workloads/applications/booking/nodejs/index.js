// IMPORTANT: Make sure to import `instrument.js` at the top of your file.
// If you're using ECMAScript Modules (ESM) syntax, use `import "./instrument.js";`
require("./instrument.js");
const http = require('http');
const querystring = require('querystring');
const { createClient } = require('redis');
const amqp = require('amqplib');
const helpers = require(`./_helpers_modules`);

/*
Save to Redis and Record Session
*/
const redisHandler = async (packageName, payload) => {
  try {
    const client = createClient({
      socket: {
        host: 'redis',
        port: 6379
      }
    });

    try {
      client.on('error', err => helpers.LoggerError(`Redis Client Error ${err}`));
      await client.connect();

      await client.hSet(`${packageName}`, payload);

      let userSession = await client.hGetAll(`${packageName}`);
      await helpers.improveLogReadability();
      await helpers.LoggerInfo(`Redis Session - ${packageName}`);
      await helpers.LoggerInfo(JSON.stringify(userSession, null, 2));
      await helpers.improveLogReadability();
    } catch (err) {
      helpers.LoggerError(err);
    }

    await client.quit();
  } catch (err) {
    helpers.LoggerError(err);
  }
}

/*
Save to Rabbit Queue
*/
const rabbitHandler = async (payload) => {
  try {
    let connection;

    // Local Vs Docker Connection
    try {
      await helpers.improveLogReadability();
      connection = await amqp.connect('amqp://rabbitmq-container');
    } catch (err) {
      await helpers.LoggerError(err);
      await helpers.improveLogReadability();
      await helpers.LoggerInfo('Falling back to localhost');
      connection = await amqp.connect('amqp://localhost');
    }

    const channel = await connection.createChannel();

    const queue = 'booking';
    const msg = payload;

    await channel.assertQueue(queue, {
      durable: true,
      arguments: { 'x-queue-type': 'quorum' }
    });
    channel.sendToQueue(queue, Buffer.from(msg));

    await helpers.LoggerInfo(` [x] Sent %s ${msg}`);

    setTimeout(function() {
      connection.close();
    }, 500);
  } catch (err) {
    helpers.LoggerError(err);
  }
}

/*
Handle Booking
*/
const makeBooking = async (bookingData) => {
  try {
    const bookingId = Date.now();
    const registrationDate = new Date();

    await helpers.improveLogReadability();
    await helpers.validateBookingFields(bookingData);
    await helpers.improveLogReadability();
    let bookingCheckIn = await helpers.readBookingDates(bookingData.check_in, 'check-in');
    let bookingCheckOut = await helpers.readBookingDates(bookingData.check_out, 'check-out');
    let bookingState;
    await helpers.improveLogReadability();
    const bookingDuration = await helpers.compareBookingDates(bookingCheckIn, bookingCheckOut);
    await helpers.improveLogReadability();
    const bookingStayConfirmation = await helpers.checkRoomAvailability(bookingCheckIn, bookingCheckOut, bookingDuration);
    bookingCheckIn = bookingStayConfirmation[0];
    bookingCheckOut = bookingStayConfirmation[1];
    bookingState = bookingStayConfirmation[2];
    await helpers.improveLogReadability();
    const bookingCheckInTime = await helpers.generateBookingTimes(bookingCheckIn, bookingData.check_in_time, 'check-in');
    const bookingCheckOutTime = await helpers.generateBookingTimes(bookingCheckOut, bookingData.check_out_time, 'check-out');
    await helpers.improveLogReadability();
    const bookingPrice = await helpers.generateGuestsPrice(bookingDuration, bookingData.guests_number, bookingData.breakfast);
    await helpers.improveLogReadability();
    const mainGuest = `${await helpers.capitalizeFirstLetter(bookingData.main_guest.title)} ${await helpers.capitalizeFirstLetter(bookingData.main_guest.firstname)} ${await helpers.capitalizeFirstLetter(bookingData.main_guest.surname)}`;

    // Confirmation Payload
    const bookingFinalization = {
      "booking_id": `${bookingId}`,
      "registration_date": `${registrationDate}`,
      "main_guest": `${mainGuest}`,
      "title": `${bookingData.main_guest.title}`,
      "firstname": `${bookingData.main_guest.firstname}`,
      "surname": `${bookingData.main_guest.surname}`,
      "origin": `${await helpers.capitalizeFirstLetter(bookingData.main_guest.origin_country)}`,
      "email": `${bookingData.main_guest.email}`,
      "phone": `${bookingData.main_guest.phone}`,
      "guests": `${bookingData.guests_number}`,
      "breakfast": `${await helpers.interpretOption(bookingData.breakfast)}`,
      "breakfast_text": `${await helpers.renderOptionSummary(bookingData.breakfast)}`,
      "check_in": `${bookingCheckInTime}`,
      "check_in_timestamp": `${await helpers.markTime(bookingCheckInTime)}`,
      "check_in_form": `${await helpers.normalizeDate(bookingCheckInTime)}`,
      "check_out": `${bookingCheckOutTime}`,
      "check_out_timestamp": `${await helpers.markTime(bookingCheckOutTime)}`,
      "check_out_form": `${await helpers.normalizeDate(bookingCheckOutTime)}`,
      "duration": `${bookingDuration}`,
      "duration_text": `${bookingDuration} Night(s)`,
      "price": `${bookingPrice}`,
      "price_text": `USD ${bookingPrice.toLocaleString()}`,
      "bookingState": bookingState,
      "summary": `
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
${await helpers.renderOptionSummary(bookingData.breakfast)}
    `};

    if (!bookingState.stateChanged){
      // Redid Payload
      const redisPayload = {
        "booking_id": `${bookingId}`,
        "registration_date": `${registrationDate}`,
        "main_guest": `${mainGuest}`,
        "title": `${bookingData.main_guest.title}`,
        "firstname": `${bookingData.main_guest.firstname}`,
        "surname": `${bookingData.main_guest.surname}`,
        "origin": `${await helpers.capitalizeFirstLetter(bookingData.main_guest.origin_country)}`,
        "email": `${bookingData.main_guest.email}`,
        "phone": `${bookingData.main_guest.phone}`,
        "guests": `${bookingData.guests_number}`,
        "breakfast": `${await helpers.interpretOption(bookingData.breakfast)}`,
        "breakfast_text": `${await helpers.renderOptionSummary(bookingData.breakfast)}`,
        "check_in": `${bookingCheckInTime}`,
        "check_in_timestamp": `${await helpers.markTime(bookingCheckInTime)}`,
        "check_in_form": `${await helpers.normalizeDate(bookingCheckInTime)}`,
        "check_out": `${bookingCheckOutTime}`,
        "check_out_timestamp": `${await helpers.markTime(bookingCheckOutTime)}`,
        "check_out_form": `${await helpers.normalizeDate(bookingCheckOutTime)}`,
        "duration": `${bookingDuration}`,
        "duration_text": `${bookingDuration} Night(s)`,
        "price": `${bookingPrice}`,
        "price_text": `USD ${bookingPrice.toLocaleString()}`
      };

      // Sessions
      await redisHandler(
        bookingData.main_guest.email,
        redisPayload
      );
      // Unique Bookings
      await redisHandler(
        `${bookingId}`,
        redisPayload
      );
      //Queue
      await rabbitHandler(`${bookingId}`);
    }

    return bookingFinalization;

  } catch (err) {
    helpers.LoggerError(err);
  }
  return null;
}

/*
Handle Payload
*/
const formatRequestParameters = async (payload, type) => {
  try {
    let requestPayload;
    let modifiedQueryString;
    let modifiedQueryObj;

    // URL payload
    if (type === 'url'){
      if ((payload.toString()).includes('?')) {
        const queryToParse = (payload).split('?')[1];    
        if (queryToParse) {
          const parsedQuery = querystring.parse(queryToParse);
          parsedQuery.exercise = 'querystring';
          modifiedQueryString = querystring.stringify(parsedQuery);
        }
      } else {
        modifiedQueryString = payload;
      }
      await helpers.LoggerInfo(modifiedQueryString);

      if (modifiedQueryString) {
        const modifiedQueryObj = Object.fromEntries(
          modifiedQueryString.split('&').map(pair => pair.split('='))
        );
        await helpers.LoggerInfo(modifiedQueryObj);
      }
    }

    // JSON payload
    if (type === 'json'){
      modifiedQueryObj = payload;
      await helpers.LoggerInfo(modifiedQueryObj);
    }

    requestPayload = {
      "main_guest": {
        "title": `${decodeURIComponent(modifiedQueryObj.title)}`,
        "firstname": `${decodeURIComponent(modifiedQueryObj.firstname)}`,
        "surname": `${decodeURIComponent(modifiedQueryObj.surname)}`,
        "email": `${decodeURIComponent(modifiedQueryObj.email)}`,
        "phone": `${decodeURIComponent(modifiedQueryObj.phone)}`,
        "origin_country": `${decodeURIComponent(modifiedQueryObj.countriesfield)}`
      },
      "guests_number": decodeURIComponent(modifiedQueryObj.guests),
      "breakfast": decodeURIComponent(modifiedQueryObj.breakfast),
      "check_in": `${decodeURIComponent(modifiedQueryObj.checkin)}`,
      "check_out": `${decodeURIComponent(modifiedQueryObj.checkout)}`,
      "check_in_time": `${decodeURIComponent(modifiedQueryObj.checkintime)}`,
      "check_out_time": `${decodeURIComponent(modifiedQueryObj.checkouttime)}`
    };
    await helpers.LoggerInfo(requestPayload);

    return requestPayload;

  } catch (err) {
    helpers.LoggerError(err);
  }
  return null;
}

/*
Health Endpoint
*/
const health = async () => {
  try {
    return JSON.stringify({
      status: 'up',
      current_time: new Date(),
    });
  } catch (err) {
    helpers.LoggerError(err);
  }
  return null;
}

/*
Handle POST
*/
const handlePostRequest = async (req, res) => {
  try {
    const pathname = req.url;

    let body = '';
    req.on('data', chunk => { body += chunk.toString(); });
    req.on('end', async () => {

      if (pathname.startsWith('/booking')) {
        let requestPayload = await formatRequestParameters(
          JSON.parse(body),
          'json'
        );

        let bookingFinalization;
        if (requestPayload) {
          bookingFinalization = await makeBooking(requestPayload);
        }

        res.writeHead(200, { 'Content-Type': 'application/json' });
        return res.end(JSON.stringify(bookingFinalization));
      } else {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(await health());
      }
    });
  } catch (err) {
    helpers.LoggerError(err);
  }
}

/*
Handle GET
*/
const handleGetRequest = async (req, res) => {
  try {
    const pathname = req.url;
    if (pathname.startsWith('/booking')) {
      let requestPayload = await formatRequestParameters(
        req.url,
        'url'
      );

      let bookingFinalization;
      if (requestPayload) {
        bookingFinalization = await makeBooking(requestPayload);
      }

      const referer = req.headers.referer;
      if (referer){
        res.writeHead(302, { 'Location': referer });
        res.setHeader('Content-Type', 'application/json');
        return res.end(JSON.stringify(bookingFinalization));
      } else {
        res.setHeader('Content-Type', 'application/json');
        res.writeHead(200, { 'Location': '/' });
        return res.end(JSON.stringify(bookingFinalization));
      }
    } else {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(await health());
    }
  } catch (err) {
    helpers.LoggerError(err);
  }
}

/*
CONTROLLER
*/
const server = http.createServer(
  async (req, res) => {
    try {
      const { method } = req;
      // Allow React
      res.setHeader('Access-Control-Allow-Origin', 'http://localhost:5173');

      // Specify allowed methods and headers
      res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
      res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

      switch(method) {
        case 'GET':
          return await handleGetRequest(req, res);
        case 'POST':
          return await handlePostRequest(req, res);
        default:
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(await health());
      }
    } catch (err) {
      helpers.LoggerError(err);
    }
  }
);

/*
SERVER
*/
server.listen(
  process.env.PORT || 4001,
  () => {
    try {
      const { address, port } = server.address();
      console.warn(`Server is listening on: http://${address}:${port}`);
    } catch (err) {
      helpers.LoggerError(err);
    }
  }
);
