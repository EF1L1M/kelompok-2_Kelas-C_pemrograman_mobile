import 'package:go_router/go_router.dart';
import '../../features/auth/cubit/auth_cubit.dart';
import '../../features/auth/cubit/auth_state.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/groups/presentation/group_detail_screen.dart';
import '../../features/groups/presentation/home_screen.dart';
import '../../features/settlement/presentation/bill_detail_screen.dart';
import '../../features/settlement/presentation/code_showcase_screen.dart';
import '../../features/settlement/presentation/notification_center_screen.dart';
import '../../features/split_bill/presentation/create_bill_screen.dart';

// ============================================================================
// GO_ROUTER & RBAC AUTH GUARD (BAB 2.5, FR-01, FR-02, UFD-1, BAB 6 ANGGOTA 1)
// Menegakkan otorisasi lapis ke-1 pada sisi Flutter:
// Unauthenticated User hanya dapat mengakses /splash, /onboarding, /login, /register.
// Seluruh route lain dicegah oleh Auth Guard redirect.
// ============================================================================

class AppRouter {
  static GoRouter createRouter(AuthCubit authCubit) {
    const publicRoutes = <String>{
      '/splash',
      '/onboarding',
      '/login',
      '/register',
    };

    return GoRouter(
      initialLocation: '/splash',
      refreshListenable: authCubit,
      redirect: (context, state) {
        final authState = authCubit.state;
        final String location = state.matchedLocation;
        final bool isPublicRoute = publicRoutes.contains(location);

        if (authState is AuthInitial || authState is AuthLoading) {
          return null;
        }

        final bool isAuthenticated = authState is AuthAuthenticated;

        // Auth Guard (Tabel 2.5 & FR-01): Pengguna belum login ditolak membuka route privat
        if (!isAuthenticated && !isPublicRoute) {
          return '/login';
        }

        // Jika sudah login tetapi berada di halaman login/register, arahkan ke /home
        if (isAuthenticated &&
            (location == '/login' || location == '/register')) {
          return '/home';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationCenterScreen(),
        ),
        GoRoute(
          path: '/code-showcase',
          builder: (context, state) => const CodeShowcaseScreen(),
        ),
        GoRoute(
          path: '/groups/:groupId',
          builder: (context, state) {
            final groupId = state.pathParameters['groupId']!;
            return GroupDetailScreen(groupId: groupId);
          },
        ),
        GoRoute(
          path: '/groups/:groupId/create-bill',
          builder: (context, state) {
            final groupId = state.pathParameters['groupId']!;
            final editBillId = state.uri.queryParameters['editBillId'];
            return CreateBillScreen(
              groupId: groupId,
              editBillId: editBillId,
            );
          },
        ),
        GoRoute(
          path: '/groups/:groupId/bills/:billId',
          builder: (context, state) {
            final groupId = state.pathParameters['groupId']!;
            final billId = state.pathParameters['billId']!;
            return BillDetailScreen(
              groupId: groupId,
              billId: billId,
            );
          },
        ),
      ],
    );
  }
}
