import Modal from './components/Modal'
import TextArea from './components/TextArea'
import Button from './components/Button'
import LoggerError from './components/LoggerError'
import LoggerInfo from './components/LoggerInfo'

function ModalDashboard (props) {

  /* Form Dashboard */
  function GenerateDashboard() {

    /* Handle Errors */
    function DisplayErrors(msg) {
      props.setModalDashboardErrorMessage(msg);
      setTimeout(() => {
        props.setModalDashboardErrorMessage('');
      }, 10000);
    }

    /* Form submit handle */
    const LoadDashboard = async (event) => {
      try {
        event.preventDefault();

        DisplayErrors('');

        try {
          const accessClient = props.ip;
          const userEmail = props.email;
          const data = {
            'accessClient': accessClient,
            'email': userEmail
          }
          // LoggerInfo(data);
          const response = await fetch(`${import.meta.env.VITE_BACKEND}/booking/dashboard/`, {
            method: "POST",
            headers: {
              'Content-Type': 'application/json'
            },
            body: JSON.stringify(data)
          });
          let result = await response.json();
          result = JSON.stringify(result);
          result = JSON.parse(result);
          // LoggerInfo(typeof result);
          // LoggerInfo(`Success: ${result}`);
          // LoggerInfo(result[0]);

          props.setModalDashboardData(JSON.stringify(result, null, 2));
        } catch (err) {
          LoggerError(err);
        }

      } catch (err) {
        DisplayErrors(`Oops! Something went wrong and your dashboard couldn't be processed... We apologize for the technicality and please try again later.`);
        LoggerError(err);
      }
    };

    return (
      <div>
        <div className='modal-component-general-container'>
          <br /><br />
          <TextArea
            name="modal-component-dashboard-textarea"
            className="modal-component-textarea modal-component-text-left"
            defaultValue={props.modalDashboardData}
            readOnly={true}
          />
          <br /><br />
        </div>
        <div>
          <Button
            text='Load Dashboard'
            type='button'
            className='modal-component-button modal-component-green'
            onClick={LoadDashboard}
          />
        </div>
      </div>
    );
  }

  /* Component */
  return (
    <div>
      {/* Modal Dashboard */}
      <Modal
        id='dashboard-modal'
        header='Dashboard'
        modalErrorMessage={props.modalDashboardErrorMessage}
        toggleModal={props.toggleDashboardModal}
        HideModalFunction={() => {props.setToggleDashboardModal('hide-modal');}}
      >
        { GenerateDashboard() }
      </Modal>
      {/* End Modal Dashboard */}
    </div>
  );
}

export default ModalDashboard;
