import Modal from './components/Modal'
import Button from './components/Button'
import LoggerError from './components/LoggerError'
import LoggerInfo from './components/LoggerInfo'

function ModalLogout (props) {

  function GenerateLogout() {
    /* Handle Modal */
    function closeModal() {
      props.HideModalFunction();
      DisplayErrors('');
    }

    /* Handle Errors */
    function DisplayErrors(msg) {
      props.setModalLogoutErrorMessage(msg);
      setTimeout(() => {
        props.setModalLogoutErrorMessage('');
      }, 10000);
    }

    /* Form submit handle */
    const HandleLogout = async (event) => {
      try {
        event.preventDefault();

        DisplayErrors('');

        try {
          const accessClient = props.ip;
          const data = {
            'accessClient': accessClient
          }
          // LoggerInfo(data);
          const response = await fetch(`${import.meta.env.VITE_BACKEND}/booking/reset/`, {
            method: "POST",
            headers: {
              'Content-Type': 'application/json'
            },
            body: JSON.stringify(data)
          });
          await response.json();
          // let result = await response.json();
          // result = JSON.stringify(result);
          // result = JSON.parse(result);
          // LoggerInfo(typeof result);
          // LoggerInfo(`Success: ${result}`);
        } catch (err) {
          LoggerError(err);
        }

        props.setToken('');
        props.EmailFunction('');
        props.EmailReadOnlyFunction(false);
        props.FirstnameFunction('');
        props.SurnameFunction('');
        props.TitleFunction('');
        props.PhoneNumberFunction('');

        // Disable Logged in options
        props.setUserLoggedIn(false);

        closeModal();

      } catch (err) {
        DisplayErrors(`Oops! Something went wrong and your logout couldn't be processed... We apologize for the technicality and please try again later.`);
        LoggerError(err);
      }
    };

    /* Component */
    return (
      <div>
        {/* Content */}
          <div className='modal-component-general-container'>
            <br /><br />
            <p>Would you like to logout?</p>
            <br /><br />
          </div>
          <div>
            <Button
              text='Logout'
              type='button'
              className="modal-component-button"
              onClick={HandleLogout}
            />
          </div>
        {/* End Content */}
      </div>
    );
  }

  return (
    <div>
      {/* Modal Logout */}
      <Modal
        id='logout-modal'
        header='Logout'
        modalErrorMessage={props.modalLogoutErrorMessage}
        toggleModal={props.toggleLogoutModal}
        HideModalFunction={() => {props.setToggleLogoutModal('hide-modal');}}
      >
        { GenerateLogout() }
      </Modal>
      {/* End Modal Logout */}
    </div>
  );
}

export default ModalLogout;
