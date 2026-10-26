import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class EmailOtpScreen extends StatefulWidget {
  final AuthService authService;

  const EmailOtpScreen({super.key, required this.authService});

  @override
  State<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends State<EmailOtpScreen> {
  final TextEditingController _emailController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isCodeSent = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Countdown timer for resend
  Timer? _timer;
  int _secondsRemaining = 60;
  bool _canResend = false;

  @override
  void dispose() {
    _emailController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _secondsRemaining = 60;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        setState(() {
          _secondsRemaining = 0;
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  String _maskEmail(String email) {
    if (!email.contains('@')) return email;
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) {
      return '$name***@$domain';
    }
    return '${name.substring(0, 2)}***${name.substring(name.length - 1)}@$domain';
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(email.trim());
  }

  Future<void> _handleSendCode() async {
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      setState(() {
        _errorMessage = 'Please enter a valid email address';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.sendEmailOtp(email);
      setState(() {
        _isCodeSent = true;
        _isLoading = false;
      });
      _startCountdown();
      // Auto focus first OTP field
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_focusNodes[0].canRequestFocus) {
          _focusNodes[0].requestFocus();
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _handleVerifyCode() async {
    final otp = _otpControllers.map((c) => c.text.trim()).join();
    if (otp.length < 6) {
      setState(() {
        _errorMessage = 'Please enter the complete 6-digit verification code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.verifyEmailOtp(_emailController.text.trim(), otp);
      if (mounted) {
        Navigator.of(context).pop(); // Back to root, StreamBuilder navigates to home
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _onOtpChanged(int index, String value) {
    if (value.length > 1) {
      // User pasted code
      final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
      for (int i = 0; i < 6; i++) {
        if (i < clean.length) {
          _otpControllers[i].text = clean[i];
        }
      }
      if (clean.length >= 6) {
        _focusNodes[5].unfocus();
        _handleVerifyCode();
      } else {
        _focusNodes[clean.length].requestFocus();
      }
      return;
    }

    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        // Automatically submit when 6th digit entered
        final fullOtp = _otpControllers.map((c) => c.text).join();
        if (fullOtp.length == 6) {
          _handleVerifyCode();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            if (_isCodeSent) {
              setState(() {
                _isCodeSent = false;
                _errorMessage = null;
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 20),
                child: IntrinsicHeight(
                  child: _isCodeSent ? _buildOtpView() : _buildEmailView(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmailView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          'Sign in with email',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "We'll send you a verification code to confirm it's you.",
          style: TextStyle(
            fontSize: 15,
            color: AppTheme.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 36),
        const Text(
          'Email address',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleSendCode(),
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'name@example.com',
            hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 15),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            filled: true,
            fillColor: AppTheme.surface,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.border, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppTheme.brandBlack, width: 1.6),
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: const TextStyle(color: AppTheme.error, fontSize: 13),
          ),
        ],
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSendCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandBlack,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.2,
                    ),
                  )
                : const Text(
                    'Send verification code',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildOtpView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          'Enter verification code',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
            children: [
              const TextSpan(text: 'We sent a 6-digit code to '),
              TextSpan(
                text: _maskEmail(_emailController.text.trim()),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const TextSpan(text: '. Enter it below to sign in.'),
            ],
          ),
        ),
        const SizedBox(height: 36),
        // 6-digit OTP fields
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 46,
              height: 56,
              child: KeyboardListener(
                focusNode: FocusNode(),
                onKeyEvent: (event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.backspace &&
                      _otpControllers[index].text.isEmpty &&
                      index > 0) {
                    _focusNodes[index - 1].requestFocus();
                  }
                },
                child: TextField(
                  controller: _otpControllers[index],
                  focusNode: _focusNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 6, // Allows paste into first box
                  buildCounter: (context,
                          {required currentLength,
                          required isFocused,
                          maxLength}) =>
                      null,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    filled: true,
                    fillColor: AppTheme.surface,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppTheme.border, width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: AppTheme.brandBlack, width: 1.8),
                    ),
                  ),
                  onChanged: (val) => _onOtpChanged(index, val),
                ),
              ),
            );
          }),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          Text(
            _errorMessage!,
            style: const TextStyle(color: AppTheme.error, fontSize: 13),
          ),
        ],
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleVerifyCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandBlack,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.2,
                    ),
                  )
                : const Text(
                    'Verify & Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: _canResend
              ? TextButton(
                  onPressed: _isLoading ? null : _handleSendCode,
                  child: const Text(
                    'Resend code',
                    style: TextStyle(
                      color: AppTheme.brandBlack,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : Text(
                  'Resend code in $_secondsRemaining seconds',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 14,
                  ),
                ),
        ),
        const Spacer(),
      ],
    );
  }
}
