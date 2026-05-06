function FunctionCapitalizeFirstLetter(msg) {
  if (!msg) {
    return msg
  }
  return `${msg.charAt(0).toUpperCase()}${msg.slice(1).toLowerCase()}`;
}

export default FunctionCapitalizeFirstLetter;
