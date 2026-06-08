import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'shared/providers.dart';
import 'shared/services/auth_service.dart';
import 'shared/services/supabase_service.dart';
import 'bottom_nav.dart';
import 'features/startup/startup_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  runApp(const ProviderScope(child: FidusApp()));
}

class FidusApp extends ConsumerWidget {
  const FidusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Fidus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();

  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate> {
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (!AuthService.isSignedIn) {
      await AuthService.signUpAuto();
    }
    if (mounted) setState(() => _initializing = false);
  }

  @override
  Widget build(BuildContext context) {
    final dataReady = !_initializing && ref.watch(initialDataReadyProvider);
    return StartupGate(
      isReady: dataReady,
      timeoutEnabled: !_initializing,
      child: _initializing
          ? const ColoredBox(color: AppColors.darkBackground)
          : const BottomNav(),
    );
  }
}
