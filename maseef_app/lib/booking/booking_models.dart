enum BookingMode { fullDay, morning, evening }

enum DayState { available, pending, booked, unavailable, closed, partial }

enum ModeAvailability { available, pending, booked }

class ModeOffer {
  const ModeOffer({
    required this.mode,
    required this.status,
    required this.start,
    required this.end,
    this.price,
  });

  final BookingMode mode;
  final ModeAvailability status;
  final String start;
  final String end;
  final double? price;
}

class CalendarDay {
  const CalendarDay({
    required this.date,
    required this.state,
    required this.modes,
  });

  final DateTime date;
  final DayState state;
  final Map<BookingMode, ModeOffer> modes;

  String get isoDate {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class AvailabilitySnapshot {
  const AvailabilitySnapshot({
    required this.configured,
    required this.listingKey,
    this.reason,
    this.year,
    this.month,
    this.days = const [],
  });

  final bool configured;
  final String listingKey;
  final String? reason;
  final int? year;
  final int? month;
  final List<CalendarDay> days;

  CalendarDay? dayOn(DateTime date) {
    for (final day in days) {
      if (day.date.year == date.year &&
          day.date.month == date.month &&
          day.date.day == date.day) {
        return day;
      }
    }
    return null;
  }

  bool get hasOpenDate => days.any(
    (day) =>
        day.state == DayState.available ||
        day.state == DayState.partial ||
        day.state == DayState.pending ||
        day.state == DayState.booked,
  );
}

class CustomerBookingRequest {
  const CustomerBookingRequest({
    required this.reference,
    required this.listingKey,
    required this.stayDate,
    required this.mode,
    required this.status,
    this.price,
  });

  final String reference;
  final String listingKey;
  final String stayDate;
  final BookingMode mode;
  final String status;
  final double? price;

  bool get isConfirmed => status == 'confirmed';
}

class BookingDraft {
  const BookingDraft({
    required this.listingKey,
    required this.stayDate,
    required this.mode,
  });

  final String listingKey;
  final String stayDate;
  final BookingMode mode;
}

DateTime calendarDate(int year, int month, int day) =>
    DateTime(year, month, day);

BookingMode? bookingModeFromJson(String value) {
  switch (value) {
    case 'full_day':
      return BookingMode.fullDay;
    case 'morning':
      return BookingMode.morning;
    case 'evening':
      return BookingMode.evening;
    default:
      return null;
  }
}

String bookingModeToJson(BookingMode mode) {
  switch (mode) {
    case BookingMode.fullDay:
      return 'full_day';
    case BookingMode.morning:
      return 'morning';
    case BookingMode.evening:
      return 'evening';
  }
}
