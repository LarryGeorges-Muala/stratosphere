function InputHidden({
    id,
    name,
    ref,
    inputDefaultValue,
    readOnly
  }) {
  return (
    <input type="hidden" id={ id } name={ name } ref={ ref } defaultValue={ inputDefaultValue } readOnly={ readOnly } />
  );
}

export default InputHidden;
