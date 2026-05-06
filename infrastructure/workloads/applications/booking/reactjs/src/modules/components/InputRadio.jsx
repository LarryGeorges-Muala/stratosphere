function InputRadio({
    name,
    inputId,
    ref,
    inputValue,
    inputClassName,
    inputOnChange,
    defaultChecked,
    labelClassName,
    labelText
  }) {
  return (
    <span>
      <input type="radio" name={ name } id={ inputId } ref={ ref } value={ inputValue } className={ inputClassName } onChange={ inputOnChange } defaultChecked={ defaultChecked } />
      <label className={ labelClassName } htmlFor={ inputId }>{ labelText }</label>
    </span>
  );
}

export default InputRadio;
