import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/patungin_patterns.dart';
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
      'badge': 'Scan Struk & Kurs Otomatis',
      'title': 'Foto struknya,\nbiar kami bacakan.',
      'desc':
          'Ekstrak item pesanan langsung dari struk nongkrong atau liburan luar negeri, lalu konversi otomatis ke Rupiah tanpa hitung manual.',
      'blobBg': AppTheme.sageWash,
      'accent': AppTheme.primaryEmerald,
      'pillA': 'USD → IDR',
      'pillB': 'Smart OCR',
    },
    {
      'icon': Icons.pie_chart_outline_rounded,
      'badge': 'Adil Tanpa Selisih Rp 0',
      'title': 'Bagi sesuai porsi,\nbukan pukul rata.',
      'desc':
          'Cukup tandai siapa pesan apa. Pajak restoran (PB1), biaya layanan, dan diskon promo otomatis terbagi proporsional tanpa selisih.',
      'blobBg': AppTheme.apricotWash,
      'accent': AppTheme.terracotta,
      'pillA': 'PB1 10%',
      'pillB': 'Selisih Rp 0',
    },
    {
      'icon': Icons.notifications_active_outlined,
      'badge': 'Pelunasan Real-Time',
      'title': 'Ingatkan teman\ntanpa rasa canggung.',
      'desc':
          'Pantau siapa yang sudah transfer atau menunggu verifikasi secara langsung, dan kirim pengingat ramah cukup dengan satu ketukan.',
      'blobBg': AppTheme.butterWash,
      'accent': AppTheme.honeyAmber,
      'pillA': 'Lunas!',
      'pillB': 'Nudge Ramah',
    },
  ];

  void _finishOnboarding() {
    context.read<AuthCubit>().completeOnboarding();
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final activeSlide = _slides[_currentPage];
    final activeAccent = activeSlide['accent'] as Color;

    return Scaffold(
      backgroundColor: AppTheme.warmCream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      BagiTigaKanLogo(size: 36),
                      SizedBox(width: 9),
                      BagiTigaKanWordmark(fontSize: 18),
                    ],
                  ),
                  TextButton(
                    onPressed: _finishOnboarding,
                    child: const Text('Lewati'),
                  ),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (idx) => setState(() => _currentPage = idx),
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    final Color blobBg = slide['blobBg'] as Color;
                    final Color accent = slide['accent'] as Color;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Ilustrasi organik berlapis (non-kotak)
                        SizedBox(
                          height: 220,
                          width: 260,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Transform.rotate(
                                angle: index.isEven ? -0.14 : 0.14,
                                child: OrganicPebbleBadge(
                                  size: 180,
                                  color: blobBg,
                                  variant: index,
                                  child: const SizedBox.shrink(),
                                ),
                              ),
                              Container(
                                width: 126,
                                height: 126,
                                decoration: BoxDecoration(
                                  color: AppTheme.paperWhite,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: accent.withValues(alpha: 0.14),
                                      blurRadius: 26,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  slide['icon'] as IconData,
                                  size: 56,
                                  color: accent,
                                ),
                              ),
                              Positioned(
                                top: 20,
                                right: 12,
                                child: Transform.rotate(
                                  angle: 0.08,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.paperWhite,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: accent.withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Text(
                                      slide['pillA'] as String,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: accent,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 18,
                                left: 8,
                                child: Transform.rotate(
                                  angle: -0.07,
                                  child: InkStampBadge(
                                    text: slide['pillB'] as String,
                                    color: accent,
                                    angleRadians: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          (slide['badge'] as String).toUpperCase(),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          slide['title'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 27,
                            height: 1.18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.7,
                            color: AppTheme.darkSlate,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            slide['desc'] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14.5,
                              color: AppTheme.mutedInk,
                              height: 1.55,
                            ),
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
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == i ? 30 : 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: _currentPage == i
                          ? activeAccent
                          : const Color(0xFFD6CEC0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeAccent,
                  ),
                  onPressed: () {
                    if (_currentPage < _slides.length - 1) {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 340),
                        curve: Curves.easeOutCubic,
                      );
                    } else {
                      _finishOnboarding();
                    }
                  },
                  child: Text(
                    _currentPage == _slides.length - 1
                        ? 'Mulai Pakai BagiTigaKan'
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
