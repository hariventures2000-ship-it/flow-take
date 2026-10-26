import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlowTake',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: StreamBuilder<User?>(
        stream: _authService.authStateChanges,
        builder: (context, snapshot) {
          // While checking authentication persistence state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: AppTheme.background,
              body: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: AppTheme.brandBlack,
                    strokeWidth: 2.2,
                  ),
                ),
              ),
            );
          }

          // If user is authenticated, show Dashboard; else show Take.app Welcome Screen
          if (snapshot.hasData && snapshot.data != null) {
            return HomeScreen(
              user: snapshot.data!,
              authService: _authService,
            );
          }

          return WelcomeScreen(authService: _authService);
        },
      ),
    );
  }
}
