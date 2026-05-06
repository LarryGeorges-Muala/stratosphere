import Button from './components/Button'

function Units (props) {

  function PrepCalendar(calendar) {
    let preppedCalendar = [];
    calendar.forEach(
      entry => {
        preppedCalendar.push(new Date(entry));
      }
    );
    return preppedCalendar;
  }

  return (
    <div className='section-group-container'>
      {props.units.map((item) => (
        <div key={item.id} className='unit-responsive'>
          <div className='unit-gallery'>
            <img className='unit-image' src='https://images.unsplash.com/photo-1618773928121-c32242e63f39?q=80&w=2940&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D' alt={item.name} />
            <div className='unit-description'>
              <span className='unit-description-name'>
                {item.name}
              </span>
              <span className='unit-description-type'>
                {item.type}
              </span>
              <span className='unit-description-rooms'>
                {item.number_of_rooms} <i className='fa fa-bed'></i> 
              </span>
              <span className='unit-description-bathrooms'>
                {item.number_of_bathrooms} <i className='fa fa-bath'></i> 
              </span>
              <span className='unit-description-occupancy'>
                {item.occupancy} <i className='fa fa-group'></i> 
              </span>
              <span className='unit-description-price'>
                <i className='fa fa-dollar'></i> {item.price} <i className='fa fa-moon-o'></i>
              </span>
              <span className='unit-description-price-breakfast'>
                <i className='fa fa-dollar'></i> {item.breakfast_price} <i className='fa fa-coffee'></i>
              </span>
            </div>
            <Button
              type='button'
              text='Book'
              className='modal-component-button'
              divClassName='modal-component-inline'
              onClick={
                () => {
                  props.setSelectedUnitId(item.id);
                  props.setSelectedUnitName(item.name);
                  props.setSelectedUnitType(item.type);
                  props.setSelectedUnitPrice(item.price);
                  props.setSelectedUnitBreakfastOption(item.breakfast);
                  props.setSelectedUnitBreakfastPrice(item.breakfast_price);
                  props.setBlockedCalendarEntries(
                    PrepCalendar(item.calendar)
                  );
                }
              }
            />
          </div>
        </div>
      ))}
    </div>
  );
}

export default Units;
