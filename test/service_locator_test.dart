import 'package:flutter_test/flutter_test.dart';
import 'package:beacon/models/hunt_room.dart';
import 'package:beacon/services/hunt_repository.dart';
import 'package:beacon/services/service_locator.dart';

class _FakeHuntRepository implements HuntRepository {
  @override
  Future<List<HuntRoom>> getCurrentHuntsForUser(String userId) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('hunt repository is unavailable until one is registered', () {
    final services = ServiceLocator();
    expect(() => services.huntRepository, throwsStateError);

    final repository = _FakeHuntRepository();
    services.setHuntRepository(repository);
    expect(services.huntRepository, same(repository));
  });

  test('auth fails closed until Firebase auth is registered', () {
    final services = ServiceLocator();
    services.setAuthUnavailable('Firebase is not configured.');

    expect(services.isAuthAvailable, isFalse);
    expect(services.authService.currentUser, isNull);
    expect(services.authService.signInWithEmail('a@b.com', 'secret1'), throwsStateError);
  });
}