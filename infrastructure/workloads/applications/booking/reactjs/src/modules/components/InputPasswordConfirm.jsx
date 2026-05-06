function InputPasswordConfirm({
    divClassName,
    labelText,
    labelClassName,
    name,
    password,
    passwordConfirm,
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
      {/* Password Confirm */}
      <label className={ labelClassName } htmlFor={ name }>{ labelText }</label>
      { (password && passwordConfirm) &&
        <span>
          { (password !== passwordConfirm) &&
          <span>✘</span>
          }
          { (password === passwordConfirm) &&
          <span>✔</span>
          }
        </span>
      }
      <br />
      <input type={ type } ref={ ref } placeholder=">" className={ inputClassName } onChange={ inputOnChange } name={ name } id={ name } defaultValue={ inputDefaultValue } autoComplete={ autoComplete } required={ required } readOnly={ readOnly } />
    </div>
  );
}

export default InputPasswordConfirm;
