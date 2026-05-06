import React, { useState, useEffect } from 'react'
import InputHidden from './components/InputHidden'
import ModalRegister from './ModalRegister'
import ModalLogin from './ModalLogin'
import ModalLogout from './ModalLogout'
import ModalResetPassword from './ModalResetPassword'
import ModalProfile from './ModalProfile'
import ModalDashboard from './ModalDashboard'
import LoggerError from './components/LoggerError'
import LoggerInfo from './components/LoggerInfo'
import FunctionCapitalizeFirstLetter from './components/FunctionCapitalizeFirstLetter'

function Nav (props) {

  /* User IP */
  const [ip, setIp] = useState('');
  /* User Token */
  const [token, setToken] = useState('');
  /* Modal toggle - Options: show-modal, hide-modal */
  const [toggleDashboardModal, setToggleDashboardModal] = useState('hide-modal');
  const [toggleLoginModal, setToggleLoginModal] = useState('hide-modal');
  const [toggleLogoutModal, setToggleLogoutModal] = useState('hide-modal');
  const [toggleRegisterModal, setToggleRegisterModal] = useState('hide-modal');
  const [toggleRecoveryModal, setToggleRecoveryModal] = useState('hide-modal');
  const [toggleProfileModal, setToggleProfileModal] = useState('hide-modal');
  /* Error Handling */
  const [modalDashboardErrorMessage, setModalDashboardErrorMessage] = useState('');
  const [modalLoginErrorMessage, setModalLoginErrorMessage] = useState('');
  const [modalLogoutErrorMessage, setModalLogoutErrorMessage] = useState('');
  const [modalRegisterErrorMessage, setModalRegisterErrorMessage] = useState('');
  const [modalRecoveryErrorMessage, setModalRecoveryErrorMessage] = useState('');
  const [modalProfileErrorMessage, setModalProfileErrorMessage] = useState('');
  /* Modals Data */
  const [modalDashboardData, setModalDashboardData] = useState('');
  const [modalRecoveryRequestOrigin, setModalRecoveryRequestOrigin] = useState('');

  /* User Greeting  */
  function GenerateGreeting() {
    if (props.firstname || props.surname) {
      return (
        <span className='greeting-banner'>Welcome {FunctionCapitalizeFirstLetter(props.title)} {FunctionCapitalizeFirstLetter(props.firstname)} {FunctionCapitalizeFirstLetter(props.surname)}</span>
      );
    } else {
      return (
        <span className='greeting-banner'></span>
      );
    }
  }

  /* User IP + Session */
  let {
    UserLoggedInFunction,
    EmailFunction,
    EmailReadOnlyFunction,
    FirstnameFunction,
    SurnameFunction,
    TitleFunction,
    PhoneNumberFunction,
    setBlockedCalendarEntries,
    setCsrfToken,
    setUnits
  } = props;

  useEffect(() => {
    fetch('https://api.ipify.org?format=json')
      .then(response => response.json())
      .then(data => {
        setIp(data.ip)

        const getCookie = async (name) => {
          let cookieValue = null;
          if (document.cookie && document.cookie !== '') {
              const cookies = document.cookie.split(';');
              for (let i = 0; i < cookies.length; i++) {
                  const cookie = cookies[i].trim();
                  // Does this cookie string begin with the name we want?
                  if (cookie.substring(0, name.length + 1) === (name + '=')) {
                      cookieValue = decodeURIComponent(cookie.substring(name.length + 1));
                      break;
                  }
              }
          }
          return cookieValue;
        };

        /* Check Session */
        const fetchSession = async (ip) => {

          // Fallback Calendar Entries
          const blockedCalendarEntriesArray = [
            new Date("2026-04-24T00:00:00"),
            new Date("2026-04-25T00:00:00"),
            new Date("2026-04-27T00:00:00"),
            new Date("2026-04-29T00:00:00"),
            new Date("2026-05-01T00:00:00"),
            new Date("2026-05-02T00:00:00"),
            new Date("2026-05-03T00:00:00"),
            new Date("2026-05-04T00:00:00"),
            new Date("2026-05-05T00:00:00"),
            new Date("2026-06-01T00:00:00"),
            new Date("2026-06-02T00:00:00"),
            new Date("2026-06-03T00:00:00"),
            new Date("2026-06-04T00:00:00"),
            new Date("2026-06-05T00:00:00"),
            new Date("2026-01-01T00:00:00")
          ];
          blockedCalendarEntriesArray.sort((a, b) => a - b);

          // Start Session Call
          try {

            const data = {
              'accessClient': ip
            }
            // LoggerInfo(data);

            const response = await fetch(`${import.meta.env.VITE_BACKEND}/booking/reload/`, {
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
            // LoggerInfo(result.csrfToken);

            if (result) {
              // Load CSRF Token
              const csrftoken = await getCookie('csrftoken');
              setCsrfToken(csrftoken);

              // Load Units
              if (Object.hasOwn(result, 'units')) {
                setUnits(result.units);
              }

              // Load JWT Token
              if (Object.hasOwn(result, 'accessToken')) {
                setToken(result.accessToken);
                // Enable Logged in options
                UserLoggedInFunction(true);
              }
              // Load blocked dates
              if (Object.hasOwn(result, 'calendar')) {
                let calendar = [];
                (result.calendar).forEach(
                  item => calendar.push(new Date(item))
                );
                setBlockedCalendarEntries(calendar);
              } else {
                setBlockedCalendarEntries(blockedCalendarEntriesArray);
              }
              
              // Pre-fill booking fields
              if (Object.hasOwn(result, 'email')) {
                EmailFunction(result.email);
                // Lock changing email unless logging out
                EmailReadOnlyFunction(true);
              }
              if (Object.hasOwn(result, 'firstname')) {
                FirstnameFunction(result.firstname);
              }
              if (Object.hasOwn(result, 'surname')) {
                SurnameFunction(result.surname);
              }
              if (Object.hasOwn(result, 'title')) {
                TitleFunction(result.title);
              }
              if (Object.hasOwn(result, 'phone')) {
                PhoneNumberFunction(result.phone);
              }
            }

          } catch (error) {
            LoggerError(error);
            setBlockedCalendarEntries(blockedCalendarEntriesArray);
          }
        }

        fetchSession(data.ip)

      })
      .catch(
        error => LoggerError(error)
      );
  }, [
    // UserLoggedInFunction,
    // EmailFunction,
    // EmailReadOnlyFunction,
    // FirstnameFunction,
    // SurnameFunction,
    // TitleFunction,
    // PhoneNumberFunction,
    // setBlockedCalendarEntries
  ]);

  return (
    <div className='greeting-group'>
      <div className='greeting-banner-container'>
        <div>
          { GenerateGreeting() }
        </div>
      </div>
      <div className='greeting-nav-container'>
        <nav>
          { !props.userLoggedIn &&
          <span>
            <button className='greeting-nav-button' onClick={() => {setToggleRegisterModal('show-modal');}}>Register</button> /
          </span>
          }
          { !props.userLoggedIn &&
          <span>
            <button className='greeting-nav-button' onClick={() => {setToggleLoginModal('show-modal');}}>Login</button> /
          </span>
          }
          { props.userLoggedIn &&
          <span>
            <button className='greeting-nav-button' onClick={() => {setToggleLogoutModal('show-modal');}}>Logout</button> /
          </span>
          }
          { props.userLoggedIn &&
          <span>
            <button className='greeting-nav-button' onClick={() => {setToggleProfileModal('show-modal');}}>Profile</button> /
          </span>
          }
          { props.userLoggedIn &&
          <span>
            <button className='greeting-nav-button' onClick={() => {setToggleDashboardModal('show-modal');}}>Dashboard</button> /
          </span>
          }
        </nav>
      </div>
      {/* Modal Register */}
      <ModalRegister
        ip={ip}
        emailLoginRegister={props.emailLoginRegister}
        modalRegisterErrorMessage={modalRegisterErrorMessage}
        setModalRegisterErrorMessage={(msg) => {setModalRegisterErrorMessage(msg);}}
        toggleRegisterModal={toggleRegisterModal}
        setToggleRegisterModal={(x) => {setToggleRegisterModal(x);}}
        setUserLoggedIn={(x) => {props.UserLoggedInFunction(x);}}
        setToken={(x) => {setToken(x);}}
        HideModalFunction={() => {setToggleRegisterModal('hide-modal');}}
        ShowLoginModalFunction={() => {setToggleLoginModal('show-modal');}}
        FirstnameFunction={props.FirstnameFunction}
        SurnameFunction={props.SurnameFunction}
        EmailFunction={props.EmailFunction}
        EmailLoginRegisterFunction={props.EmailLoginRegisterFunction}
        ResetEmailLoginRegisterFunction={props.ResetEmailLoginRegisterFunction}
        EmailReadOnlyFunction={props.EmailReadOnlyFunction}
        TitleFunction={props.TitleFunction}
        PhoneNumberFunction={props.PhoneNumberFunction}
      />
      {/* End Modal Register */}

      {/* Modal Login */}
      <ModalLogin
        ip={ip}
        emailLoginRegister={props.emailLoginRegister}
        modalLoginErrorMessage={modalLoginErrorMessage}
        setModalLoginErrorMessage={(msg) => {setModalLoginErrorMessage(msg);}}
        toggleLoginModal={toggleLoginModal}
        setToggleLoginModal={(x) => {setToggleLoginModal(x);}}
        setUserLoggedIn={(x) => {props.UserLoggedInFunction(x);}}
        setToken={(x) => {setToken(x);}}
        HideModalFunction={() => {setToggleLoginModal('hide-modal');}}
        ShowRecoveryModalFunction={() => {setToggleRecoveryModal('show-modal');}}
        ShowRegisterModalFunction={() => {setToggleRegisterModal('show-modal');}}
        FirstnameFunction={props.FirstnameFunction}
        SurnameFunction={props.SurnameFunction}
        EmailFunction={props.EmailFunction}
        EmailLoginRegisterFunction={props.EmailLoginRegisterFunction}
        ResetEmailLoginRegisterFunction={props.ResetEmailLoginRegisterFunction}
        EmailReadOnlyFunction={props.EmailReadOnlyFunction}
        TitleFunction={props.TitleFunction}
        PhoneNumberFunction={props.PhoneNumberFunction}
        setModalRecoveryRequestOrigin={(x) => {setModalRecoveryRequestOrigin(x);}}
      />
      {/* End Modal Login */}

      {/* Modal Recovery */}
      <ModalResetPassword
        ip={ip}
        emailLoginRegister={props.emailLoginRegister}
        modalRecoveryRequestOrigin={modalRecoveryRequestOrigin}
        setModalRecoveryRequestOrigin={(x) => {setModalRecoveryRequestOrigin(x);}}
        modalRecoveryErrorMessage={modalRecoveryErrorMessage}
        setModalRecoveryErrorMessage={(msg) => {setModalRecoveryErrorMessage(msg);}}
        toggleRecoveryModal={toggleRecoveryModal}
        setToggleRecoveryModal={(x) => {setToggleRecoveryModal(x);}}
        setUserLoggedIn={(x) => {props.UserLoggedInFunction(x);}}
        setToken={(x) => {setToken(x);}}
        HideModalFunction={() => {setToggleRecoveryModal('hide-modal');}}
        FirstnameFunction={props.FirstnameFunction}
        SurnameFunction={props.SurnameFunction}
        EmailFunction={props.EmailFunction}
        EmailLoginRegisterFunction={props.EmailLoginRegisterFunction}
        ResetEmailLoginRegisterFunction={props.ResetEmailLoginRegisterFunction}
        EmailReadOnlyFunction={props.EmailReadOnlyFunction}
        TitleFunction={props.TitleFunction}
        PhoneNumberFunction={props.PhoneNumberFunction}
        ShowLoginModalFunction={() => {setToggleLoginModal('show-modal');}}
        ShowProfileModalFunction={() => {setToggleProfileModal('show-modal');}}
      />
      {/* End Modal Recovery */}

      {/* Modal Logout */}
      <ModalLogout
        ip={ip}
        modalLogoutErrorMessage={modalLogoutErrorMessage}
        setModalLogoutErrorMessage={(msg) => {setModalLogoutErrorMessage(msg);}}
        toggleLogoutModal={toggleLogoutModal}
        setToggleLogoutModal={(x) => {setToggleLogoutModal(x);}}
        setUserLoggedIn={(x) => {props.UserLoggedInFunction(x);}}
        setToken={(x) => {setToken(x);}}
        HideModalFunction={() => {setToggleLogoutModal('hide-modal');}}
        FirstnameFunction={props.FirstnameFunction}
        SurnameFunction={props.SurnameFunction}
        EmailFunction={props.EmailFunction}
        EmailReadOnlyFunction={props.EmailReadOnlyFunction}
        TitleFunction={props.TitleFunction}
        PhoneNumberFunction={props.PhoneNumberFunction}
      />
      {/* End Modal Logout */}

      {/* Modal Profile */}
      <ModalProfile
        ip={ip}
        token={token}
        title={props.title}
        firstname={props.firstname}
        surname={props.surname}
        email={props.email}
        phoneNumber={props.phoneNumber}
        emailReadOnly={props.emailReadOnly}
        modalProfileErrorMessage={modalProfileErrorMessage}
        setModalProfileErrorMessage={(msg) => {setModalProfileErrorMessage(msg);}}
        toggleProfileModal={toggleProfileModal}
        setToggleProfileModal={(x) => {setToggleProfileModal(x);}}
        setUserLoggedIn={(x) => {props.UserLoggedInFunction(x);}}
        setToken={(x) => {setToken(x);}}
        HideModalFunction={() => {setToggleProfileModal('hide-modal');}}
        ShowRecoveryModalFunction={() => {setToggleRecoveryModal('show-modal');}}
        FirstnameFunction={props.FirstnameFunction}
        SurnameFunction={props.SurnameFunction}
        EmailFunction={props.EmailFunction}
        EmailLoginRegisterFunction={props.EmailLoginRegisterFunction}
        ResetEmailLoginRegisterFunction={props.ResetEmailLoginRegisterFunction}
        EmailReadOnlyFunction={props.EmailReadOnlyFunction}
        TitleFunction={props.TitleFunction}
        PhoneNumberFunction={props.PhoneNumberFunction}
        setModalRecoveryRequestOrigin={(x) => {setModalRecoveryRequestOrigin(x);}}
      />
      {/* End Modal Profile */}

      {/* Modal Dashboard */}
      <ModalDashboard
        ip={ip}
        email={props.email}
        modalDashboardErrorMessage={modalDashboardErrorMessage}
        setModalDashboardErrorMessage={(msg) => {setModalDashboardErrorMessage(msg);}}
        toggleDashboardModal={toggleDashboardModal}
        setToggleDashboardModal={(x) => {setToggleDashboardModal(x);}}
        modalDashboardData={modalDashboardData}
        setModalDashboardData={(x) => {setModalDashboardData(x);}}
        HideModalFunction={() => {setToggleDashboardModal('hide-modal');}}
      />
      {/* End Modal Dashboard */}
    </div>
  );
}

export default Nav;
