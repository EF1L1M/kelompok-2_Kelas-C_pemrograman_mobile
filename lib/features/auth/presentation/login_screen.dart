import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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
  final _emailController = TextEditingController(text: 'andi@mahasiswa.ac.id');
  final _passwordController = TextEditingController(text: '123456');
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthCubit>().signInWithEmail(
            email: _emailController.text,
            password: _passwordController.text,
          );
    }
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
                  constraints: const BoxConstraints(maxWidth: 460),
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
                                  'Smart Split-Bill & Budget',
                                  style: TextStyle(
                                    fontSize: 21,
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
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Masuk ke Akun Anda',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: validateEmail,
                                  decoration: const InputDecoration(
                                    labelText: 'Alamat Email',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
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
                                const SizedBox(height: 20),
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
                                    isLoading
                                        ? 'Memproses...'
                                        : 'Masuk',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: isLoading
                                      ? null
                                      : () => context
                                          .read<AuthCubit>()
                                          .signInWithGoogle(),
                                  icon: const Icon(
                                    Icons.g_mobiledata_rounded,
                                    size: 26,
                                  ),
                                  label: const Text('Lanjutkan dengan Google'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.switch_account_rounded,
                                  size: 18,
                                  color: AppTheme.primaryEmerald,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Masuk Cepat Akun Tersimpan',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppTheme.darkSlate,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _SavedAccountChip(
                                  label: 'Andi Pratama',
                                  subtitle: 'andi@mahasiswa.ac.id',
                                  onTap: () {
                                    _emailController.text =
                                        'andi@mahasiswa.ac.id';
                                    _passwordController.text = '123456';
                                    _submitLogin();
                                  },
                                ),
                                _SavedAccountChip(
                                  label: 'Budi Santoso',
                                  subtitle: 'budi@mahasiswa.ac.id',
                                  onTap: () {
                                    _emailController.text =
                                        'budi@mahasiswa.ac.id';
                                    _passwordController.text = '123456';
                                    _submitLogin();
                                  },
                                ),
                                _SavedAccountChip(
                                  label: 'Citra Lestari',
                                  subtitle: 'citra@mahasiswa.ac.id',
                                  onTap: () {
                                    _emailController.text =
                                        'citra@mahasiswa.ac.id';
                                    _passwordController.text = '123456';
                                    _submitLogin();
                                  },
                                ),
                                _SavedAccountChip(
                                  label: 'Doni Kusuma',
                                  subtitle: 'doni@luar.ac.id',
                                  onTap: () {
                                    _emailController.text = 'doni@luar.ac.id';
                                    _passwordController.text = '123456';
                                    _submitLogin();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Belum punya akun? '),
                          TextButton(
                            onPressed: () => context.go('/register'),
                            child: const Text(
                              'Daftar Sekarang',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const Text('·'),
                          TextButton(
                            onPressed: () => context.go('/onboarding'),
                            child: const Text('Info Fitur'),
                          ),
                        ],
                      ),
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

class _SavedAccountChip extends StatelessWidget {
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _SavedAccountChip({
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(
        Icons.account_circle_outlined,
        size: 17,
        color: AppTheme.primaryEmerald,
      ),
      label: Text(
        '$label ($subtitle)',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      onPressed: onTap,
      backgroundColor: Colors.white,
    );
  }
}
