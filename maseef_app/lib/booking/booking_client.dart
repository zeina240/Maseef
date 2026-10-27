import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:maseef_app/auth/auth_session.dart';
import 'package:maseef_app/booking/booking_models.dart';

enum BookingBlockReason { signedOut, storageNotApproved }

class BookingAuthException implements Exception {
  const BookingAuthException({this.reason = BookingBlockReason.signedOut});

  final BookingBlockReason reason;
}

class BookingLoadException implements Exception {
  const BookingLoadException();
}

abstract class BookingClient {
  Future<AvailabilitySnapshot> loadMonth({
    required String listingKey,
    required int year,
    required int month,
  });

  Future<CustomerBookingRequest> submitRequest(BookingDraft draft);

  Future<List<CustomerBookingRequest>> loadMyRequests();
}

/// Used when a screen must not invent availability or call the network.
class NotConfiguredBookingClient implements BookingClient {
  const NotConfiguredBookingClient();

  @override
  Future<AvailabilitySnapshot> loadMonth({
    required String listingKey,
    required int year,
    required int month,
  }) async {
    return AvailabilitySnapshot(
      configured: false,
      listingKey: listingKey,
      reason: 'not_configured',
      year: year,
      month: month,
    );
  }

  @override
  Future<List<CustomerBookingRequest>> loadMyRequests() async {
    throw const BookingAuthException();
  }

  @override
  Future<CustomerBookingRequest> submitRequest(BookingDraft draft) async {
    throw const BookingAuthException();
  }
}

typedef BookingSender = Future<http.Response> Function(Uri uri);

class BookingCall {
  const BookingCall({
    required this.method,
    required this.uri,
    required this.headers,
    this.body,
  });

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final String? body;
}

typedef BookingCallSender = Future<http.Response> Function(BookingCall call);

class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'MASEEF_API_BASE',
    defaultValue: 'http://localhost:5000',
  );
}

class ApiBookingClient implements BookingClient {
  ApiBookingClient({
    this.baseUrl = ApiConfig.baseUrl,
    this.accessToken,
    this.session,
    this.writesEnabled = false,
    BookingSender? sender,
    this.callSender,
  }) : _sender = sender ?? _defaultSender;

  final String baseUrl;

  /// Kept for callers that already hold a token. [session] wins when both are set.
  final String? accessToken;

  /// Live session. Booking writes read [AuthSession.token] at call time.
  final AuthSession? session;

  /// Stays false until 001_session_bookings.sql is applied and an owner is linked.
  /// The token is still retained so a later approved release can send it.
  final bool writesEnabled;

  final BookingSender _sender;
  final BookingCallSender? callSender;

  String? get _token => session?.token ?? accessToken;

  static Future<http.Response> _defaultSender(Uri uri) {
    return http
        .get(uri, headers: const {'accept': 'application/json'})
        .timeout(const Duration(seconds: 4));
  }

