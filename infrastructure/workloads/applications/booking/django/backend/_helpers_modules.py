from datetime import date, datetime

import traceback, json, re, pycountry, redis, pika

from . import models


'''
Sample Blocked Calendar Entries
'''
blocked_calendar_entries_list = [
    date(2026, 4, 25),
    date(2026, 4, 26),
    date(2026, 4, 27),
    date(2026, 5, 1),
    date(2026, 5, 2),
    date(2026, 1, 1),
]
blocked_calendar_entries_list.sort()


'''
Loggers
'''
def logger_error(msg):
    try:
        print('\n............................')
        print(msg)
        print(traceback.format_exc())
        print('............................\n')
        return True
    except Exception as e:
        print(e)
    return False


def logger_info(msg):
    print('\n............................')
    print(msg)
    print('............................\n')
    return True


'''
Visual Aid
'''
def improve_log_readability():
    print('\n............................')
    return True


'''
Health Endpoint
'''
def health():
    return {
        'status': 'up',
        'current_time': datetime.now()
    }


'''
Redis Session - Create
'''
def create_redis_session(package_name, payload):
    try:
        r = redis.Redis(
            host='localhost',
            port=6379,
            decode_responses=True
        )
        try:
            # Save session
            r.hset(package_name, mapping=payload)
            # Check session
            user_session = r.hgetall(package_name)
            # Session expiration
            r.expire(
                package_name,
                (3600 * 24)
            )
            logger_info(
                f'''
                Redis session '{package_name}'
                {type(user_session)}
                {user_session}
                '''
            )
            r.close()
            return True
        except Exception as e:
            logger_error(e)
            r.close()
    except Exception as e:
        logger_error(e)
    return False


'''
Redis Session - Fetch
'''
def fetch_redis_session(package_name):
    user_session = {}
    try:
        r = redis.Redis(
            host='localhost',
            port=6379,
            decode_responses=True
        )
        try:
            # Check session
            user_session = r.hgetall(package_name)
            logger_info(
                f'''
                Redis session '{package_name}'
                {type(user_session)}
                {user_session}
                '''
            )
            r.close()
        except Exception as e:
            logger_error(e)
            r.close()
    except Exception as e:
        logger_error(e)
    return user_session


'''
Redis Session - Clear
'''
def clear_redis_session(package_name):
    try:
        r = redis.Redis(
            host='localhost',
            port=6379,
            decode_responses=True
        )
        try:
            # Check session
            r.delete(package_name)
            logger_info(
                f'''
                Redis session deleted '{package_name}'
                '''
            )
            r.close()
            return True
        except Exception as e:
            logger_error(e)
            r.close()
    except Exception as e:
        logger_error(e)
    return False


'''
Rabbit - Record
'''
def add_to_rabbit_queue(payload, payload_type=''):
    rabbit_queue = 'booking'
    try:
        connection = pika.BlockingConnection(pika.ConnectionParameters('localhost'))
        channel = connection.channel()
        channel.queue_declare(
            queue=rabbit_queue,
            durable=True,
            arguments={'x-queue-type': 'quorum'}
        )
        try:
            if payload_type == 'json':
                channel.basic_publish(
                    exchange='',
                    routing_key=rabbit_queue,
                    body=json.dumps(payload),
                    properties=pika.BasicProperties(content_type='application/json')
                )
            else:
                channel.basic_publish(
                    exchange='',
                    routing_key=rabbit_queue,
                    body=payload
                )
            logger_info(f" [x] Sent '{payload}'")
            connection.close()
            return True
        except Exception as e:
            logger_error(e)
            connection.close()
    except Exception as e:
        logger_error(e)
    return False


'''
Units
'''
def load_units_from_database(payload):
    try:
        if not isinstance(payload, dict):
            payload = json.loads(payload)
        units_list = []
        units = models.Unit.objects.filter(active=True)
        for unit in units:
            # Load calendar per unit
            calendar = []
            booking_entries = unit.booking_set.all()
            for entry in booking_entries:
                calendar = calendar + entry.generate_calendar()

            # Load details per unit
            units_list.append({
                'id': unit.id,
                'name': unit.name,
                'type': unit.type,
                'number_of_rooms': unit.number_of_rooms,
                'number_of_bathrooms': unit.number_of_bathrooms,
                'price': unit.price,
                'occupancy': unit.occupancy,
                'breakfast': unit.breakfast,
                'breakfast_price': unit.breakfast_price,
                'calendar': calendar,
            })
        payload['units'] = units_list

    except Exception as e:
        logger_error(e)
    return payload


'''
Test Each Booking Field
'''
def test_booking_fields(booking_data, booking_field):
    try:
        logger_info(f"Checking field '{booking_field}'...")
        if booking_field in booking_data:
            logger_info(f"'{booking_field}' valid..")
            return True
        else:
            logger_info(f"'{booking_field}' missing..")
    except Exception as e:
        logger_error(e)
    return False


