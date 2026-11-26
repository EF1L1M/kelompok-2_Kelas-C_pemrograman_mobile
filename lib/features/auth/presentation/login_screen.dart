import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/firebase/firebase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/form_validator_mixin.dart';
import '../../../core/widgets/patungin_patterns.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with FormValidatorMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      context.read<AuthCubit>().signInWithEmail(
            email: _emailController.text,
            password: _passwordController.text,
          );
    }
  }

  void _showForgotPasswordDialog() {
    final resetCtrl = TextEditingController(text: _emailController.text.trim());
    final resetFormKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Kata Sandi'),
        content: Form(
          key: resetFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Masukkan email yang terdaftar di BagiTigaKan untuk menerima tautan pengaturan ulang kata sandi.',
                style: TextStyle(fontSize: 13, color: AppTheme.mutedInk),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: resetCtrl,
                keyboardType: TextInputType.emailAddress,
                validator: validateEmail,
                decoration: const InputDecoration(
                  labelText: 'Alamat Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!(resetFormKey.currentState?.validate() ?? false)) return;
              final email = resetCtrl.text.trim();
              Navigator.pop(ctx);
              final err =
                  await context.read<AuthCubit>().sendPasswordResetEmail(email);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    err ??
                        'Tautan reset kata sandi telah dikirim ke $email (cek log Auth Emulator jika menggunakan emulator lokal).',
                  ),
                  backgroundColor: err != null
                      ? AppTheme.statusRejected
                      : AppTheme.primaryEmerald,
                ),
              );
            },
            child: const Text('Kirim Tautan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        switch (state) {
          case AuthAuthenticated():
            context.go('/home');
          case AuthError(:final message):
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: AppTheme.statusRejected,
              ),
            );
          default:
            break;
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return Scaffold(
          backgroundColor: AppTheme.warmCream,
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Header gelombang organik hangat — menggantikan kotak form kaku
                OrganicWaveHeader(
                  waveDepth: 34,
                  padding: EdgeInsets.fromLTRB(
                    24,
                    MediaQuery.of(context).padding.top + 28,
                    24,
                    54,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const BagiTigaKanLogo(
                                size: 46,
                                showSubtleBorder: true,
                              ),
                              const SizedBox(width: 12),
                              const BagiTigaKanWordmark(
                                fontSize: 22,
                                onDark: true,
                                showTagline: true,
                              ),
                              const Spacer(),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor:
                                      AppTheme.warmCream.withValues(alpha: 0.9),
                                ),
                                onPressed: isLoading
                                    ? null
                                    : () => context.go('/onboarding'),
                                child: const Text('Info Fitur'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 26),
                          Text(
                            '${timeBasedGreeting()}!',
                            style: TextStyle(
                              color:
                                  AppTheme.butterWash.withValues(alpha: 0.95),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Masuk dan lanjut\npatungan bareng teman.',
                            style: TextStyle(
                              color: AppTheme.warmCream,
                              fontSize: 27,
                              height: 1.2,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.7,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Area formulir terbuka di atas kertas hangat (tanpa kurungan kotak)
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Email Terdaftar',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkSlate,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              validator: validateEmail,
                              decoration: const InputDecoration(
                                hintText: 'nama@email.com',
                                prefixIcon: Icon(Icons.alternate_email_rounded),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Kata Sandi',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkSlate,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) => _submitLogin(),
                              validator: validatePassword,
                              decoration: InputDecoration(
                                hintText: 'Masukkan kata sandi Anda',
                                prefixIcon:
                                    const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: isLoading
                                    ? null
                                    : _showForgotPasswordDialog,
                                child: const Text('Lupa kata sandi?'),
                              ),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              onPressed: isLoading ? null : _submitLogin,
                              icon: isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.arrow_forward_rounded),
                              label: Text(
                                isLoading
                                    ? 'Sedang masuk...'
                                    : 'Masuk Sekarang',
                              ),
                            ),
                            const SizedBox(height: 24),
                            const DashedDivider(),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Baru di BagiTigaKan? ',
                                  style: TextStyle(color: AppTheme.mutedInk),
                                ),
                                TextButton(
                                  onPressed: isLoading
                                      ? null
                                      : () => context.go('/register'),
                                  child: const Text('Buat Akun Baru'),
                                ),
                              ],
                            ),
                            if (FirebaseAppConfig.useEmulator) ...[
                              const SizedBox(height: 12),
                              Center(
                                child: DashedCouponChip(
                                  icon: Icons.dns_outlined,
                                  color: AppTheme.primaryEmerald,
                                  label:
                                      'Emulator · ${FirebaseAppConfig.emulatorHost}:${FirebaseAppConfig.authEmulatorPort}',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
