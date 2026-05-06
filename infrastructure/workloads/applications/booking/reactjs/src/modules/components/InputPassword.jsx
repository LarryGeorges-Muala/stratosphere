function InputPassword({
    divClassName,
    labelClassName,
    name,
    labelText,
    type,
    ref,
    inputClassName,
    inputOnChange,
    inputDefaultValue,
    autoComplete,
    required,
    readOnly
  }) {
  return (
    <div className={ divClassName }>
      <label className={ labelClassName } htmlFor={ name }>{ labelText }</label><br />
      <input type={ type } ref={ ref } placeholder=">" className={ inputClassName } onChange={ inputOnChange } name={ name } id={ name } defaultValue={ inputDefaultValue } autoComplete={ autoComplete } required={ required } readOnly={ readOnly } />
    </div>
  );
}

export default InputPassword;