  @override
  Future<AvailabilitySnapshot> loadMonth({
    required String listingKey,
    required int year,
    required int month,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/listings/${Uri.encodeComponent(listingKey)}/availability'
      '?year=$year&month=$month',
    );
    try {
      final response = await _sender(uri);
      if (response.statusCode != 200) throw const BookingLoadException();
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw const BookingLoadException();
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) throw const BookingLoadException();
      return _snapshot(listingKey, data);
    } on BookingLoadException {
      rethrow;
    } catch (_) {
      throw const BookingLoadException();
    }
  }

  @override
  Future<List<CustomerBookingRequest>> loadMyRequests() {
    return _whenWritesOpen((token) async {
      final response = await _send(
        BookingCall(
          method: 'GET',
          uri: Uri.parse('$baseUrl/api/me/booking-requests'),
          headers: _authorizedHeaders(token),
        ),
      );
      final data = _object(response)['data'];
      if (data is! List) throw const BookingLoadException();
      final requests = <CustomerBookingRequest>[];
      for (final raw in data) {
        if (raw is Map<String, dynamic>) {
          requests.add(_request(raw));
        } else if (raw is Map) {
          requests.add(_request(Map<String, dynamic>.from(raw)));
        } else {
          throw const BookingLoadException();
        }
      }
      return requests;
    });
  }

  @override
  Future<CustomerBookingRequest> submitRequest(BookingDraft draft) {
    return _whenWritesOpen((token) async {
      final response = await _send(
        BookingCall(
          method: 'POST',
          uri: Uri.parse(
            '$baseUrl/api/listings/${Uri.encodeComponent(draft.listingKey)}/booking-requests',
          ),
          headers: _authorizedHeaders(token),
          body: jsonEncode({
            'stayDate': draft.stayDate,
            'mode': bookingModeToJson(draft.mode),
          }),
        ),
      );
      final data = _object(response)['data'];
      if (data is Map<String, dynamic>) return _request(data);
      if (data is Map) return _request(Map<String, dynamic>.from(data));
      throw const BookingLoadException();
    });
  }

  Future<T> _whenWritesOpen<T>(Future<T> Function(String token) send) async {
    if (!writesEnabled) {
      throw const BookingAuthException(
        reason: BookingBlockReason.storageNotApproved,
      );
    }
    final token = _token;
    if (token == null || token.isEmpty) {
      throw const BookingAuthException();
    }
    try {
      return await send(token);
    } on BookingAuthException {
      rethrow;
    } on BookingLoadException {
      rethrow;
    } catch (_) {
      throw const BookingLoadException();
    }
  }

  Map<String, String> _authorizedHeaders(String token) {
    return {
      'accept': 'application/json',
      'content-type': 'application/json',
      'authorization': 'Bearer $token',
    };
  }

  Future<http.Response> _send(BookingCall call) {
    final sender = callSender;
    if (sender != null) return sender(call);
    if (call.method == 'GET') {
      return http
          .get(call.uri, headers: call.headers)
          .timeout(const Duration(seconds: 8));
    }
    return http
        .post(call.uri, headers: call.headers, body: call.body)
        .timeout(const Duration(seconds: 8));
  }

  Map<String, dynamic> _object(http.Response response) {
    if (response.statusCode == 401) {
      throw const BookingAuthException();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const BookingLoadException();
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw const BookingLoadException();
    }
    throw const BookingLoadException();
  }

  CustomerBookingRequest _request(Map<String, dynamic> data) {
    final reference = data['reference'];
    final stayDate = data['stayDate'];
    final status = data['status'];
    final mode = bookingModeFromJson('${data['mode']}');
    final listingKey = data['listingKey'];
    if (reference is! String ||
        stayDate is! String ||
        status is! String ||
        listingKey is! String ||
        mode == null) {
      throw const BookingLoadException();
    }
    return CustomerBookingRequest(
      reference: reference,
      listingKey: listingKey,
      stayDate: stayDate,
      mode: mode,
      status: status,
      price: data['price'] is num ? (data['price'] as num).toDouble() : null,
    );
  }

  AvailabilitySnapshot _snapshot(String listingKey, Map<String, dynamic> data) {
    final configured = data['configured'] == true;
    final days = <CalendarDay>[];
    final rawDays = data['days'];
    if (configured && rawDays is List) {
      for (final raw in rawDays) {
        if (raw is Map<String, dynamic>) {
          final day = _day(raw);
          if (day != null) days.add(day);
        } else if (raw is Map) {
          final day = _day(Map<String, dynamic>.from(raw));
          if (day != null) days.add(day);
        }
      }
    }
    return AvailabilitySnapshot(
      configured: configured,
      listingKey: listingKey,
      reason: data['reason'] as String?,
      year: data['year'] is int ? data['year'] as int : null,
      month: data['month'] is int ? data['month'] as int : null,
      days: days,
    );
  }

  CalendarDay? _day(Map<String, dynamic> raw) {
    final iso = raw['date'];
    if (iso is! String) return null;
    final parts = iso.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    final modes = <BookingMode, ModeOffer>{};
    final rawModes = raw['modes'];
    if (rawModes is Map) {
      rawModes.forEach((key, value) {
        final mode = bookingModeFromJson(key.toString());
        if (mode == null || value is! Map) return;
        final status = _modeStatus(value['status']);
        final start = value['start'];
        final end = value['end'];
        if (status == null || start is! String || end is! String) return;
        modes[mode] = ModeOffer(
          mode: mode,
          status: status,
          start: start,
          end: end,
          price: value['price'] is num
              ? (value['price'] as num).toDouble()
              : null,
        );
      });
    }
    return CalendarDay(
      date: calendarDate(year, month, day),
      state: _dayState(raw['state']) ?? DayState.unavailable,
      modes: modes,
    );
  }

  DayState? _dayState(Object? value) {
    switch (value) {
      case 'available':
        return DayState.available;
      case 'pending':
        return DayState.pending;
      case 'booked':
        return DayState.booked;
      case 'unavailable':
        return DayState.unavailable;
      case 'closed':
        return DayState.closed;
      case 'partial':
        return DayState.partial;
      default:
        return null;
    }
  }

  ModeAvailability? _modeStatus(Object? value) {
    switch (value) {
      case 'available':
        return ModeAvailability.available;
      case 'pending':
        return ModeAvailability.pending;
      case 'booked':
        return ModeAvailability.booked;
      default:
        return null;
    }
  }
}
