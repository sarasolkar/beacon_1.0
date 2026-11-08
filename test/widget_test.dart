import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beacon/main.dart';
import 'package:beacon/screens/role_selection/role_selection_screen.dart';
import 'package:beacon/screens/hunt/hunt_created_screen.dart';
import 'package:beacon/screens/auth/login_screen.dart';
import 'package:beacon/models/hunt.dart';
import 'package:beacon/models/hunt_room.dart';
import 'package:beacon/models/hint_item.dart';
import 'package:beacon/models/user_profile.dart';
import 'package:beacon/services/auth_service.dart';
import 'package:beacon/services/hunt_repository.dart';
import 'package:beacon/services/service_locator.dart';

const _testUser = UserProfile(
  uid: 'test_user',
  displayName: 'Test Player',
  email: 'player@example.com',
);

/// Minimal in-memory auth used only by these tests.
class _FakeAuthService implements AuthService {
  UserProfile? _user;

  @override
  Stream<UserProfile?> get authStateChanges => const Stream.empty();

  @override
  UserProfile? get currentUser => _user;

  @override
  bool get isAuthenticated => _user != null;

  @override
  Future<UserProfile?> signInWithEmail(String email, String password) async =>
      _user = _testUser;

  @override
  Future<UserProfile?> signInWithGoogle() async => _user = _testUser;

  @override
  Future<UserProfile?> signInAnonymously({String? displayName}) async =>
      _user = _testUser;

  @override
  Future<UserProfile?> signUpWithEmail(
    String email,
    String password,
    String displayName,
  ) async => _user = _testUser;

  @override
  Future<void> signOut() async => _user = null;

  @override
  Future<void> syncUserProfile(UserProfile user) async {}
}

class _ProfileSyncFailingAuthService extends _FakeAuthService {
  @override
  Future<UserProfile?> signInWithEmail(String email, String password) async {
    final user = await super.signInWithEmail(email, password);
    throw ProfileSyncException(
      user: user!,
      cause: StateError('Firestore profile write failed'),
    );
  }
}

class _HangingAuthService extends _FakeAuthService {
  @override
  Future<UserProfile?> signInWithEmail(String email, String password) =>
      Completer<UserProfile?>().future;
}

/// Only the methods these tests call are implemented.
class _FakeHuntRepository implements HuntRepository {
  int currentHuntFetchCount = 0;

  @override
  Future<List<HuntRoom>> getCurrentHuntsForUser(String userId) async {
    currentHuntFetchCount++;
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    ServiceLocator().setAuthService(_FakeAuthService());
    ServiceLocator().setHuntRepository(_FakeHuntRepository());
  });

  testWidgets('Splash screen renders Beacon branding and navigates to Login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const BeaconApp());
    await tester.pumpAndSettle();

    expect(find.text('Beacon'), findsOneWidget);
    expect(find.text('Hide'), findsOneWidget);
    expect(find.text('Hint'), findsOneWidget);
    expect(find.text('Hunt.'), findsOneWidget);
    expect(find.text("Let's Go"), findsOneWidget);

    await tester.tap(find.text("Let's Go"));
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.byTooltip('Show password'), findsOneWidget);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('Email sign-in succeeds and navigates to Role Selection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'player@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'securepass123');
    await tester.ensureVisible(find.text('Sign In'));
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Choose Your Path'), findsOneWidget);
    expect(find.text('Welcome Back'), findsNothing);
  });

  testWidgets(
    'Navigates to home when authentication succeeds but profile sync fails',
    (WidgetTester tester) async {
      ServiceLocator().setAuthService(_ProfileSyncFailingAuthService());

      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'player@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'securepass123');
      await tester.ensureVisible(find.text('Sign In'));
      await tester.tap(find.text('Sign In'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Choose Your Path'), findsOneWidget);
      expect(find.textContaining('profile sync failed'), findsOneWidget);
    },
  );

  testWidgets('Releases the login spinner when authentication times out', (
    WidgetTester tester,
  ) async {
    ServiceLocator().setAuthService(_HangingAuthService());

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'player@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'securepass123');
    await tester.ensureVisible(find.text('Sign In'));
    await tester.tap(find.text('Sign In'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 31));

    expect(
      find.text(
        'Sign-in timed out. Check your internet connection and try again.',
      ),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Role Selection renders profile and options', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RoleSelectionScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Choose Your Path'), findsOneWidget);
    expect(find.text('Hide an Object'), findsOneWidget);
    expect(find.text('Join a Hunt'), findsOneWidget);
    expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
  });

  testWidgets('Current hunts refresh when returning to Role Selection', (
    WidgetTester tester,
  ) async {
    final auth = _FakeAuthService();
    await auth.signInWithEmail('player@example.com', 'securepass123');
    ServiceLocator().setAuthService(auth);
    final repository = _FakeHuntRepository();
    ServiceLocator().setHuntRepository(repository);
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [roleSelectionRouteObserver],
        home: const RoleSelectionScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.currentHuntFetchCount, 1);

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Temporary Hunt Screen')),
      ),
    );
    await tester.pumpAndSettle();
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(repository.currentHuntFetchCount, 2);
  });

  testWidgets('HuntCreatedScreen displays hunt details and lobby button', (
    WidgetTester tester,
  ) async {
    final hunt = Hunt(
      id: 'test_1',
      code: '7K3P9',
      name: 'Emerald Ridge Cache',
      locationCoordinates: '37.7749° N, 122.4194° W',
      difficulty: HuntDifficulty.medium,
      reward: 'Vintage Compass Coin',
      hints: HintItem.defaultHints(),
    );

    await tester.pumpWidget(MaterialApp(home: HuntCreatedScreen(hunt: hunt)));
    await tester.pumpAndSettle();

    expect(find.text('Hunt Created!'), findsOneWidget);
    expect(find.text('7K3P9'), findsWidgets);
    expect(find.text('Emerald Ridge Cache'), findsOneWidget);
    expect(find.text('Open Hunt Lobby 🚀'), findsOneWidget);
    expect(find.text('Share Hunt Code'), findsOneWidget);
  });
}