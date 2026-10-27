import 'package:maseef_app/l10n/place_names.dart';

class Listing {
  const Listing({
    required this.id,
    required this.name,
    required this.governorate,
    required this.locality,
    required this.whatsapp,
    required this.referencedImageFilename,
    this.facebookUrl,
    this.instagramUrl,
    this.photoAssets = const [],
    this.videoUrl,
    this.bedrooms,
    this.amenityKeys = const [],
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String governorate;
  final String locality;
  final String whatsapp;
  final String? facebookUrl;
  final String? instagramUrl;

  /// Basename of the bundled photo, matching the file in assets/images.
  final String referencedImageFilename;
  final List<String> photoAssets;
  final String? videoUrl;

  /// Supplied bedroom count. Omitted when the host has not provided one.
  final int? bedrooms;

  /// Stable amenity keys supplied for this listing. Empty when none were provided.
  final List<String> amenityKeys;

  /// Exact chalet coordinates, only when the host has supplied them.
  ///
  /// No listing has these yet. They must never be filled in by geocoding the
  /// locality: an area is not the chalet. A future owner workflow will let a
  /// host pick the exact point on a map and save it.
  final double? latitude;
  final double? longitude;

  bool get hasPhoto => photoAssets.isNotEmpty;

  /// True only when both coordinates exist and are valid.
  bool get hasExactLocation => isValidCoordinate(latitude, longitude);

  /// What "Open in Google Maps" opens: the exact point when known, otherwise a
  /// search for the known locality and governorate (an area, not the chalet).
  Uri get mapsUri => hasExactLocation
      ? googleMapsSearchUri('$latitude,$longitude')
      : googleMapsSearchUri('$locality، $governorate، فلسطين');

  String get locationLabel => '$locality، $governorate';

  bool matchesQuery(String query) {
    final needle = _normalizeSearch(query);
    if (needle.isEmpty) return true;
    final haystack = _normalizeSearch(
      [
        name,
        ...searchTermsForPlace(governorate),
        ...searchTermsForPlace(locality),
      ].join(' '),
    );
    return haystack.contains(needle);
  }
}

String _normalizeSearch(String value) {
  return value
      .toLowerCase()
      .replaceAll('-', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Whether [latitude] and [longitude] describe a real point on Earth.
bool isValidCoordinate(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) return false;
  if (latitude.isNaN || longitude.isNaN) return false;
  return latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}

/// A keyless Google Maps URL (https://developers.google.com/maps/documentation/urls).
/// [query] is a place name or a "lat,lng" pair.
Uri googleMapsSearchUri(String query) {
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': query,
  });
}

/// Converts a supplied phone number into a WhatsApp link.
/// A local number that starts with 0 uses the Palestinian country code.
Uri whatsAppUri(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) {
    throw ArgumentError('WhatsApp number is empty');
  }
  final international = digits.startsWith('0')
      ? '970${digits.substring(1)}'
      : digits;
  return Uri.parse('https://wa.me/$international');
}
