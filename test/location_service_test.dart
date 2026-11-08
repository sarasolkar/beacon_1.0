import 'package:flutter_test/flutter_test.dart';
import 'package:beacon/services/location_service.dart';
import 'package:beacon/services/gps_simulation_service.dart';

void main() {
  group('LocationService Math Tests', () {
    test('parseCoordinates handles directional coordinates', () {
      expect(LocationService.parseCoordinates('37.7749° N, 122.4194° W'), (
        37.7749,
        -122.4194,
      ));
    });

    test('parseCoordinates rejects invalid coordinates', () {
      expect(LocationService.parseCoordinates('91, 0'), isNull);
      expect(LocationService.parseCoordinates('not coordinates'), isNull);
    });

    test('calculateDistanceMeters returns 0 for identical coordinates', () {
      final distance = LocationService.calculateDistanceMeters(
        startLatitude: 37.7749,
        startLongitude: -122.4194,
        endLatitude: 37.7749,
        endLongitude: -122.4194,
      );
      expect(distance, closeTo(0.0, 0.001));
    });

    test(
      'calculateDistanceMeters accurately calculates known distance in San Francisco',
      () {
        // Market St & 4th St (37.7858, -122.4065) to Market St & 5th St (37.7842, -122.4079) ~210m
        final distance = LocationService.calculateDistanceMeters(
          startLatitude: 37.7858,
          startLongitude: -122.4065,
          endLatitude: 37.7842,
          endLongitude: -122.4079,
        );
        expect(distance, greaterThan(190.0));
        expect(distance, lessThan(230.0));
      },
    );

    test(
      'calculateBearingDegrees returns 0 (due North) when moving North along meridian',
      () {
        final bearing = LocationService.calculateBearingDegrees(
          startLatitude: 10.0,
          startLongitude: 50.0,
          endLatitude: 11.0,
          endLongitude: 50.0,
        );
        expect(bearing, closeTo(0.0, 0.1));
      },
    );

    test('calculateBearingDegrees returns 90 (due East) along equator', () {
      final bearing = LocationService.calculateBearingDegrees(
        startLatitude: 0.0,
        startLongitude: 0.0,
        endLatitude: 0.0,
        endLongitude: 1.0,
      );
      expect(bearing, closeTo(90.0, 0.1));
    });

    test('calculateBearingDegrees returns 180 (due South) along meridian', () {
      final bearing = LocationService.calculateBearingDegrees(
        startLatitude: 11.0,
        startLongitude: 50.0,
        endLatitude: 10.0,
        endLongitude: 50.0,
      );
      expect(bearing, closeTo(180.0, 0.1));
    });
  });

  group('GpsSimulationService Tests', () {
    late GpsSimulationService simulationService;

    setUp(() {
      simulationService = GpsSimulationService(
        initialLat: 37.7700,
        initialLng: -122.4200,
        targetLat: 37.7749,
        targetLng: -122.4194,
      );
    });

    tearDown(() {
      simulationService.dispose();
    });

    test('Initial distance and bearing are computed towards target', () {
      expect(simulationService.distanceToTargetMeters, greaterThan(500.0));
      expect(simulationService.distanceToTargetMeters, lessThan(600.0));
      expect(simulationService.bearingToTargetDegrees, greaterThan(0.0));
      expect(simulationService.bearingToTargetDegrees, lessThan(15.0));
    });

    test('stepTowardsTarget reduces distance towards the treasure', () {
      final initialDistance = simulationService.distanceToTargetMeters;
      simulationService.stepTowardsTarget(100.0);
      final newDistance = simulationService.distanceToTargetMeters;

      expect(newDistance, lessThan(initialDistance));
      expect(initialDistance - newDistance, closeTo(100.0, 5.0));
    });

    test('stepAwayFromTarget increases distance from the treasure', () {
      final initialDistance = simulationService.distanceToTargetMeters;
      simulationService.stepAwayFromTarget(50.0);
      final newDistance = simulationService.distanceToTargetMeters;

      expect(newDistance, greaterThan(initialDistance));
      expect(newDistance - initialDistance, closeTo(50.0, 5.0));
    });

    test('teleportToDistance snaps position to exact proximity', () {
      simulationService.teleportToDistance(15.0);
      expect(simulationService.distanceToTargetMeters, closeTo(15.0, 1.0));
    });

    test('Position stream emits new position on step', () async {
      expectLater(
        simulationService.positionStream,
        emits(predicate<PositionData>((p) => p.accuracy <= 5.0)),
      );

      simulationService.stepTowardsTarget(50.0);
    });
  });
}
