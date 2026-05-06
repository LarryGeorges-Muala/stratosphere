import DatePicker from "react-datepicker";
import "react-datepicker/dist/react-datepicker.css";
// CSS Modules, react-datepicker-cssmodules.css
// import 'react-datepicker/dist/react-datepicker-cssmodules.css';

function Calendar({
    entry,
    formEntry,
    minEntry,
    maxEntry,
    entryOnChange,
    entriesExcluded,
    divClassName,
    labelClassName,
    name,
    labelText,
    ref
  }) {
  return (
    <div className={ divClassName }>
      <label className={ labelClassName } htmlFor={ name }>{ labelText }</label><br />
      <DatePicker
        id={name}
        showIcon
        toggleCalendarOnIconClick
        form={formEntry}
        selected={entry}
        minDate={minEntry}
        maxDate={maxEntry}
        excludeDates={entriesExcluded}
        onChange={entryOnChange}
        ref={ref}
      />
    </div>
  );
}

export default Calendar;
