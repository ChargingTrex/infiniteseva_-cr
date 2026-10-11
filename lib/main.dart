import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'pages/admin_ads_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/participate_page.dart';
import 'pages/signup_page.dart';
import 'services/app_state.dart';
import 'services/offline_queue.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  await AppState.instance.load();
  try {
    await RecitationQueue.instance.init();
  } catch (_) {
    // Offline saving unavailable; the app still works online.
  }
  runApp(const InfiniteSevaApp());
}

class InfiniteSevaApp extends StatelessWidget {
  const InfiniteSevaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: AppState.instance,
      child: MaterialApp(
        title: 'Infinite Seva',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        initialRoute: '/',
        routes: {
          '/': (_) => const HomePage(),
          '/login': (_) => const LoginPage(),
          '/signup': (_) => const SignupPage(),
          '/participate': (_) => const ParticipatePage(),
          '/dashboard': (_) => const DashboardPage(),
          '/admin/ads': (_) => const AdminAdsPage(),
        },
      ),
    );
  }
}
