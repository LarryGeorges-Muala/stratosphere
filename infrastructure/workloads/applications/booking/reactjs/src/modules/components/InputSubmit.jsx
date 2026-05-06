function InputSubmit({
    divClassName,
    ref,
    name,
    inputValue,
    inputClassName,
    inputOnClick
  }) {
  return (
    <div className={ divClassName }>
      <br />
      <input type="submit" ref={ ref } name={ name } id={ name } value={ inputValue } className={ inputClassName } onClick={ inputOnClick } />
      <br />
    </div>
  );
}

export default InputSubmit;
