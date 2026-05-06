const databaseMysql = require(`../_mysql_modules`);
const helpers = require(`../_helpers_modules`);

/*
DB Migration
# node --env-file=node.env worker-mysql.js
# node --env-file=node.env ./workers/worker-mysql.js
*/
const sqlQueries = [
  `DROP TABLE IF EXISTS Bookings;`,
  `CREATE TABLE IF NOT EXISTS Bookings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(100) NULL DEFAULT NULL,
    booking_id VARCHAR(255) UNIQUE NOT NULL,
    user_email VARCHAR(255) NOT NULL,
    origin VARCHAR(255) NOT NULL,
    guests VARCHAR(255) NOT NULL,
    breakfast VARCHAR(255) NOT NULL,
    check_in VARCHAR(255) NOT NULL,
    check_in_timestamp VARCHAR(255) NOT NULL,
    check_out VARCHAR(255) NOT NULL,
    check_out_timestamp VARCHAR(255) NOT NULL,
    duration VARCHAR(50) NOT NULL,
    duration_text VARCHAR(50) NOT NULL,
    price VARCHAR(50) NOT NULL,
    price_text VARCHAR(50) NOT NULL,
    registration_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
  );
  `
];

helpers.LoggerInfo("Warming up migration system...");
setTimeout(
  async () => {
    try {
      await helpers.LoggerInfo("Starting migration worker...");
      await databaseMysql.mysqlSingleThreadHandler(sqlQueries);
    } catch (err) {
      await helpers.LoggerError(err);
    }
  },
  10000
);
