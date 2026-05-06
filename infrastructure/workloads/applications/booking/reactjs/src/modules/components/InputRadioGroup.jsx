function InputRadioGroup({
    children,
    divClassName,
    description,
    groupDivClassName
  }) {
  return (
    <div className={ divClassName }>
      <p>{ description }</p>
      <div className={ groupDivClassName }>
        { children }
      </div>
    </div>
  );
}

export default InputRadioGroup;
