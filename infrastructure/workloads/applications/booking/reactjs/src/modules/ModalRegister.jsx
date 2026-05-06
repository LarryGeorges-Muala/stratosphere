import React, { useState, useRef } from 'react'
import Modal from './components/Modal'
import InputText from './components/InputText'
import InputEmail from './components/InputEmail'
import InputPassword from './components/InputPassword'
import InputPasswordConfirm from './components/InputPasswordConfirm'
import InputPasswordShow from './components/InputPasswordShow'
import InputSubmit from './components/InputSubmit'
import Button from './components/Button'
import LoggerError from './components/LoggerError'
import LoggerInfo from './components/LoggerInfo'
import FunctionCapitalizeFirstLetter from './components/FunctionCapitalizeFirstLetter'

function ModalRegister (props) {

  /* Handle Passwords */
  const [password, setPassword] = useState('');
  const [passwordConfirm, setPasswordConfirm] = useState('');
  const [passwordType, setPasswordType] = useState('password');
  /* Swicth to Login */
  const [switchToLogin, setSwitchToLogin] = useState(false);
  /* Form */
  const formRef = useRef(null);

  /* Handle Form */
  function ManualFormReset() {
    formRef.current?.reset();
    setPassword('');
  }

  function GenerateRegistration() {

    /* Handle Modal */
    function CloseModal() {
      props.HideModalFunction();
      formRef.current?.reset();
      setSwitchToLogin(false);
      DisplayErrors('');
    }

    /* Handle Errors */
    function DisplayErrors(msg) {
      props.setModalRegisterErrorMessage(msg);
      setTimeout(() => {
        props.setModalRegisterErrorMessage('');
      }, 10000);
    }

    /* Switch Modal */
    function EnableSwicthModal() {
      DisplayErrors(`Existing account... Please login...`);
      setSwitchToLogin(true);
    }
    function SwicthModal() {
      CloseModal();
      props.ShowLoginModalFunction();
    }

    /* Form submit handle */
    const HandleRegistration = async (event) => {
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

            if (result.length === 0) {
              // LoggerInfo("CREATE USER");
              const createUser = await fetch(`${import.meta.env.VITE_BACKEND}/users/`, {
                method: "POST",
                headers: {
                  'Content-Type': 'application/json'
                },
                body: JSON.stringify(data)
              });
              let createUserResult = await createUser.json();
              createUserResult = JSON.stringify(createUserResult);
              createUserResult = JSON.parse(createUserResult);
              // LoggerInfo(typeof createUserResult);
              // LoggerInfo(`Success: ${createUserResult}`);
              // LoggerInfo(createUserResult.accessToken);

              // Issue JWT Token
              props.setToken(createUserResult.accessToken);

              // Create Redis Session
              const accessClient = props.ip;
              const sessionObj = {
                'accessToken': createUserResult.accessToken,
                'accessClient': accessClient,
                'username': createUserResult.username,
                'userId': createUserResult.userId,
                'firstname': data.firstname,
                'surname': data.surname,
                'email': data.email,
                'title': '',
                'phone': ''
              }
              // LoggerInfo("CREATE SESSION");
              const createSession = await fetch(`${import.meta.env.VITE_BACKEND}/booking/session/`, {
                method: "POST",
                headers: {
                  'Content-Type': 'application/json'
                },
                body: JSON.stringify(sessionObj)
              });
              await createSession.json();
              // let createSessionResult = await createSession.json();
              // createSessionResult = JSON.stringify(createSessionResult);
              // createSessionResult = JSON.parse(createSessionResult);
              // LoggerInfo(typeof createSessionResult);
              // LoggerInfo(`Success: ${createSessionResult}`);
              // LoggerInfo(createSessionResult.message);

              // Pre-fill booking fields
              props.ResetEmailLoginRegisterFunction('');
              props.EmailFunction(data.email);
              props.FirstnameFunction(FunctionCapitalizeFirstLetter(data.firstname));
              props.SurnameFunction(FunctionCapitalizeFirstLetter(data.surname));
              props.TitleFunction('');
              props.PhoneNumberFunction('');

              // Lock changing email unless logging out
              props.EmailReadOnlyFunction(true);

              // Enable Logged in options
              props.setUserLoggedIn(true);

              CloseModal();
            } else {
              // LoggerInfo("USER EXISTS");
              EnableSwicthModal();
            }

            form.reset();

          } catch (error) {
            DisplayErrors(`Oops! Something went wrong and your registration couldn't be processed... We apologize for the technicality and please try again later.`);
            LoggerError(error);
          }

        }
      } catch (err) {
        DisplayErrors(`Oops! Something went wrong and your registration couldn't be processed... We apologize for the technicality and please try again later.`);
        LoggerError(err);
      }
    };

    /* Component */
    return (
      <div>
      {/* Content */}
        {/* Form */}
        <form id="modal-form-register" ref={formRef} onSubmit={HandleRegistration}>
          {/* Firstname */}
          <InputText
            name='firstname'
            labelText='First name:'
            divClassName='modal-component-form-container'
            labelClassName='label'
            autoComplete='on'
            required={true}
          />
          {/* Surname */}
          <InputText
            name='surname'
            labelText='Last name:'
            divClassName='modal-component-form-container'
            labelClassName='label'
            autoComplete='on'
            required={true}
          />
          {/* Email */}
          <InputEmail
            name='email'
            labelText='Email:'
            inputDefaultValue={props.emailLoginRegister}
            divClassName='modal-component-form-container'
            labelClassName='label'
            autoComplete='on'
            required={true}
            inputOnChange={ props.EmailLoginRegisterFunction }
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
          { !switchToLogin &&
          <InputSubmit
            name='submit-button'
            inputValue='Submit'
            divClassName='modal-component-form-container'
            inputClassName='modal-component-submit-button'
          />
          }
          {/* Alt Button */}
          { switchToLogin &&
          <Button
            text='Login'
            type='button'
            className='modal-component-button'
            onClick={SwicthModal}
          />
          }
        </form>
      {/* End Content */}
      </div>
    );
  }

  return (
    <div>
      {/* Modal Register */}
      <Modal
        id='register-modal'
        header='Register'
        modalErrorMessage={props.modalRegisterErrorMessage}
        toggleModal={props.toggleRegisterModal}
        HideModalFunction={() => {
          props.setToggleRegisterModal('hide-modal');
          props.ResetEmailLoginRegisterFunction('');
          ManualFormReset();
        }}
      >
        { GenerateRegistration() }
      </Modal>
      {/* End Modal Register */}
    </div>
  );
}

export default ModalRegister;
