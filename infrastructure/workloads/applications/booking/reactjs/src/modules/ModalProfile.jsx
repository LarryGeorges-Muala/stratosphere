import React, { useRef } from 'react'
import Button from './components/Button'
import Modal from './components/Modal'
import InputText from './components/InputText'
import InputEmail from './components/InputEmail'
import InputPhone from './components/InputPhone'
import InputSubmit from './components/InputSubmit'
import LoggerError from './components/LoggerError'
import LoggerInfo from './components/LoggerInfo'
import FunctionCapitalizeFirstLetter from './components/FunctionCapitalizeFirstLetter'

function ModalProfile (props) {

  function GenerateProfile() {

    /* Form */
    const formRef = useRef(null);

    /* Handle Modal */
    function CloseModal() {
      props.HideModalFunction();
      DisplayErrors('');
    }

    /* Reset Password */
    function HandleResetPassword(){
      CloseModal();
      props.ResetEmailLoginRegisterFunction(props.email);
      props.setModalRecoveryRequestOrigin('profile');
      props.ShowRecoveryModalFunction();
    }

    /* Handle Errors */
    function DisplayErrors(msg) {
      props.setModalProfileErrorMessage(msg);
      setTimeout(() => {
        props.setModalProfileErrorMessage('');
      }, 10000);
    }

    /* Form submit handle */
    const HandleProfile = async (event) => {
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
              // JWT Token
              const accessToken = props.token;
              // Client
              const accessClient = props.ip;
              // Payload
              const sessionObj = {
                'accessToken': accessToken,
                'accessClient': accessClient,
                'username': data.username,
                'userId': data.email,
                'firstname': data.firstname,
                'surname': data.surname,
                'email': data.email,
                'title': data.title,
                'phone': data.phone
              }
              const updateUser = await fetch(`${import.meta.env.VITE_BACKEND}/users/profile/`, {
                method: "POST",
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': `Bearer ${accessToken}`,
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

                    // Create Redis Session
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
                    props.TitleFunction(FunctionCapitalizeFirstLetter(data.title));
                    props.EmailFunction(data.email);
                    props.FirstnameFunction(FunctionCapitalizeFirstLetter(data.firstname));
                    props.SurnameFunction(FunctionCapitalizeFirstLetter(data.surname));
                    props.PhoneNumberFunction(data.phone);

                    // Lock changing email unless logging out
                    props.EmailReadOnlyFunction(true);

                    CloseModal();

                  } else {
                    DisplayErrors(`Oops! Something went wrong and your update couldn't be processed... We apologize for the technicality and please try again later.`);
                  }
                } else {
                  DisplayErrors(`Oops! Something went wrong and your update couldn't be processed... We apologize for the technicality and please try again later.`);
                }
              } else {
                DisplayErrors(`Oops! Something went wrong and your update couldn't be processed... We apologize for the technicality and please try again later.`);
              }

            } else {
              // LoggerInfo("CREATE USER");
              DisplayErrors('Account not found... Please register...');
            }

            // form.reset();

          } catch (error) {
            DisplayErrors(`Oops! Something went wrong and your update couldn't be processed... We apologize for the technicality and please try again later.`);
            LoggerError(error);
          }

        }
      } catch (err) {
        DisplayErrors(`Oops! Something went wrong and your update couldn't be processed... We apologize for the technicality and please try again later.`);
        LoggerError(err);
      }
    };

    /* Component */
    return (
      <div>
      {/* Content */}
        {/* Form */}
        <form id="modal-form-profile" ref={formRef} onSubmit={HandleProfile}>
          {/* Title */}
          <InputText
            name='title'
            labelText='Title:'
            inputDefaultValue={props.title}
            divClassName='modal-component-form-container'
            labelClassName='label'
            autoComplete='on'
            required={true}
            inputOnChange={ (event) => {props.TitleFunction(event.target.value)} }
          />
          {/* Firstname */}
          <InputText
            name='firstname'
            labelText='First name:'
            inputDefaultValue={props.firstname}
            divClassName='modal-component-form-container'
            labelClassName='label'
            autoComplete='on'
            required={true}
            inputOnChange={ (event) => {props.FirstnameFunction(event.target.value)} }
          />
          {/* Surname */}
          <InputText
            name='surname'
            labelText='Last name:'
            inputDefaultValue={props.surname}
            divClassName='modal-component-form-container'
            labelClassName='label'
            autoComplete='on'
            required={true}
            inputOnChange={ (event) => {props.SurnameFunction(event.target.value)} }
          />
          {/* Email */}
          <InputEmail
            name='email'
            labelText='Email:'
            inputDefaultValue={props.email}
            divClassName='modal-component-form-container'
            inputClassName='form-container-element-read-only'
            labelClassName='label'
            autoComplete='on'
            required={true}
            readOnly={ props.emailReadOnly }
            inputOnChange={ (event) => {props.EmailFunction(event.target.value)} }
          />
          {/* Phone */}
          <InputPhone
            name='phone'
            labelText='Phone number:'
            inputDefaultValue={props.phoneNumber}
            divClassName='modal-component-form-container'
            labelClassName='label'
            autoComplete='on'
            required={true}
            inputOnChange={ (event) => {props.PhoneNumberFunction(event.target.value)} }
          />
          {/* Submit */}
          <InputSubmit
            name='submit-button'
            inputValue='Update Profile'
            divClassName='modal-component-form-container'
            inputClassName='modal-component-submit-button'
          />
        </form>
        {/* Reset */}
        <br />
        <Button
          text='Change password?'
          type='button'
          className='modal-component-button'
          onClick={HandleResetPassword}
        />
      {/* End Content */}
      </div>
    );
  }

  return (
    <div>
      {/* Modal Profile */}
      <Modal
        id='profile-modal'
        header='Profile'
        modalErrorMessage={props.modalProfileErrorMessage}
        toggleModal={props.toggleProfileModal}
        HideModalFunction={() => {
          props.setToggleProfileModal('hide-modal');
          props.ResetEmailLoginRegisterFunction('');
          props.setModalRecoveryRequestOrigin('');
        }}
      >
        { GenerateProfile() }
      </Modal>
      {/* End Modal Profile */}
    </div>
  );
}

export default ModalProfile;