'''
Validate Email
'''
def is_email_valid(email):
    try:
        regex = r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$'
        if re.fullmatch(regex, email):
            return True
    except Exception as e:
        logger_error(e)
    return False


'''
Validate Origin Country
'''
def is_country_valid(country):
    try:
        check = pycountry.countries.get(alpha_2=country)
        if check:
            logger_info(f"'{country}' valid..")
            return True
        else:
            logger_info(f"'{country}' invalid..")
    except Exception as e:
        logger_error(e)
    return False


'''
Main Guest Important Fields Validation
'''
def main_guest_validator(booking_data, booking_field):
    try:
        match booking_field:
            case 'email':
                is_email_valid(booking_data['email'])
            case 'phone':
                logger_info('No validation required - Phone number optional...')
            case 'countriesfield':
                is_country_valid(booking_data['countriesfield'])
            case _:
                logger_info('No validation required...')
        return True
    except Exception as e:
        logger_error(e)
    return False


'''
Confirm Booking Main Guest
'''
def confirm_booking_main_guest(booking_data, booking_field):
    try:
        logger_info(f'''Checking field '{booking_field}'...''')

        # Filtering main guest
        if 'main_guest' in str(booking_field).lower():
            if 'main_guest' in booking_data:
                logger_info(f'''{booking_field} - Main guest loaded...''')
                main_guest_dict = json.loads(booking_field)
                main_guest = main_guest_dict['main_guest']
                for key, value in main_guest.items():
                    test_booking_fields(main_guest, key)
                    main_guest_validator(main_guest, key)
                return True
            else:
                logger_error(f'''{booking_field} - Main guest missing...''')
        else:
            logger_error(f'''Main guest details missing from field \n '{booking_field}'... ''')
    except Exception as e:
        logger_error(e)
    return False


'''
Valdate Booking Fields
'''
def validate_booking_fields(booking_data):
    try:
        # Hardcoded fields to validate - Main Guest
        booking_main_guest = [
            '{"main_guest": ["title", "firstname", "surname", "email", "phone", "countriesfield"]}'
        ]
        # Hardcoded fields to validate - Booking Details
        booking_fields = [
            'guests_number',
            'breakfast',
            'check_in',
            'check_out',
            'check_in_time',
            'check_out_time',
        ]

        # Validation Main Guest
        confirm_booking_main_guest(booking_data, booking_main_guest[0])
        improve_log_readability()

        # Validation Details Loop
        for field in booking_fields:
            test_booking_fields(booking_data, field)
        return True
    except Exception as e:
        logger_error(e)
    return False


'''
Generate Earliest Validation Date
'''
def earliest_date():
    now = datetime.now()
    today = datetime(now.year, now.month, now.day)
    return today


'''
Validate Date Format
'''
def validate_booking_dates_format(date_entry, date_entry_name):
    try:
        if '-' in str(date_entry).lower(): 
            if ' ' not in str(date_entry).lower():
                logger_info(f''''{date_entry_name}' - '{date_entry}' valid... ''')
                return True
            else:
                logger_error(f'''Invalid date format from '{date_entry_name}' - '{date_entry}' - Please use format 'YYYY-MM-DD'...''')
        else:
            logger_error(f'''Invalid date format from '{date_entry_name}' - '{date_entry}' - Please use format 'YYYY-MM-DD'...''')
    except Exception as e:
        logger_error(e)
    return False


'''
Read Booking Dates
'''
def read_booking_dates(date_entry, date_entry_name):
    try:
        if (date_entry):
            if validate_booking_dates_format(date_entry, date_entry_name):
                date_obj = datetime.strptime(
                    (date_entry.split('T'))[0],
                    "%Y-%m-%d"
                )
                today = earliest_date()
                if today <= date_obj:
                    return date_obj
                else:
                    logger_error(f'''Invalid date format from '{date_entry_name}' - '{date_entry}' - Please set a recent date...''')
            else:
                logger_error(f'''Invalid date format from '{date_entry_name}' - '{date_entry}'...''')
        else:
            logger_error(f'''Invalid date format from '{date_entry_name}' - '{date_entry}'...''')
    except Exception as e:
        logger_error(e)
    return None


'''
Calculate Booking Duration
'''
def calculate_booking_duration(checkin, checkout):
    try:
        return (datetime(checkout.year, checkout.month, checkout.day) - datetime(checkin.year, checkin.month, checkin.day)).days
    except Exception as e:
        logger_error(e)
    return 0


