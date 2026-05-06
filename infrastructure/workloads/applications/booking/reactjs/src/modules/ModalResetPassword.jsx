import React, { useState, useRef } from 'react'
import Modal from './components/Modal'
import InputEmail from './components/InputEmail'
import InputPassword from './components/InputPassword'
import InputPasswordConfirm from './components/InputPasswordConfirm'
import InputPasswordShow from './components/InputPasswordShow'
import InputSubmit from './components/InputSubmit'
import LoggerError from './components/LoggerError'
import LoggerInfo from './components/LoggerInfo'

function ModalResetPassword (props) {

  /* Form */
  const formRef = useRef(null);

  /* Handle Form */
  function ManualFormReset() {
    formRef.current?.reset();
  }

  function GenerateRecovery() {

    /* Handle Passwords */
    const [password, setPassword] = useState('');
    const [passwordConfirm, setPasswordConfirm] = useState('');
    const [passwordType, setPasswordType] = useState('password');

    /* Handle Modal */
    function closeModal() {
      props.HideModalFunction();
      formRef.current?.reset();
      DisplayErrors('');
    }

    /* Handle Errors */
    function DisplayErrors(msg) {
      props.setModalRecoveryErrorMessage(msg);
      setTimeout(() => {
        props.setModalRecoveryErrorMessage('');
      }, 10000);
    }

    /* Form submit handle */
    const HandleRecovery = async (event) => {
      try {
        // Prevent the browser from reloading the page
        event.preventDefault();

        DisplayErrors('');

        const form = formRef.current;
        if (form.reportValidity()) {
          const formData = new FormData(form);
          const data = Object.fromEntries(formData.entries());

          // LoggerInfo(data);

          try {
            const response = await fetch(`${import.meta.env.VITE_BACKEND}/users/verify/`, {
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

            if (result.length !== 0) {
              // LoggerInfo("USER EXISTS");
              const accessClient = props.ip;
              const sessionObj = {
                'accessClient': accessClient,
                'password': data.password,
                'email': data.email
              }
              // LoggerInfo(sessionObj);
              const updateUser = await fetch(`${import.meta.env.VITE_BACKEND}/users/reset/`, {
                method: "POST",
                headers: {
                  'Content-Type': 'application/json'
                },
                body: JSON.stringify(sessionObj)
              });
              let updateUserResult = await updateUser.json();
              updateUserResult = JSON.stringify(updateUserResult);
              updateUserResult = JSON.parse(updateUserResult);
              // LoggerInfo(typeof updateUserResult);
              // LoggerInfo(`Success: ${updateUserResult}`);
              // LoggerInfo(updateUserResult.accessToken);

              if (updateUserResult) {
                if (Object.hasOwn(updateUserResult, 'valid')) {
                  if (updateUserResult.valid) {

                    props.EmailFunction(data.email);

                    if (props.modalRecoveryRequestOrigin === 'profile') {
                      props.ShowProfileModalFunction();
                    }
                    if (props.modalRecoveryRequestOrigin === 'login') {
                      props.ShowLoginModalFunction();
                    }

                  } else {
                    DisplayErrors(`Oops! Something went wrong and your recovery couldn't be processed... We apologize for the technicality and please try again later.`);
                  }
                } else {
                  DisplayErrors(`Oops! Something went wrong and your recovery couldn't be processed... We apologize for the technicality and please try again later.`);
                }
              } else {
                DisplayErrors(`Oops! Something went wrong and your recovery couldn't be processed... We apologize for the technicality and please try again later.`);
              }

            } else {
              // LoggerInfo("CREATE USER");
              DisplayErrors(`Account not found... Please try again with a valid email address or register a new account...`);
            }
            closeModal();
            form.reset();

          } catch (error) {
            DisplayErrors(`Oops! Something went wrong and your recovery couldn't be processed... We apologize for the technicality and please try again later.`);
            LoggerError(error);
          }

        }
      } catch (err) {
        DisplayErrors(`Oops! Something went wrong and your recovery couldn't be processed... We apologize for the technicality and please try again later.`);
        LoggerError(err);
      }
    };

    /* Component */
    return (
      <div>
        {/* Content */}
        {/* Form */}
        <form id="modal-form-recovery" ref={formRef} onSubmit={HandleRecovery}>
          {/* Email */}
          <InputEmail
            name='email'
            labelText='Email:'
            inputDefaultValue={props.emailLoginRegister}
            divClassName='modal-component-form-container'
            labelClassName='label'
            autoComplete='on'
            required={true} 
          />
          {/* Password */}
          <InputPassword
            type={passwordType}
            name='password'
            labelText='Password:'
            divClassName='modal-component-form-container'
            labelClassName='label'
            autoComplete='off'
            required={true}
            inputOnChange={(event) => {setPassword(event.target.value);}}
          />
          <InputPasswordConfirm
            type={passwordType}
            name='password-confirm'
            labelText='Confirm password:'
            divClassName='modal-component-form-container'
            labelClassName='label'
            autoComplete='off'
            required={true}
            inputOnChange={(event) => {setPasswordConfirm(event.target.value);}}
            password={password}
            passwordConfirm={passwordConfirm}
          />
          <InputPasswordShow
            divClassName='modal-component-form-container'
            inputClassName='modal-component-form-password-show'
            labelClassName='modal-component-form-password-show-label'
            showPassword={(event) => { event.target.checked ? setPasswordType('text') : setPasswordType('password');} } 
          />
          {/* Submit */}
          <InputSubmit
            name='submit-button'
            inputValue='Submit'
            divClassName='modal-component-form-container'
            inputClassName='modal-component-submit-button'
          />
        </form>
        {/* End Content */}
      </div>
    );
  }

  return (
    <div>
      {/* Modal Recovery */}
      <Modal
        id='recovery-modal'
        header='Recovery'
        modalErrorMessage={props.modalRecoveryErrorMessage}
        toggleModal={props.toggleRecoveryModal}
        HideModalFunction={() => {
          props.setToggleRecoveryModal('hide-modal');
          props.ResetEmailLoginRegisterFunction('');
          ManualFormReset();
        }}
      >
        { GenerateRecovery() }
      </Modal>
      {/* End Modal Recovery */}
    </div>
  );
}

export default ModalResetPassword;
