import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'core/services/data_saver_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/services/supabase_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/role_gate.dart';
import 'features/auth/auth_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await Hive.initFlutter();
  await Hive.openBox('envol_cache');
  await DataSaverService.initialize();
  await Firebase.initializeApp();

  await SupabaseService.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const EnvolApp());
}

class EnvolApp extends StatelessWidget {
  const EnvolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Envol',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: SupabaseService.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final isLoggedIn = SupabaseService.isLoggedIn;
        if (isLoggedIn) {
          PushNotificationService.initialize();
        }
        return isLoggedIn ? const RoleGate() : const AuthScreen();
      },
    );
  }
}
