import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/form_validator_mixin.dart';
import '../../../core/widgets/patungin_patterns.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with FormValidatorMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submitRegister() {
    if (_formKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      context.read<AuthCubit>().registerWithEmail(
            fullName: _nameController.text,
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
                OrganicWaveHeader(
                  gradientColors: const [Color(0xFF1D4D3D), Color(0xFF2B7A60)],
                  waveDepth: 30,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    MediaQuery.of(context).padding.top + 14,
                    20,
                    46,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: AppTheme.warmCream
                                      .withValues(alpha: 0.14),
                                  foregroundColor: AppTheme.warmCream,
                                ),
                                icon: const Icon(Icons.arrow_back_rounded),
                                onPressed: () => context.go('/login'),
                              ),
                              const Spacer(),
                              const BagiTigaKanLogo(
                                size: 36,
                                showSubtleBorder: true,
                              ),
                              const SizedBox(width: 8),
                              const BagiTigaKanWordmark(
                                fontSize: 17,
                                onDark: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Yuk bikin akun\nBagiTigaKan dulu.',
                            style: TextStyle(
                              color: AppTheme.warmCream,
                              fontSize: 26,
                              height: 1.2,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Biar kamu bisa bikin grup patungan atau langsung gabung pakai kode temanmu.',
                            style: TextStyle(
                              color: AppTheme.warmCream.withValues(alpha: 0.84),
                              fontSize: 13.5,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 34),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Nama Lengkap',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkSlate,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.name],
                              validator: validateFullName,
                              decoration: const InputDecoration(
                                hintText: 'Contoh: Budi Santoso',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Alamat Email',
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
                            const SizedBox(height: 16),
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
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newPassword],
                              validator: validatePassword,
                              decoration: InputDecoration(
                                hintText: 'Minimal 6 karakter',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
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
                            const SizedBox(height: 16),
                            const Text(
                              'Konfirmasi Kata Sandi',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkSlate,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submitRegister(),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Konfirmasi kata sandi wajib diisi';
                                }
                                if (value != _passwordController.text) {
                                  return 'Konfirmasi kata sandi tidak cocok';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                hintText: 'Ulangi kata sandi',
                                prefixIcon: const Icon(Icons.lock_reset_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscureConfirmPassword =
                                        !_obscureConfirmPassword,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 26),
                            ElevatedButton.icon(
                              onPressed: isLoading ? null : _submitRegister,
                              icon: isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.person_add_alt_1_rounded),
                              label: Text(
                                isLoading
                                    ? 'Mendaftarkan Akun...'
                                    : 'Daftar & Mulai Patungan',
                              ),
                            ),
                            const SizedBox(height: 20),
                            const DashedDivider(),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Sudah punya akun? ',
                                  style: TextStyle(color: AppTheme.mutedInk),
                                ),
                                TextButton(
                                  onPressed: isLoading
                                      ? null
                                      : () => context.go('/login'),
                                  child: const Text('Masuk di sini'),
                                ),
                              ],
                            ),
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
