
function LoggerInfo(msg) {
  const ENV = (import.meta.env.VITE_ENV).toString().toLowerCase();
  const PROD = ["prod", "production"];
  if (!PROD.includes(ENV)) {
    console.log('\n............................');
    console.log(msg);
    console.trace();
    console.log('............................\n');
  }
};

export default LoggerInfo;
