import React, { useState } from 'react'
import reactLogo from './assets/react.svg'
import viteLogo from './assets/vite.svg'
import heroImg from './assets/hero.png'
import FormBooking from './modules/FormBooking'
import Nav from './modules/Nav'
import Units from './modules/Units'
import './App.css'

function App() {

  /* User Fields */
  const [firstname, setFirstname] = useState('');
  const [surname, setSurname] = useState('');
  const [title, setTitle] = useState('');
  const [email, setEmail] = useState('');
  const [emailLoginRegister, setEmailLoginRegister] = useState('');
  const [emailReadOnly, setEmailReadOnly] = useState(false);
  const [phoneNumber, setPhoneNumber] = useState('');

  /* User Logged In */
  const [userLoggedIn, setUserLoggedIn] = useState(false);

  /* CSRF */
  const [csrfToken, setCsrfToken] = useState('');

  /* Units */
  const [units, setUnits] = useState([]);
  const [selectedUnitId, setSelectedUnitId] = useState('');
  const [selectedUnitName, setSelectedUnitName] = useState('');
  const [selectedUnitType, setSelectedUnitType] = useState('');
  const [selectedUnitPrice, setSelectedUnitPrice] = useState(0);
  const [selectedUnitBreakfastOption, setSelectedUnitBreakfastOption] = useState(false);
  const [selectedUnitBreakfastPrice, setSelectedUnitBreakfastPrice] = useState(0);

  /* Blocked Calendar Entries */
  const [blockedCalendarEntries, setBlockedCalendarEntries] = useState([]);

  return (
    <>
      <section id="center">
        <div className="hero">
          <img src={heroImg} className="base" width="170" height="179" alt="" />
          <img src={reactLogo} className="framework" alt="React logo" />
          <img src={viteLogo} className="vite" alt="Vite logo" />
        </div>
        <div>
          <h1>Booking System</h1>
          <p>
            <code>ReactJS</code> → <code>Django / NestJS</code> → <code>Redis</code> → <code>RabbitMQ</code> → <code>Python / NodeJS</code> → <code>MySQL</code>
          </p>
        </div>
        {/* Nav */}
        <Nav
          title={title}
          firstname={firstname}
          surname={surname}
          email={email}
          emailLoginRegister={emailLoginRegister}
          phoneNumber={phoneNumber}
          emailReadOnly={emailReadOnly}
          FirstnameFunction={(x) => {setFirstname(x);}}
          SurnameFunction={(x) => {setSurname(x);}}
          TitleFunction={(x) => {setTitle(x);}}
          EmailFunction={(x) => {setEmail(x);}}
          EmailLoginRegisterFunction={(event) => {setEmailLoginRegister(event.target.value);}}
          ResetEmailLoginRegisterFunction={(x) => {setEmailLoginRegister(x);}}
          EmailReadOnlyFunction={(x) => {setEmailReadOnly(x);}}
          PhoneNumberFunction={(x) => {setPhoneNumber(x);}}
          userLoggedIn={userLoggedIn}
          UserLoggedInFunction={(x) => {setUserLoggedIn(x);}}
          blockedCalendarEntries={blockedCalendarEntries}
          setBlockedCalendarEntries={(x) => {setBlockedCalendarEntries(x);}}
          csrfToken={csrfToken}
          setCsrfToken={(x) => {setCsrfToken(x);}}
          units={units}
          setUnits={(x) => {setUnits(x);}}
        />
        {/* Units */}
        <Units
          units={units}
          setUnits={(x) => {setUnits(x);}}
          setSelectedUnitId={(x) => {setSelectedUnitId(x);}}
          setSelectedUnitName={(x) => {setSelectedUnitName(x);}}
          setSelectedUnitType={(x) => {setSelectedUnitType(x);}}
          setSelectedUnitPrice={(x) => {setSelectedUnitPrice(x);}}
          setSelectedUnitBreakfastOption={(x) => {setSelectedUnitBreakfastOption(x);}}
          setSelectedUnitBreakfastPrice={(x) => {setSelectedUnitBreakfastPrice(x);}}
          setBlockedCalendarEntries={(x) => {setBlockedCalendarEntries(x);}}
        />
        {/* Booking Form */}
        { selectedUnitId &&
        <FormBooking
          firstname={firstname}
          surname={surname}
          title={title}
          email={email}
          emailLoginRegister={emailLoginRegister}
          phoneNumber={phoneNumber}
          emailReadOnly={emailReadOnly}
          FirstnameFunction={(event) => {setFirstname(event.target.value);}}
          SurnameFunction={(event) => {setSurname(event.target.value);}}
          TitleFunction={(event) => {setTitle(event.target.value);}}
          EmailFunction={(event) => {setEmail(event.target.value);}}
          EmailLoginRegisterFunction={(event) => {setEmailLoginRegister(event.target.value);}}
          ResetEmailLoginRegisterFunction={(x) => {setEmailLoginRegister(x);}}
          EmailReadOnlyFunction={(x) => {setEmailReadOnly(x);}}
          PhoneNumberFunction={(event) => {setPhoneNumber(event.target.value);}}
          userLoggedIn={userLoggedIn}
          UserLoggedInFunction={(x) => {setUserLoggedIn(x);}}
          blockedCalendarEntries={blockedCalendarEntries}
          setBlockedCalendarEntries={(x) => {setBlockedCalendarEntries(x);}}
          csrfToken={csrfToken}
          setCsrfToken={(x) => {setCsrfToken(x);}}
          units={units}
          setUnits={(x) => {setUnits(x);}}
          selectedUnitId={selectedUnitId}
          selectedUnitName={selectedUnitName}
          selectedUnitType={selectedUnitType}
          selectedUnitPrice={selectedUnitPrice}
          selectedUnitBreakfastOption={selectedUnitBreakfastOption}
          selectedUnitBreakfastPrice={selectedUnitBreakfastPrice}
        />
        }
      </section>

      <div className="ticks"></div>
      <div className="ticks"></div>
      <section id="spacer"></section>
    </>
  )
}

export default App
