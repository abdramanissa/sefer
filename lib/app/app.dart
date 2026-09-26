import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/feel.dart';
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

  // Building ThemeData is cheap, but a new instance makes every widget that
  // reads the theme rebuild. Most state changes (a word tapped, a tick of
  // reading time) don't touch the theme, so keep the same instance until one
  // of its inputs changes.
  String? _themeKey;
  ThemeData? _theme;

  ThemeData _themeFor(AppState app, Brightness platform) {
    final s = app.settings;
    var palette = app.paletteFor(platform);
    final accent = hexToColor(s.accentHex);
    final key = [
      s.themeMode,
      s.customThemeId,
      palette.brightness,
      for (final c in palette.editable.values) c.toARGB32(),
      s.accentHex,
      s.uiFont,
    ].join('|');
    if (key == _themeKey && _theme != null) return _theme!;
    if (accent != null) {
      palette = SeferColors.fromBase(palette.brightness, {...palette.editable, 'accent': accent});
    }
    AppTheme.uiFamily = uiFontFamily(s.uiFont);
    _themeKey = key;
    return _theme = AppTheme.build(palette);
  }

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
        return MaterialApp(
          title: 'Sefer',
          debugShowCheckedModeBanner: false,
          theme: _themeFor(app, platform),
          themeAnimationDuration: const Duration(milliseconds: 380),
          themeAnimationCurve: Curves.easeOutCubic,
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: _ScaledTextScaler(mq.textScaler, s.uiScale),
              ),
              child: FeelScope(feel: Feel.byId(s.feel), roundness: s.roundness, child: child!),
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
