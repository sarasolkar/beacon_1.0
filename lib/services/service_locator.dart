import 'auth_service.dart';
import 'hunt_repository.dart';
import '../models/user_profile.dart';

/// Injectable service locator singleton.
///
/// Production services are registered after Firebase initializes (see
/// main.dart). Until then, authentication fails closed.
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  // ── Auth ───────────────────────────────────────────────────────────────────

  AuthService _authService = _UnavailableAuthService();

  AuthService get authService => _authService;

  bool get isAuthAvailable => _authService is! _UnavailableAuthService;

  void setAuthService(AuthService service) {
    _authService = service;
  }

  void setAuthUnavailable([String? message]) {
    _authService = _UnavailableAuthService(message);
  }

  // ── Hunt repository ────────────────────────────────────────────────────────

  HuntRepository? _huntRepository;

  HuntRepository get huntRepository {
    final repository = _huntRepository;
    if (repository == null) {
      throw StateError(
        'The hunt repository is unavailable until Firebase is initialized.',
      );
    }
    return repository;
  }

  void setHuntRepository(HuntRepository repository) {
    _huntRepository = repository;
  }
}

class _UnavailableAuthService implements AuthService {
  final String _message;

  _UnavailableAuthService([String? message])
    : _message =
          message ??
          'Authentication is unavailable until Firebase is configured.';

  @override
  Stream<UserProfile?> get authStateChanges => const Stream.empty();

  @override
  UserProfile? get currentUser => null;

  @override
  bool get isAuthenticated => false;

  @override
  Future<UserProfile?> signInWithGoogle() async => throw StateError(_message);

  @override
  Future<UserProfile?> signInAnonymously({String? displayName}) async =>
      throw StateError(_message);

  @override
  Future<UserProfile?> signInWithEmail(String email, String password) async =>
      throw StateError(_message);

  @override
  Future<UserProfile?> signUpWithEmail(
    String email,
    String password,
    String displayName,
  ) async => throw StateError(_message);

  @override
  Future<void> signOut() async {}

  @override
  Future<void> syncUserProfile(UserProfile user) async {}
}