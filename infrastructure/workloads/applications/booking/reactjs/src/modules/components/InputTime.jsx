function InputTime({
    divClassName,
    labelClassName,
    name,
    labelText,
    ref,
    inputClassName,
    inputOnChange,
    inputDefaultValue,
    required,
    readOnly
  }) {
  return (
    <div className={ divClassName }>
      <label className={ labelClassName } htmlFor={ name }>{ labelText }</label><br />
      <input ref={ ref } type="time" className={ inputClassName } onChange={ inputOnChange } name={ name } id={ name } defaultValue={ inputDefaultValue } required={ required } readOnly={ readOnly } />
    </div>
  );
}

export default InputTime;
