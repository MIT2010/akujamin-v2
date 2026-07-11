import 'package:authentication/authentication.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_about/feature_about.dart';
import 'package:feature_counseling/feature_counseling.dart';
import 'package:feature_history/feature_history.dart';
import 'package:feature_home/feature_home.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:feature_payment/feature_payment.dart';
import 'package:feature_profile/feature_profile.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

/// The composition root's widget (§13, §17): wires `AppRouter` (from
/// `shared`) into `MaterialApp.router`, themed from `design_system`.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final appRouter = getIt<AppRouter>()..standaloneRoutes = _routes;

    return MaterialApp.router(
      title: 'Flutter Starter Kit',
      routerConfig: appRouter.router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
    );
  }
}

final _routes = <RouteBase>[
  GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
  GoRoute(path: '/home', builder: (context, state) => const HomePage()),
  GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),
  GoRoute(path: '/about', builder: (context, state) => const AboutPage()),
  GoRoute(
    path: '/onboarding',
    builder: (context, state) => const OnboardingPage(),
  ),
  GoRoute(path: '/history', builder: (context, state) => const HistoryPage()),
  GoRoute(
    path: '/certificate',
    builder: (context, state) => const CertificatePage(),
  ),
  GoRoute(
    path: '/counseling',
    builder: (context, state) => const CounselingListPage(),
  ),
  GoRoute(path: '/chat/:code', builder: (context, state) => const ChatPage()),
  GoRoute(path: '/payment', builder: (context, state) => const PaymentPage()),
];
