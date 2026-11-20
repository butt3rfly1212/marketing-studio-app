import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import 'dashboard_page.dart';
import 'firebase_options.dart';
import 'login_page.dart';
import 'operation/metrics.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 대시보드와 같은 파이어베이스 프로젝트(ai-marketing-66997)에 연결한다.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kIsWeb) {
    // 웹 대시보드처럼 로그인은 이 탭에서만 유지한다(공용 PC에 로그인이 남지 않게).
    await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
  }
  // Operation 채널 성과: channel_metrics 공개 읽기(publishable 키는 공개용이라 앱에 넣어도 된다).
  await Supabase.initialize(url: MetricsSource.url, publishableKey: MetricsSource.publishableKey);
  runApp(const StudioApp());
}

class StudioApp extends StatefulWidget {
  const StudioApp({super.key});

  @override
  State<StudioApp> createState() => _StudioAppState();
}

class _StudioAppState extends State<StudioApp> {
  ThemeMode _mode = ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marketing Studio',
      debugShowCheckedModeBanner: false,
      theme: studioTheme(Brightness.light),
      darkTheme: studioTheme(),
      themeMode: _mode,
      home: AuthGate(
        onToggleTheme: () => setState(() {
          _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
        }),
      ),
    );
  }
}

/// 로그인 상태에 따라 로그인 화면과 대시보드를 바꿔 보여 준다.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, this.onToggleTheme});

  final VoidCallback? onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: Text('로그인 상태를 확인하고 있습니다.')));
        }
        final user = snapshot.data;
        return user == null ? const LoginPage() : DashboardPage(user: user, onToggleTheme: onToggleTheme);
      },
    );
  }
}
