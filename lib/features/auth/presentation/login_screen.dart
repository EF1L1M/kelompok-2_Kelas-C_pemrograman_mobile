import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/firebase/firebase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/form_validator_mixin.dart';
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
                'Masukkan email yang terdaftar di Patungin untuk menerima tautan pengaturan ulang kata sandi.',
                style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
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
              final err = await context
                  .read<AuthCubit>()
                  .sendPasswordResetEmail(email);
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
                  behavior: SnackBarBehavior.floating,
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
                behavior: SnackBarBehavior.floating,
              ),
            );
          default:
            break;
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryEmerald
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: AppTheme.primaryEmerald,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Patungin',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.darkSlate,
                                  ),
                                ),
                                Text(
                                  'Kelola patungan grup & pelunasan tagihan dengan mudah',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Masuk ke Akun Anda',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Gunakan email dan kata sandi yang sudah terdaftar.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email],
                                  validator: validateEmail,
                                  decoration: const InputDecoration(
                                    labelText: 'Alamat Email',
                                    hintText: 'contoh@email.com',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.password],
                                  onFieldSubmitted: (_) => _submitLogin(),
                                  validator: validatePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Kata Sandi',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
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
                                    child: const Text('Lupa Kata Sandi?'),
                                  ),
                                ),
                                const SizedBox(height: 8),
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
                                      : const Icon(Icons.login_rounded),
                                  label: Text(
                                    isLoading ? 'Memproses...' : 'Masuk',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Belum punya akun? '),
                          TextButton(
                            onPressed: isLoading
                                ? null
                                : () => context.go('/register'),
                            child: const Text(
                              'Daftar Sekarang',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const Text('·'),
                          TextButton(
                            onPressed: isLoading
                                ? null
                                : () => context.go('/onboarding'),
                            child: const Text('Info Fitur'),
                          ),
                        ],
                      ),
                      if (FirebaseAppConfig.useEmulator) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.primaryEmerald
                                  .withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.dns_rounded,
                                size: 15,
                                color: AppTheme.primaryEmerald,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Mode Firebase Emulator (${FirebaseAppConfig.emulatorHost}:${FirebaseAppConfig.authEmulatorPort})',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF065F46),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
