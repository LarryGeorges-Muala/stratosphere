function InputText({
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
      <input ref={ ref } type="text" placeholder=">" className={ inputClassName } onChange={ inputOnChange } name={ name } id={ name } defaultValue={ inputDefaultValue } autoComplete={ autoComplete } required={ required } readOnly={ readOnly } />
    </div>
  );
}

export default InputText;
