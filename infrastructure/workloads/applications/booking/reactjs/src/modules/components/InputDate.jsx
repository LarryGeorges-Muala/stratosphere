function InputDate({
    divClassName,
    labelClassName,
    name,
    labelText,
    ref,
    min,
    max,
    inputClassName,
    inputOnChange,
    inputValue,
    required,
    readOnly
  }) {
  return (
    <div className={ divClassName }>
      <label className={ labelClassName } htmlFor={ name }>{ labelText }</label><br />
      <input type="date" name={ name } id={ name } ref={ ref } min={ min } max={ max } className={ inputClassName } onChange={ inputOnChange } value={ inputValue } required={ required } readOnly={ readOnly } /><br />
    </div>
  );
}

export default InputDate;
