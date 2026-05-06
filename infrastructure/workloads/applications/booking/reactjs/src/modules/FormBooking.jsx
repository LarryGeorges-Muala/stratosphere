import React, { useState, useRef } from 'react'
import { useReactToPrint } from 'react-to-print'
import Button from './components/Button'
import Calendar from './components/Calendar'
import Modal from './components/Modal'
import TextArea from './components/TextArea'
import ListCountries from './components/ListCountries'
import InputText from './components/InputText'
import InputEmail from './components/InputEmail'
import InputPhone from './components/InputPhone'
import InputNumber from './components/InputNumber'
import InputRadioGroup from './components/InputRadioGroup'
import InputRadio from './components/InputRadio'
import InputSubmit from './components/InputSubmit'
import InputTime from './components/InputTime'
import LoggerError from './components/LoggerError'
import LoggerInfo from './components/LoggerInfo'
import { subDays, addDays } from 'date-fns'

function FormBooking (props) {

  /* Printing component */
  const componentRef = useRef();
  /* Booking message */
  const [bookingMessage, setBookingMessage] = useState('');
  /* Modal toggle - Options: show-modal, hide-modal */
  const [toggleModal, setToggleModal] = useState('hide-modal');
  /* Booking dates */
  const [bookingDatesCheckin, setBookingDatesCheckin] = useState(GenerateMinDate());
  const [bookingDatesCheckout, setBookingDatesCheckout] = useState(GenerateMinDateFromToday());
  const [bookingDatesCheckoutMin, setBookingDatesCheckoutMin] = useState(GenerateMinDateFromToday());
  const [bookingDatesCheckoutMax, setBookingDatesCheckoutMax] = useState(GenerateMaxDateFromToday());
  const [bookingDatesCheckinAdjusted, setBookingDatesCheckinAdjusted] = useState('');
  const [bookingDatesCheckoutAdjusted, setBookingDatesCheckoutAdjusted] = useState('');
  /* Booking references */
  let checkinValueWorkaround = bookingDatesCheckin;
  let checkoutValueWorkaround = bookingDatesCheckout;
  const [bookingGuests, setBookingGuests] = useState(1);
  const [bookingDuration, setBookingDuration] = useState(1);
  const [bookingBreakfastOption, setBookingBreakfastOption] = useState(true);
  /* Booking form */
  const formRef = useRef(null);
  const submitFormRef = useRef(null);
  /* Booking state */
  const [bookingStateElement, setBookingStateElement] = useState('');

  /* Booking state functions */
  function ManualFormSubmission() {
    submitFormRef.current?.click();
  }
  function ManualFormReset() {
    formRef.current?.reset();
  }
  function HandleCloseModal() {
    setToggleModal('hide-modal');
  }
  function HandleValidation() {
    ManualFormReset();
    HandleCloseModal();
  }
  function HandleAdjustment() {
    setBookingDatesCheckin(bookingDatesCheckinAdjusted);
    setBookingDatesCheckout(bookingDatesCheckoutAdjusted);
    HandleCloseModal();
    ManualFormSubmission();
  }

  /* Booking state elements */
  function GenerateBookingState() {
    const HandlePrinting = useReactToPrint({
      contentRef: componentRef,
      documentTitle: "Booking-Confirmation",
    });
    return (
      <div>
        <TextArea ref={componentRef} name="modal-component-textarea" className="modal-component-textarea" defaultValue={ bookingMessage } readOnly={true} />
        { bookingStateElement === 'valid' &&
        <div>
          <Button
            type='button'
            text='Modify Booking'
            className='modal-component-button modal-component-red'
            divClassName='modal-component-inline'
            onClick={() => {HandleCloseModal();}}
          />
          <Button
            type='button'
            text='Make New Booking'
            className='modal-component-button modal-component-green'
            divClassName='modal-component-inline'
            onClick={() => {HandleValidation();}}
          />
          <Button
            type='button'
            text='Print Booking'
            className='modal-component-button modal-component-orange'
            divClassName='modal-component-inline'
            onClick={HandlePrinting}
          />
        </div>
        }
        { bookingStateElement === 'adjusted' &&
        <div>
          <Button
            type='button'
            text='Modify Booking'
            className='modal-component-button modal-component-red'
            onClick={HandleCloseModal}
          />
          <Button
            type='button'
            text='Accept'
            className='modal-component-button modal-component-green'
            onClick={HandleAdjustment}
          />
        </div>
        }
      </div>
    );
  }

  /* Check-in calendar min date */
  function GenerateMinDate() {
    try {
      return subDays(new Date(), 0);
    } catch (err) {
      LoggerError(err);
    }
    return '';
  }
  
  /* Check-out calendar min date */
  function GenerateMinDateFromToday() {
    try {
      return addDays(new Date(), 1);
    } catch (err) {
      LoggerError(err);
    }
    return '';
  }
  function GenerateMaxDateFromToday() {
    try {
      return addDays(new Date(), 360);
    } catch (err) {
      LoggerError(err);
    }
    return '';
  }

  /* Verify blocked entries */
  function CheckBlockedDates(date) {
    const greaterDate = props.blockedCalendarEntries.findIndex(element => element.getTime() > date.getTime());
    if (greaterDate !== -1) {
      return props.blockedCalendarEntries.slice(greaterDate)[0];
    }
    return null;
  }

  /* Check-in/check-out calendars change handle */
  function HandleDateChanges(date){
    try {
      setBookingDatesCheckin(date);
      const tmp = addDays(date, 1);
      if (date >= new Date(bookingDatesCheckoutMin)) {
        setBookingDatesCheckout(tmp);
        checkoutValueWorkaround = tmp;
      } else {
        checkoutValueWorkaround = bookingDatesCheckout;
      }
      setBookingDatesCheckoutMin(tmp);
      const maxCheckoutDate = CheckBlockedDates(date);
      if (maxCheckoutDate) {
        setBookingDatesCheckoutMax(maxCheckoutDate);
      } else {
        setBookingDatesCheckoutMax(
          GenerateMaxDateFromToday()
        );
      }
    } catch (err) {
      LoggerError(err);
    }
  }

  /* Check-in/check-out calendars difference in days */
  function GenerateStayDuration() {
    const diffInTime = checkoutValueWorkaround.getTime() - checkinValueWorkaround.getTime();
    const diffInDays = Math.round(diffInTime / (1000 * 3600 * 24));
    setBookingDuration(diffInDays);
    return diffInDays;
  }

  function GenerateCost() {
    if (props.selectedUnitBreakfastOption && bookingBreakfastOption) {
      return (Number(bookingDuration) * Number(bookingGuests) * (parseFloat(props.selectedUnitPrice) + parseFloat(props.selectedUnitBreakfastPrice)));
    }
    return (Number(bookingDuration) * Number(bookingGuests) * parseFloat(props.selectedUnitPrice));
  }

  /* Error Msg */
  function DisplayErrorModal() {
    setBookingMessage(`
    Oops! Something went wrong and your booking couldn't be processed... We apologize for the technicality and please try again later.
    `);
    setToggleModal('show-modal');
  }

  /* Form submit handle */
  const HandleFormSubmission = async (event) => {
    try {

      event.preventDefault();
      const form = formRef.current;
      if (form.reportValidity()) {
        const formData = new FormData(form);
        const data = Object.fromEntries(
          formData.entries()
        );
        data.check_in = bookingDatesCheckin;
        data.check_out = bookingDatesCheckout;
        data.unit_id = props.selectedUnitId;
        try {
          const response = await fetch(`${import.meta.env.VITE_BACKEND}/booking/`, {
            method: "POST",
            headers: {
              'Content-Type': 'application/json',
              'X-CSRFToken': props.csrfToken,
            },
            body: JSON.stringify(data),
            credentials: 'include',
          });
          const result = await response.json();
          // LoggerInfo(typeof result);
          // LoggerInfo(`Success: ${result}`);

          // Check-in Auto Adjust
          const autoAdjust = result.bookingState;
          const autoAdjustState = autoAdjust.stateChanged;
          const autoAdjustSummary = autoAdjust.stateChangedSummary;

          if (autoAdjustState) {
            setBookingMessage(autoAdjustSummary);
            setBookingDatesCheckinAdjusted(result.check_in_form);
            setBookingDatesCheckoutAdjusted(result.check_out_form);
            setBookingStateElement('adjusted');
          } else {
            setBookingMessage(result.summary);
            setBookingStateElement('valid');
          }
        } catch (error) {
          DisplayErrorModal();
          LoggerError(error);
        }
        // Result Modal
        setToggleModal('show-modal');
      }

    } catch (err) {
      DisplayErrorModal();
      LoggerError(err);
    }
  };

  /* Component */
  return (
    <div className='group-container'>
      <div className='form-group-container'>
        {/* Modal */}
        <Modal
          id='booking-modal'
          header='Notice'
          modalErrorMessage=''
          toggleModal={toggleModal}
          HideModalFunction={() => {setToggleModal('hide-modal');}}
        >
          { GenerateBookingState() }
        </Modal>
        <hr className='unit-greeting-banner' />
        <h2>{props.selectedUnitName}</h2>
        <p>{props.selectedUnitType}</p>
        <hr className='unit-greeting-banner' />
        <br />
        {/* Form */}
        <form id="booking" ref={formRef} onSubmit={HandleFormSubmission}>
          {/* Calendar Check-In */}
          <Calendar
            name='check_in'
            labelText='Check-in date:'
            divClassName='form-container'
            labelClassName='label'
            formEntry='booking'
            entry={bookingDatesCheckin}
            minEntry={GenerateMinDate()}
            entryOnChange={
              (date) => {
                checkinValueWorkaround = date;
                HandleDateChanges(date);
                GenerateStayDuration();
              }
            }
            entriesExcluded={props.blockedCalendarEntries}
          />
          {/* Calendar Check-Out */}
          <Calendar
            name='check_out'
            labelText='Check-out date:'
            divClassName='form-container'
            labelClassName='label'
            formEntry='booking'
            entry={bookingDatesCheckout}
            minEntry={bookingDatesCheckoutMin}
            maxEntry={bookingDatesCheckoutMax}
            entryOnChange={
              (date) => {
                checkoutValueWorkaround = date;
                setBookingDatesCheckout(date);
                GenerateStayDuration();
              }
            }
          />
          {/* Check-In Time */}
          <InputTime
            name='check_in_time'
            labelText='Check-in time:'
            inputDefaultValue='09:00'
            divClassName='form-container'
            labelClassName='label'
            required={true}
          />
          {/* Check-Out Time */}
          <InputTime
            name='check_out_time'
            labelText='Check-out time:'
            inputDefaultValue='11:00'
            divClassName='form-container'
            labelClassName='label'
            required={true}
          />
          {/* Title */}
          <InputText
            name='title'
            labelText='Title:'
            inputDefaultValue={props.title}
            divClassName='form-container'
            labelClassName='label'
            autoComplete='on'
            required={true}
            inputOnChange={ (event) => { !props.userLoggedIn && props.TitleFunction(event); } }
          />
          {/* Firstname */}
          <InputText
            name='firstname'
            labelText='First name:'
            inputDefaultValue={props.firstname}
            divClassName='form-container'
            labelClassName='label'
            autoComplete='on'
            required={true}
            inputOnChange={ (event) => { !props.userLoggedIn && props.FirstnameFunction(event); } }
          />
          {/* Surname */}
          <InputText
            name='surname'
            labelText='Last name:'
            inputDefaultValue={props.surname}
            divClassName='form-container'
            labelClassName='label'
            autoComplete='on'
            required={true}
            inputOnChange={ (event) => { !props.userLoggedIn && props.SurnameFunction(event); } }
          />
          {/* Email */}
          <InputEmail
            name='email'
            labelText='Email:'
            inputDefaultValue={props.email}
            divClassName='form-container'
            inputClassName='form-container-element-read-only'
            labelClassName='label'
            autoComplete='on'
            required={true}
            readOnly={props.emailReadOnly}
            inputOnChange={ props.EmailFunction }
          />
          {/* Phone */}
          <InputPhone
            name='phone'
            labelText='Phone number:'
            inputDefaultValue={props.phoneNumber}
            divClassName='form-container'
            labelClassName='label'
            autoComplete='on'
            required={true}
            inputOnChange={ (event) => { !props.userLoggedIn && props.PhoneNumberFunction(event); } }
          />
          {/* Countries */}
          <ListCountries
            divClassName='form-container'
          />
          {/* Guests */}
          <InputNumber
            name='guests_number'
            labelText='Guests number:'
            inputDefaultValue='1'
            min='1'
            divClassName='form-container'
            labelClassName='label'
            autoComplete='off'
            required={true}
            inputOnChange={
              (event) => setBookingGuests(event.target.value)
            }
          />
          {/* Breakfast */}
          { props.selectedUnitBreakfastOption &&
          <InputRadioGroup
            description='Breakfast:'
            groupDivClassName='form-container-radio-group'
            divClassName='form-container'
          >
            <InputRadio
              name='breakfast'
              inputId='breakfastYes'
              labelText='Yes'
              value={true}
              className='form-container-radio'
              labelClassName='label'
              inputClassName='form-container-radio'
              defaultChecked={true}
              inputOnChange={
                () => setBookingBreakfastOption(true)
              }
            />
            <InputRadio
              name='breakfast'
              inputId='breakfastNo'
              labelText='No'
              value={false}
              className='form-container-radio'
              labelClassName='label'
              inputClassName='form-container-radio'
              inputOnChange={
                () => setBookingBreakfastOption(false)
              }
            />
          </InputRadioGroup>
          }
          <span className='modal-component-textarea-price-currency'>USD</span>
          <TextArea
            name="modal-component-textarea-price"
            className="modal-component-textarea modal-component-textarea-price"
            defaultValue={
              GenerateCost()
            }
            readOnly={true}
          />
          <span className='modal-component-textarea-price-duration'>For {bookingDuration} night(s)</span>
          {/* Submit */}
          <InputSubmit
            ref={submitFormRef}
            name='submit-button'
            inputValue='Submit'
            divClassName='form-container'
          />
          <br />
        </form>
      </div>
    </div>
  );
}

export default FormBooking;
