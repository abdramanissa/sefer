import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'app_shell.dart';

class SeferApp extends StatefulWidget {
  const SeferApp({super.key, required this.state});
  final AppState state;

  @override
  State<SeferApp> createState() => _SeferAppState();
}

class _SeferAppState extends State<SeferApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.detached || s == AppLifecycleState.hidden) {
      widget.state.flush();
    }
  }

  @override
  void didChangePlatformBrightness() => setState(() {});

  @override
  Widget build(BuildContext context) => AppScope(
    state: widget.state,
    child: Builder(
      builder: (context) {
        final app = context.app;
        final s = app.settings;
        Haptic.enabled = s.haptics;
        Motion.forceReduce = s.reduceMotion;
        final platform = View.of(context).platformDispatcher.platformBrightness;
        final palette = app.paletteFor(platform);
        return MaterialApp(
          title: 'Sefer',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(palette),
          themeAnimationDuration: const Duration(milliseconds: 380),
          themeAnimationCurve: Curves.easeOutCubic,
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: _ScaledTextScaler(mq.textScaler, s.uiScale),
              ),
              child: child!,
            );
          },
          home: const AppShell(),
        );
      },
    ),
  );
}

/// The system text scale multiplied by the app's own UI scale setting.
class _ScaledTextScaler extends TextScaler {
  const _ScaledTextScaler(this.base, this.factor);
  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.scale(1) * factor;

  @override
  bool operator ==(Object other) =>
      other is _ScaledTextScaler && other.base == base && other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}
