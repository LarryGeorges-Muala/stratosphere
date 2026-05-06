function Button({
    divClassName,
    type,
    ref,
    name,
    className,
    onClick,
    text
  }) {
  return (
    <div className={ divClassName }>
      <button type={ type } ref={ ref } id={ name } className={ className } onClick={ onClick } >{ text }</button>
    </div>
  );
}

export default Button;
