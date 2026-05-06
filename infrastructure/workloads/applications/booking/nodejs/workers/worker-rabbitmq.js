/*
# node --env-file=../node.env worker-rabbitmq.js
*/
const amqp = require('amqplib');
const { createClient } = require('redis');
const databaseMysql = require(`../_mysql_modules`);
const helpers = require(`../_helpers_modules`);

/*
Redis
*/
async function fetchFromRedis(key) {
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

      let userSession = await client.hGetAll(`${key}`);
      let bookingFinalization = JSON.stringify(userSession, null, 2);
      bookingFinalization = JSON.parse(bookingFinalization);

      await helpers.LoggerInfo(`Redis Session - ${key}`);
      await helpers.LoggerInfo(typeof bookingFinalization);
      await helpers.LoggerInfo(bookingFinalization);

      // Run DB query
      const sqlQueries = [
        `SHOW TABLES;`,
        `SELECT id FROM users WHERE email="${bookingFinalization.email}" LIMIT 1;`,
        `INSERT INTO Bookings (
          booking_id,
          user_email,
          origin,
          guests,
          breakfast,
          check_in,
          check_in_timestamp,
          check_out,
          check_out_timestamp,
          duration,
          duration_text,
          price,
          price_text
        ) VALUES (
          "${bookingFinalization.booking_id}",
          "${bookingFinalization.email}",
          "${bookingFinalization.origin}",
          "${bookingFinalization.guests}",
          "${bookingFinalization.breakfast}",
          "${bookingFinalization.check_in}",
          "${bookingFinalization.check_in_timestamp}",
          "${bookingFinalization.check_out}",
          "${bookingFinalization.check_out_timestamp}",
          "${bookingFinalization.duration}",
          "${bookingFinalization.duration_text}",
          "${bookingFinalization.price}",
          "${bookingFinalization.price_text}"
        );
        `,
        `
          UPDATE Bookings AS a
          INNER JOIN users AS b ON a.user_email = b.email
          SET a.user_id = b.id
          WHERE a.user_email="${bookingFinalization.email}";
        `,
        `SELECT * FROM Bookings;`
      ];
      await databaseMysql.mysqlSingleThreadHandler(sqlQueries);

    } catch (err) {
      await helpers.LoggerError(err);
    }
    await client.quit();
  } catch (err) {
    await helpers.LoggerError(err);
  }
}

/*
RabbitMq
# node --env-file=node.env ./workers/worker-rabbitmq.js
*/
async function pollRabbitQueue() {
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

    await channel.assertQueue(queue, {
      durable: true,
      arguments: { 'x-queue-type': 'quorum' }
    });

    await helpers.LoggerInfo(` [*] Waiting for messages in ${queue}. To exit press CTRL+C`);

    channel.consume(queue, async function(msg) {
      await helpers.LoggerInfo(` [x] Received ${msg.content.toString()}`);
      // Fetch key in Redis
      await fetchFromRedis(msg.content.toString());
    }, {
      noAck: true
    });
  } catch (err) {
    await helpers.LoggerError(err);
  }
}

pollRabbitQueue();