'''
Compare Booking Dates
'''
def compare_booking_dates(checkin, checkout):
    try:
        if checkin < checkout:
            # if int(checkin.timestamp() * 1000) < int(checkout.timestamp() * 1000):
            if mark_time(checkin) < mark_time(checkout):
                days_difference = calculate_booking_duration(checkin, checkout)
                logger_info(f''' Duration: {days_difference} night(s)''')
                return days_difference
            else:
                logger_error(f'''Invalid Check-Out Date from '{checkout}' compared to '{checkin}'...''')
        else:
            logger_error(f'''Invalid Check-Out Date from '{checkout}' compared to '{checkin}'...''')
    except Exception as e:
        logger_error(e)
    return 0


'''
Generate Booking Times
'''
def generate_booking_times(date_entry, time_entry, description):
    try:
        time_list = str(time_entry).split(':')
        genarated_date = datetime(
            date_entry.year,
            date_entry.month,
            date_entry.day,
            int(time_list[0]),
            int(time_list[1])
        )
        logger_info(f''' '{description} time': '{time_entry}' / {genarated_date}... ''')
        return genarated_date
    except Exception as e:
        logger_error(e)
    return None


'''
Room Availability
'''
def normalize_date(date_entry):
    return date_entry.strftime("%Y-%m-%d")

def check_room_availability(checkin, checkout, booking_duration):
    try:
        return [
            checkin,
            checkout,
            {
                'stateChanged': False,
                'stateChangedSummary': ''
            }
        ]
    except Exception as e:
        logger_error(e)
    return []


'''
Guests Pricing
'''
def guest_price_value():
    return 100
def breakfast_price_value():
    return 30

def generate_guests_price(booking_duration, guests_number, breakfast, unit_id):
    total = 0
    price_guest = 0
    breakfast_price = 0
    try:
        unit = models.Unit.objects.get(pk=unit_id)
        if unit:
            price_guest = unit.price
            breakfast_price = unit.breakfast_price
        breakfast_enabled = str(breakfast)
        breakfast_enabled = breakfast_enabled in ['true', 'on']
        logger_info(f''' USD {price_guest:,} per guest per night... ''')

        if breakfast_enabled:
            total = int(booking_duration) * int(guests_number) * (price_guest + breakfast_price)
            logger_info(f'''
    Including breakfast...
    USD {breakfast_price:,} per guest per breakfast...
    For {guests_number} guest(s) with breakfast and {booking_duration} night(s): USD {total:,}...
            ''')
        else:
            total = int(booking_duration) * int(guests_number) * price_guest
            logger_info(f'''
    For {guests_number} guest(s) and {booking_duration} night(s): USD {total:,}...
            ''')
    except Exception as e:
        logger_error(e)
    return total


'''
Format Content
'''
def capitalize_first_letter(text):
    try:
        if not text:
            return text
        return text[:1].upper() + text[1:]
    except Exception as e:
        logger_error(e)
    return ''

def interpret_option(handler):
    try:
        handler = (str(handler).lower() in ['true', 'on'])
        if handler:
            return capitalize_first_letter('yes')
        else:
            return capitalize_first_letter('no')
    except Exception as e:
        logger_error(e)
    return ''

def render_option_summary(handler, unit_id):
    try:
        price_guest = 0
        breakfast_price = 0
        unit = models.Unit.objects.get(pk=unit_id)
        if unit:
            price_guest = unit.price
            breakfast_price = unit.breakfast_price
        handler = (str(handler).lower() in ['true', 'on'])
        if handler:
            return f'''
    With breakfast included

    Notes:
    USD {price_guest:,} per guest per night
    USD {breakfast_price:,} per guest per breakfast

    Enjoy Your Stay!
            '''
        return f'''
    Notes:
    USD {price_guest:,} per guest per night

    Enjoy Your Stay!
    '''
    except Exception as e:
        logger_error(e)
    return ''

def mark_time(date_entry):
    try:
        return int(date_entry.timestamp() * 1000)
    except Exception as e:
        logger_error(e)
    return None


'''
Decode Content
'''
def format_request_parameters(payload, payload_type):
    try:
        logger_info(type(payload))
        if payload_type == 'json':
            payload = json.loads(payload.decode('utf-8'))
            logger_info(type(payload))
    except Exception as e:
        logger_error(e)
    return payload


