function InputNumber({
    divClassName,
    labelClassName,
    name,
    labelText,
    ref,
    min,
    max,
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
      <input ref={ ref } type="number" placeholder=">" min={ min } max={ max } className={ inputClassName } onChange={ inputOnChange } name={ name } id={ name } defaultValue={ inputDefaultValue } autoComplete={ autoComplete } required={ required } readOnly={ readOnly } />
    </div>
  );
}

export default InputNumber;
