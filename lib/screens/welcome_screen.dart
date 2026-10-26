import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/google_icon.dart';
import 'email_otp_screen.dart';

class WelcomeScreen extends StatefulWidget {
  final AuthService authService;

  const WelcomeScreen({super.key, required this.authService});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isGoogleLoading = false;
  String? _errorMessage;

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.signInWithGoogle();
      // Navigation is automatically handled by authStateChanges in main.dart
    } on FirebaseAuthException catch (e) {
      if (e.code == 'ERROR_ABORTED_BY_USER' ||
          e.code == 'popup_closed_by_user' ||
          e.message?.contains('cancelled') == true) {
        // User voluntarily dismissed
      } else {
        setState(() {
          _errorMessage = '[Firebase] ${e.code}: ${e.message}';
        });
      }
    } catch (e) {
      debugPrint('Google Sign-in failed with error: $e');
      setState(() {
        _errorMessage = e.toString().replaceAll('PlatformException(', '').replaceAll(')', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  void _navigateToEmailLogin() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            EmailOtpScreen(authService: widget.authService),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          final tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight - 20),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 36),

                      // Brand Logo / Monogram
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.brandBlack,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                'F',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'FlowTake',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.6,
                            ),
                          ),
                        ],
                      ),

                      const Spacer(flex: 2),

                      // Main Heading
                      const Text(
                        'Your business,\nmade simple.',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -1.2,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Supporting Subtitle
                      const Text(
                        'Sign in to manage your store, connect with customers, and grow your business.',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.textSecondary,
                          height: 1.45,
                        ),
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFFCA5A5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  size: 18, color: AppTheme.error),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: AppTheme.error,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const Spacer(flex: 3),

                      // Primary Button: Continue with Google
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton(
                          onPressed:
                              _isGoogleLoading ? null : _handleGoogleSignIn,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(
                                color: AppTheme.border, width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: _isGoogleLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: AppTheme.brandBlack,
                                    strokeWidth: 2.2,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    GoogleIcon(size: 20),
                                    SizedBox(width: 12),
                                    Text(
                                      'Continue with Google',
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Secondary Button: Continue with email
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isGoogleLoading ? null : _navigateToEmailLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.brandBlack,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Continue with email',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Terms and Privacy Footer
                      Center(
                        child: Text(
                          'By continuing, you agree to our Terms of Service and Privacy Policy.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted.withValues(alpha: 0.9),
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
