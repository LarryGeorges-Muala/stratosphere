function InputPasswordShow({
    divClassName,
    ref,
    inputClassName,
    labelClassName,
    showPassword
  }) {
  return (
    <div className={ divClassName }>
      {/* Password Show */}
      <input ref={ ref } type="checkbox" className={ inputClassName } onClick={ showPassword } onChange={ showPassword } /><span className={ labelClassName }>Show password</span>
    </div>
  );
}

export default InputPasswordShow;
