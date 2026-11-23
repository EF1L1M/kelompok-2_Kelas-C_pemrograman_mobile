import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'core/firebase/firebase_config.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/cubit/auth_cubit.dart';
import 'features/auth/cubit/auth_state.dart';
import 'features/groups/cubit/group_cubit.dart';
import 'repositories/auth_repository.dart';
import 'repositories/bill_settlement_repository.dart';
import 'repositories/group_repository.dart';
import 'repositories/open_source_api_repository.dart';

// ============================================================================
// ENTRY POINT APLIKASI PATUNGIN (SMART SPLIT-BILL & BUDGET)
// Mata Kuliah: Pemrograman Mobile (Dart & Flutter SDK)
// Mengintegrasikan Firebase Auth & Cloud Firestore (Local Emulator Suite / Cloud),
// BLoC/Cubit State Management, GoRouter Auth Guard, Open-Source API, dan Notifikasi.
// ============================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inisialisasi Firebase & sambungkan ke Local Emulator Suite (tahap awal)
  await FirebaseAppConfig.initialize();

  // 2. Inisialisasi Push Notifications (Foreground, Background, Terminated)
  await NotificationService.instance.initialize();

  // 3. Muat preferensi onboarding lokal sebelum merender aplikasi
  final authRepository = AuthRepository();
  await authRepository.loadPreferences();

  runApp(SmartSplitBillApp(authRepository: authRepository));
}

class SmartSplitBillApp extends StatefulWidget {
  final AuthRepository authRepository;

  const SmartSplitBillApp({
    super.key,
    required this.authRepository,
  });

  @override
  State<SmartSplitBillApp> createState() => _SmartSplitBillAppState();
}

class _SmartSplitBillAppState extends State<SmartSplitBillApp> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  late final AuthRepository _authRepository;
  late final GroupRepository _groupRepository;
  late final OpenSourceApiRepository _apiRepository;
  late final BillSettlementRepository _settlementRepository;

  late final AuthCubit _authCubit;
  late final GroupCubit _groupCubit;
  late final GoRouter _router;
  StreamSubscription<AuthState>? _authStateSub;
  StreamSubscription<NotificationTapPayload>? _notifTapSub;
  StreamSubscription<LocalPushBannerEvent>? _pushBannerSub;

  @override
  void initState() {
    super.initState();
    _authRepository = widget.authRepository;
    _groupRepository = GroupRepository();
    _apiRepository = OpenSourceApiRepository();
    _settlementRepository = BillSettlementRepository();

    _authCubit = AuthCubit(_authRepository);
    _groupCubit = GroupCubit(
      groupRepository: _groupRepository,
      settlementRepository: _settlementRepository,
    );

    // Sinkronkan GroupCubit saat pengguna login/keluar
    final initialUser = _authRepository.currentUser;
    _groupCubit.bindUser(initialUser?.uid);
    _authStateSub = _authCubit.stream.listen((state) {
      if (state is AuthAuthenticated) {
        _groupCubit.bindUser(state.user.uid);
      } else if (state is AuthUnauthenticated) {
        _groupCubit.bindUser(null);
      }
    });

    _router = AppRouter.createRouter(_authCubit);

    // FR-06: Ketukan pada Push Notification langsung membuka halaman Bill Detail
    _notifTapSub = NotificationService.instance.onNotificationTap.listen(
      (payload) {
        if (payload.groupId.isNotEmpty && payload.billId.isNotEmpty) {
          _router.push('/groups/${payload.groupId}/bills/${payload.billId}');
        }
      },
    );

    // Tampilkan banner Push Notification interaktif saat event lokal terpancar
    _pushBannerSub = NotificationService.instance.onPushBanner.listen(
      (event) {
        final messenger = _scaffoldMessengerKey.currentState;
        if (messenger == null) return;
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            backgroundColor: AppTheme.darkSlate,
            behavior: SnackBarBehavior.floating,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Color(0xFF34D399),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'BUKA TAGIHAN',
              textColor: const Color(0xFF34D399),
              onPressed: () {
                NotificationService.instance.triggerNotificationTap(
                  event.payload,
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _authStateSub?.cancel();
    _notifTapSub?.cancel();
    _pushBannerSub?.cancel();
    _authCubit.close();
    _groupCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: _authRepository),
        RepositoryProvider.value(value: _groupRepository),
        RepositoryProvider.value(value: _apiRepository),
        RepositoryProvider.value(value: _settlementRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _authCubit),
          BlocProvider.value(value: _groupCubit),
        ],
        child: MaterialApp.router(
          title: 'Patungin',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: _scaffoldMessengerKey,
          theme: AppTheme.lightTheme,
          routerConfig: _router,
        ),
      ),
    );
  }
}
