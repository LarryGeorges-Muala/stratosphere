const mysql = require('mysql2');
const helpers = require(`./_helpers_modules`);

/*
Queries Runner
*/
const mysqlSingleThreadHandler = async (sqlQuery) => {
  try {
    const connection = mysql.createConnection({
      host: 'mysql',
      user: 'booking',
      password: process.env.MYSQL_PASSWORD,
      database: 'booking',
      port: 3306
    });

    // Connect to MySQL
    connection.connect( async (err) => {
      if (err) {
        await helpers.LoggerError(`Error connecting to MySQL: ${err.stack}`);
        return;
      }
      await helpers.LoggerInfo(`Connected to MySQL as id ${connection.threadId}`);

      sqlQuery.forEach(
        (entry, index) => {
          // Execute Query
          connection.query(
            `${entry}`, 
            async (error, results) => {
              await helpers.LoggerInfo(`running '${entry}'`);

              if (error) {
                await helpers.LoggerInfo(error);
              }
              await helpers.LoggerInfo(results);

              if (index == (sqlQuery.length - 1)) {
                // Close connection
                connection.end(async (err) => {
                  if (err) {
                    await helpers.LoggerError(`Error closing MySQL connection: ${err.stack}`);
                  } else {
                    await helpers.LoggerInfo('MySQL connection closed.');
                  }
                });
              }
            }
          );
        }
      );
    });
  } catch (err) {
    await helpers.LoggerError(err);
  }
}

/*
Exports
*/
module.exports = {
  mysqlSingleThreadHandler
};
