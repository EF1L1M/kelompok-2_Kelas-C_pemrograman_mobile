import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../cubit/auth_cubit.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  static const List<Map<String, dynamic>> _slides = [
    {
      'icon': Icons.document_scanner_rounded,
      'badge': 'Scan Struk & Multi-Mata Uang',
      'title': 'Pindai Struk & Konversi Kurs Otomatis',
      'desc':
          'Ekstrak rincian belanja langsung dari struk dan konversi tagihan mata uang asing (USD, SGD, EUR, JPY, MYR) ke Rupiah secara otomatis.',
    },
    {
      'icon': Icons.calculate_rounded,
      'badge': 'Akurasi Tanpa Selisih',
      'title': 'Pembagian Proporsional Otomatis',
      'desc':
          'Pilih anggota untuk setiap pesanan. Pajak restoran (PB1), biaya layanan, dan diskon dibagi secara adil dan proporsional tanpa selisih pembulatan.',
    },
    {
      'icon': Icons.notifications_active_rounded,
      'badge': 'Pelunasan Real-Time',
      'title': 'Pantau Pelunasan & Kirim Pengingat',
      'desc':
          'Lacak siapa yang sudah membayar atau menunggu verifikasi secara langsung, serta kirim pengingat pembayaran ramah hanya dengan satu ketukan.',
    },
  ];

  void _finishOnboarding() {
    context.read<AuthCubit>().completeOnboarding();
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: _finishOnboarding,
            child: const Text('Lewati'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (idx) => setState(() => _currentPage = idx),
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryEmerald.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            slide['icon'] as IconData,
                            size: 54,
                            color: AppTheme.primaryEmerald,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            slide['badge'] as String,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryEmerald,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          slide['title'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkSlate,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide['desc'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF475569),
                            height: 1.5,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == i ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == i
                          ? AppTheme.primaryEmerald
                          : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _slides.length - 1) {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    } else {
                      _finishOnboarding();
                    }
                  },
                  child: Text(
                    _currentPage == _slides.length - 1
                        ? 'Mulai Sekarang'
                        : 'Lanjut',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