'''
Handle Booking
'''
def create_booking(payload, payload_type):
    booking_finalization = {}
    try:
        payload = format_request_parameters(payload, payload_type)

        booking_id = mark_time(datetime.now())
        registration_id = datetime.now()

        improve_log_readability()
        validate_booking_fields(payload)
        improve_log_readability()

        booking_checkin = read_booking_dates(
            payload['check_in'],
            'check-in'
        )
        improve_log_readability()
        booking_checkout = read_booking_dates(
            payload['check_out'],
            'check-out'
        )

        improve_log_readability()
        booking_duration = compare_booking_dates(
            booking_checkin,
            booking_checkout
        )

        improve_log_readability()
        booking_stay_confirmation = check_room_availability(
            booking_checkin,
            booking_checkout,
            booking_duration
        )
        booking_state = booking_stay_confirmation[2]

        improve_log_readability()
        booking_checkin_time = generate_booking_times(
            booking_stay_confirmation[0],
            payload['check_in_time'],
            'check-in'
        )
        improve_log_readability()
        booking_checkout_time = generate_booking_times(
            booking_stay_confirmation[1],
            payload['check_out_time'],
            'check-out'
        )

        improve_log_readability()
        booking_price = generate_guests_price(
            booking_duration,
            payload['guests_number'],
            payload['breakfast'],
            payload['unit_id']
        )

        improve_log_readability()
        main_guest = f"{capitalize_first_letter(payload['title'])} {capitalize_first_letter(payload['firstname'])} {capitalize_first_letter(payload['surname'])}"

        booking_finalization = {
            'booking_id': str(booking_id),
            'registration_date': str(registration_id),
            'main_guest': str(main_guest),
            'title': payload['title'],
            'firstname': payload['firstname'],
            'surname': payload['surname'],
            'origin': capitalize_first_letter(payload['countriesfield']),
            'email': payload['email'],
            'phone': payload['phone'],
            'guests': payload['guests_number'],
            'breakfast': interpret_option(payload['breakfast']),
            'breakfast_text': render_option_summary(payload['breakfast'], payload['unit_id']),
            'check_in': str(booking_checkin_time),
            'check_in_timestamp': mark_time(booking_checkin_time),
            'check_in_form': normalize_date(booking_checkin_time),
            'check_out': str(booking_checkout_time),
            'check_out_timestamp': mark_time(booking_checkout_time),
            'check_out_form': normalize_date(booking_checkout_time),
            'duration': str(booking_duration),
            'duration_text': f'{booking_duration} Night(s)',
            'price': str(booking_price),
            'price_text': f'USD {booking_price:,}',
            'bookingState': booking_state,
            'summary': f'''
    Dear {main_guest},

    Booking #{booking_id} Confirmed 
    For
    {payload['guests_number']} guest(s)  
    For
    {booking_duration} night(s)
    From 
    {booking_checkin_time}
    To 
    {booking_checkout_time}
    At the value of
    USD {booking_price:,}
    {render_option_summary(payload['breakfast'], payload['unit_id'])}
        ''',
        }

        try:
            unit = models.Unit.objects.get(pk=payload['unit_id'])
            unit.booking_set.create(
                check_in = booking_checkin_time,
                check_in_time = booking_checkin_time,
                check_out = booking_checkout_time,
                check_out_time = booking_checkout_time,
                guest_email = payload['email'],
                guest_origin = capitalize_first_letter(payload['countriesfield']),
                guests_number = payload['guests_number'],
                breakfast = (payload['breakfast'] in ['true', 'on']),
                total = booking_price
            )
        except Exception as e:
            logger_error(e)

        if booking_state['stateChanged'] == False:
            redis_payload = booking_finalization.copy()
            redis_payload.pop('bookingState', None)
            redis_payload.pop('summary', None)
            # Sessions
            create_redis_session(payload['email'], redis_payload)
            # Unique Bookings
            create_redis_session(str(booking_id), redis_payload)
            # Queue
            add_to_rabbit_queue(str(booking_id))
            add_to_rabbit_queue(redis_payload, 'json')
    except Exception as e:
        logger_error(e)
    return booking_finalization


'''
Create User Session
'''
def create_user_session(payload, payload_type):
    session_status = {
        'message': 'Creating session failed',
        'code': 400
    }
    try:
        payload = format_request_parameters(payload, payload_type)
        client_ip = payload['accessClient']
        create_redis_session(
            client_ip,
            payload
        )
        session_status = {
            'message': 'Session created',
            'code': 200
        }
    except Exception as e:
        logger_error(e)
    return session_status


'''
Fetch User Session
'''
def fetch_user_session(payload, payload_type):
    user_session = {}
    try:
        payload = format_request_parameters(payload, payload_type)
        client_ip = payload['accessClient']
        user_session = fetch_redis_session(client_ip)
        user_session = load_units_from_database(user_session)
    except Exception as e:
        logger_error(e)
    return user_session


'''
Delete User Session
'''
def delete_user_session(payload, payload_type):
    session_status = {
        'message': 'Clearing session failed',
        'code': 400
    }
    try:
        payload = format_request_parameters(payload, payload_type)
        client_ip = payload['accessClient']
        session_cleared = clear_redis_session(client_ip)
        if session_cleared:
            session_status = {
                'message': 'Session cleared',
                'code': 200
            }
    except Exception as e:
        logger_error(e)
    return session_status
