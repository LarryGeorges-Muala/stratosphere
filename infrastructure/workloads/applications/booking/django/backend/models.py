import datetime
from django.db import models
from django.contrib.auth.models import User, AbstractUser
from django.utils import timezone
from django.core.validators import MinValueValidator, MaxValueValidator

# Create your models here.
# class Client(AbstractUser):
#     identifier = models.CharField(max_length=200, unique=True)
#     # email = models.EmailField(max_length=254)
#     title = models.CharField(max_length=200, blank=True)
#     phone = models.CharField(max_length=200, blank=True)
#     registration_date = models.DateTimeField("created published")

#     USERNAME_FIELD = "identifier"
#     # EMAIL_FIELD = "email"

#     def __str__(self):
#         return f"{self.id} - {self.identifier}"

#     def was_published_recently(self):
#         return self.created_date >= timezone.now() - datetime.timedelta(days=1)


class Client(models.Model):

    user = models.OneToOneField(User, on_delete=models.CASCADE)

    title = models.CharField(max_length=200, blank=True)
    first_name = models.CharField(max_length=200, blank=True)
    last_name = models.CharField(max_length=200, blank=True)
    email = models.EmailField(max_length=254, default='')
    phone = models.CharField(max_length=200, blank=True)
    registration_date = models.DateTimeField("created published", default=timezone.now)

    def __str__(self):
        return f"{self.id} - {self.user.username}"

    def was_published_recently(self):
        return self.registration_date >= timezone.now() - datetime.timedelta(days=1)


class Unit(models.Model):

    # Limit choices
    UNIT_TYPE_CHOICES = [
        ('Apartment', 'Apartment'),
        ('Penthouse', 'Penthouse'),
        ('Villa', 'Villa'),
    ]

    # Re-usable unit size
    def number_of_rooms_in_unit():
        minimum_number_of_rooms = 1
        return int(minimum_number_of_rooms)

    # Fields
    name = models.CharField(max_length=200)
    type = models.CharField(
        max_length=200,
        choices=UNIT_TYPE_CHOICES,
        default='A',
    )
    number_of_rooms = models.IntegerField(
        validators=[
            MinValueValidator(1)
        ],
        default=number_of_rooms_in_unit
    )
    number_of_bathrooms = models.IntegerField(
        validators=[
            MinValueValidator(1)
        ],
        default=1
    )
    price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0
    )
    occupancy = models.IntegerField(
        validators=[
            MinValueValidator(1)
        ],
        default=1
    )
    breakfast = models.BooleanField(default=True)
    breakfast_price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0
    )
    active = models.BooleanField(default=True)
    created_date = models.DateTimeField("created published", default=timezone.now)

    def __str__(self):
        return f"{self.id} - {self.name}"

    def was_published_recently(self):
        return self.created_date >= timezone.now() - datetime.timedelta(days=1)


class Booking(models.Model):

    def default_check_out():
        return datetime.date.today() + datetime.timedelta(days=1)

    def default_time():
        return datetime.datetime.now().time()

    unit = models.ForeignKey(Unit, on_delete=models.CASCADE)
    check_in = models.DateField(default=datetime.date.today)
    check_in_time = models.TimeField(default=default_time)
    check_out = models.DateField(default=default_check_out)
    check_out_time = models.TimeField(default=default_time)
    guest_email = models.EmailField(max_length=254, default='')
    guest_origin = models.CharField(max_length=200, default='')
    guests_number = models.IntegerField(
        validators=[
            MinValueValidator(1)
        ],
        default=1
    )
    breakfast = models.BooleanField(default=True)
    total = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0
    )

    def __str__(self):
        return f"{self.check_in} -> {self.check_out}"

    def duration_calculator(self):
        return int((self.check_out - self.check_in).days)

    def generate_calendar(self):
        duration = self.duration_calculator()
        calendar = []
        for i in range(duration + 1):
            calendar.append(
                self.check_in + datetime.timedelta(days=i)
            )
        return calendar


    # On Save, cache to Redis

