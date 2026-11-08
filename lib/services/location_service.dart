import 'dart:math' as math;

enum LocationPermissionStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

class PositionData {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double altitude;
  final double heading;
  final double speed;
  final DateTime timestamp;

  const PositionData({
    required this.latitude,
    required this.longitude,
    this.accuracy = 5.0,
    this.altitude = 0.0,
    this.heading = 0.0,
    this.speed = 0.0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? const _DefaultDateTime();
}

class _DefaultDateTime implements DateTime {
  const _DefaultDateTime();
  @override
  dynamic noSuchMethod(Invocation invocation) => DateTime.now();
}

abstract class LocationService {
  Future<LocationPermissionStatus> checkPermission();
  Future<LocationPermissionStatus> requestPermission();
  Stream<PositionData> get positionStream;
  Stream<double> get headingStream;

  static (double, double)? parseCoordinates(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parts = raw.split(',');
    if (parts.length != 2) return null;

    try {
      double parsePart(String part) {
        final tokens = part.replaceAll('°', '').trim().split(RegExp(r'\s+'));
        final value = double.parse(tokens.first);
        if (tokens.length > 1) {
          switch (tokens[1].toUpperCase()) {
            case 'S':
            case 'W':
              return -value.abs();
            case 'N':
            case 'E':
              return value.abs();
          }
        }
        return value;
      }

      final latitude = parsePart(parts[0]);
      final longitude = parsePart(parts[1]);
      if (latitude.abs() > 90 || longitude.abs() > 180) return null;
      return (latitude, longitude);
    } on FormatException {
      return null;
    }
  }

  /// Pure-Dart Haversine distance in meters
  static double calculateDistanceMeters({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    const double earthRadiusMeters = 6371000.0;
    final double dLat = _toRadians(endLatitude - startLatitude);
    final double dLon = _toRadians(endLongitude - startLongitude);

    final double lat1 = _toRadians(startLatitude);
    final double lat2 = _toRadians(endLatitude);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) *
            math.sin(dLon / 2) *
            math.cos(lat1) *
            math.cos(lat2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  /// Pure-Dart forward azimuth bearing in degrees (0° to 360°)
  static double calculateBearingDegrees({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    final double lat1 = _toRadians(startLatitude);
    final double lat2 = _toRadians(endLatitude);
    final double dLon = _toRadians(endLongitude - startLongitude);

    final double y = math.sin(dLon) * math.cos(lat2);
    final double x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final double radians = math.atan2(y, x);
    final double degrees = (radians * 180.0 / math.pi + 360.0) % 360.0;
    return degrees;
  }

  static double _toRadians(double degree) => degree * math.pi / 180.0;
}
