import 'dart:async';
import 'location_service.dart';

class GpsSimulationService implements LocationService {
  double _currentLat;
  double _currentLng;
  double _targetLat;
  double _targetLng;
  double _currentHeading = 45.0;
  LocationPermissionStatus _permissionStatus = LocationPermissionStatus.granted;

  final StreamController<PositionData> _positionController =
      StreamController<PositionData>.broadcast();
  final StreamController<double> _headingController =
      StreamController<double>.broadcast();

  GpsSimulationService({
    double initialLat = 37.7725,
    double initialLng = -122.4220,
    this._targetLat = 37.7749,
    this._targetLng = -122.4194,
  })  : _currentLat = initialLat,
        _currentLng = initialLng;

  double get currentLatitude => _currentLat;
  double get currentLongitude => _currentLng;
  double get currentHeading => _currentHeading;

  double get distanceToTargetMeters => LocationService.calculateDistanceMeters(
        startLatitude: _currentLat,
        startLongitude: _currentLng,
        endLatitude: _targetLat,
        endLongitude: _targetLng,
      );

  double get bearingToTargetDegrees => LocationService.calculateBearingDegrees(
        startLatitude: _currentLat,
        startLongitude: _currentLng,
        endLatitude: _targetLat,
        endLongitude: _targetLng,
      );

  @override
  Future<LocationPermissionStatus> checkPermission() async => _permissionStatus;

  @override
  Future<LocationPermissionStatus> requestPermission() async => _permissionStatus;

  void setPermissionStatus(LocationPermissionStatus status) {
    _permissionStatus = status;
  }

  void setTargetCoordinates(double lat, double lng) {
    _targetLat = lat;
    _targetLng = lng;
    _emitPosition();
  }

  @override
  Stream<PositionData> get positionStream => _positionController.stream;

  @override
  Stream<double> get headingStream => _headingController.stream;

  /// Move hunter along the bearing vector towards the treasure
  void stepTowardsTarget(double meters) {
    final currentDist = distanceToTargetMeters;
    if (currentDist <= meters) {
      teleportToDistance(5.0);
      return;
    }

    final ratio = meters / currentDist;
    _currentLat += (_targetLat - _currentLat) * ratio;
    _currentLng += (_targetLng - _currentLng) * ratio;
    _currentHeading = bearingToTargetDegrees;

    _emitPosition();
  }

  /// Move hunter away from the treasure
  void stepAwayFromTarget(double meters) {
    final currentDist = distanceToTargetMeters;
    final ratio = meters / currentDist;
    _currentLat -= (_targetLat - _currentLat) * ratio;
    _currentLng -= (_targetLng - _currentLng) * ratio;

    _emitPosition();
  }

  /// Snaps position to exact distance from target
  void teleportToDistance(double desiredDistanceMeters) {
    // Offset along latitude (approx 111,111 meters per degree)
    const metersPerDegreeLat = 111111.0;
    final latOffset = desiredDistanceMeters / metersPerDegreeLat;

    _currentLat = _targetLat - latOffset;
    _currentLng = _targetLng;
    _currentHeading = bearingToTargetDegrees;

    _emitPosition();
  }

  void setHeading(double degrees) {
    _currentHeading = (degrees % 360.0 + 360.0) % 360.0;
    _headingController.add(_currentHeading);
  }

  void _emitPosition() {
    _positionController.add(
      PositionData(
        latitude: _currentLat,
        longitude: _currentLng,
        accuracy: 3.5,
        altitude: 15.0,
        heading: _currentHeading,
        speed: 1.4, // ~5 km/h walking speed
        timestamp: DateTime.now(),
      ),
    );
    _headingController.add(_currentHeading);
  }

  void dispose() {
    _positionController.close();
    _headingController.close();
  }
}
