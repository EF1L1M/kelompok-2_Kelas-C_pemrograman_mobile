import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/patungin_patterns.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

// ============================================================================
// SPLASH SCREEN — Kanvas botani hangat dengan emblem pebble organik
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
    Future<void>.delayed(const Duration(milliseconds: 850), () {
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
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF143C2E),
                Color(0xFF1B6B50),
                Color(0xFF287D62),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: CustomPaint(
            painter: const OrganicCanvasPainter(
              blobColor: Color(0x16FAF6F0),
              dotColor: Color(0x1AFAF6F0),
            ),
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 132,
                            height: 132,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    AppTheme.warmCream.withValues(alpha: 0.16),
                                width: 1.5,
                              ),
                            ),
                          ),
                          const BagiTigaKanLogo(
                            size: 94,
                            showSubtleBorder: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const BagiTigaKanWordmark(
                        fontSize: 32,
                        onDark: true,
                        showTagline: true,
                        alignment: CrossAxisAlignment.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Patungan bareng teman, adil sampai rupiah terakhir.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.warmCream.withValues(alpha: 0.82),
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 36),
                      const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppTheme.butterWash,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
