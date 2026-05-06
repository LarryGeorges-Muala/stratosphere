import * as Sentry from '@sentry/react'

function LoggerError(msg) {
  const ENV = (import.meta.env.VITE_ENV).toString().toLowerCase();
  const PROD = ["prod", "production"];
  if (!PROD.includes(ENV)) {
    console.log('\n............................');
    console.error(`${msg}`);
    console.log(new Error().stack);
    console.log('............................\n');
  }
  // throw new Error(`${msg}`);
};

export default LoggerError;
