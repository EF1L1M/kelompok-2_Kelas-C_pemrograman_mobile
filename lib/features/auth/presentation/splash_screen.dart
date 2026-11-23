import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

// ============================================================================
// SPLASH SCREEN (UFD-1: Tunggu FirebaseAuth authStateChanges -> Home / Onboarding / Login)
// ============================================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _minDelayElapsed = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _minDelayElapsed = true;
      _tryNavigate(context.read<AuthCubit>().state);
    });
  }

  void _tryNavigate(AuthState state) {
    if (!mounted || !_minDelayElapsed || _hasNavigated) return;
    if (state is AuthInitial || state is AuthLoading) return;

    _hasNavigated = true;
    switch (state) {
      case AuthAuthenticated():
        context.go('/home');
      case AuthUnauthenticated(:final showOnboardingFirst):
        context.go(showOnboardingFirst ? '/onboarding' : '/login');
      default:
        context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) => _tryNavigate(state),
      child: Scaffold(
        backgroundColor: AppTheme.darkSlate,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryEmerald, AppTheme.secondaryTeal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryEmerald.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 46,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Patungin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pindai Struk · Konversi Kurs Otomatis · Patungan Real-Time',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: AppTheme.primaryEmerald,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
