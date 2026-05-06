function TextArea({
    id,
    name,
    ref,
    className,
    defaultValue,
    readOnly
  }) {
  return (
    <textarea id={id} name={name} ref={ref} className={className} rows="4" cols="50" defaultValue={defaultValue} readOnly={readOnly}></textarea>
  );
}

export default TextArea;
