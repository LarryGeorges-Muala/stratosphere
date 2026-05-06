function InputPhone({
    divClassName,
    labelClassName,
    name,
    labelText,
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
      <input ref={ ref } type="tel" placeholder=">" className={ inputClassName } onChange={ inputOnChange } name={ name } id={ name } defaultValue={ inputDefaultValue } autoComplete={ autoComplete } required={ required } readOnly={ readOnly } />
    </div>
  );
}

export default InputPhone;
