import Button from "./Button"
import TextArea from "./TextArea"

function Modal (props) {

  function HandleCloseModal() {
    props.HideModalFunction();
  }

  return (
    <div id={ props.id } className={ props.toggleModal }>
      <div className="modal-component-content">
        <span className="modal-component-close" onClick={HandleCloseModal}>&times;</span>

        {/* Header */}
        <h2>{ props.header }</h2>
        <hr />

        <div>
          {/* Content */}
          { props.children }
          {/* End Content */}
        </div>

        {/* Errors Handler */}
        { props.modalErrorMessage &&
        <div className='modal-component-textarea-container'>
          <TextArea name="modal-component-textarea-errors" className="modal-component-textarea-errors" defaultValue={ props.modalErrorMessage } readOnly={true} />
        </div>
        }

        {/* Close */}
        <Button type='button' text='Close' divClassName='modal-component-button-container' className='modal-component-close-button' onClick={HandleCloseModal} />

      </div>
    </div>
  );
}

export default Modal;
