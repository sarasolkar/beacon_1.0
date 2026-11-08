import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/role_selection/role_selection_screen.dart';
import 'screens/hunt/join_hunt_screen.dart';
import 'screens/hunt/create_hunt_screen.dart';
import 'screens/lobby/lobby_screen.dart';
import 'screens/hunt/hunt_mode_screen.dart';
import 'screens/dashboard/hider_dashboard_screen.dart';

import 'services/firebase_auth_service.dart';
import 'services/firestore_hunt_repository.dart';
import 'services/service_locator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final serviceLocator = ServiceLocator();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    serviceLocator.setAuthService(FirebaseAuthService());
    serviceLocator.setHuntRepository(FirestoreHuntRepository());
    if (kDebugMode) debugPrint('Firebase initialized.');
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('Firebase initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    serviceLocator.setAuthUnavailable(
      'Firebase could not be initialized. Check the Firebase configuration '
      'for this platform. Details: $error',
    );
  }

  runApp(const BeaconApp());
}

class BeaconApp extends StatelessWidget {
  const BeaconApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beacon',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
      navigatorObservers: [roleSelectionRouteObserver],
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/role-selection': (context) => const RoleSelectionScreen(),
        '/join-hunt': (context) => const JoinHuntScreen(),
        '/create-hunt': (context) => const CreateHuntScreen(),
        '/lobby': (context) => const LobbyScreen(roomCode: '7K3P9'),
        '/hunt-mode': (context) => const HuntModeScreen(roomCode: '7K3P9'),
        '/hider-dashboard': (context) =>
            const HiderDashboardScreen(roomCode: '7K3P9'),
      },
    );
  }
}
