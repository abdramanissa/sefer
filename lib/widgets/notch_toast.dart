import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../theme/app_theme.dart';
import 'ui_kit.dart';

/// The app's feedback channel (DESIGN.md §7.6): a black pill that drips out
/// of the top of the screen, grows, and slips back. Always black, whatever
/// the theme, like a hardware "dynamic island".
///
/// Toasts queue; a new one waits for the current one to leave.
void showNotchToast(
  BuildContext context, {
  required String title,
  String? subtitle,
  IconData? icon,
  Color accent = const Color(0xFF8FA377),
  String? action,
  VoidCallback? onAction,
  Duration? duration,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final words = '$title ${subtitle ?? ''}'.trim().split(RegExp(r'\s+')).length;
  final d = duration ?? Duration(milliseconds: (900 + 330 * words).clamp(2200, 6000));
  _queue.add(_Toast(title, subtitle, icon, accent, action, onAction, d));
  SemanticsService.sendAnnouncement(
    View.of(context),
    subtitle == null ? title : '$title. $subtitle',
    Directionality.of(context),
  );
  if (!_showing) _next(overlay);
}

class _Toast {
  _Toast(this.title, this.subtitle, this.icon, this.accent, this.action, this.onAction, this.duration);
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color accent;
  final String? action;
  final VoidCallback? onAction;
  final Duration duration;
}

final List<_Toast> _queue = [];
bool _showing = false;

void _next(OverlayState overlay) {
  if (_queue.isEmpty || !overlay.mounted) {
    _showing = false;
    return;
  }
  _showing = true;
  final toast = _queue.removeAt(0);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _NotchToast(
      toast: toast,
      onDone: () {
        entry.remove();
        _next(overlay);
      },
    ),
  );
  overlay.insert(entry);
}

class _NotchToast extends StatefulWidget {
  const _NotchToast({required this.toast, required this.onDone});
  final _Toast toast;
  final VoidCallback onDone;

  @override
  State<_NotchToast> createState() => _NotchToastState();
}

class _NotchToastState extends State<_NotchToast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
    reverseDuration: const Duration(milliseconds: 450),
  );
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.status != AnimationStatus.dismissed) return;
    if (Motion.reduced(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
    _timer = Timer(widget.toast.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    _timer?.cancel();
    if (!mounted) return;
    if (Motion.reduced(context)) {
      _c.value = 0;
    } else {
      await _c.reverse();
    }
    widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.toast;
    final top = MediaQuery.viewPaddingOf(context).top;
    final screenW = MediaQuery.sizeOf(context).width;
    final fullW = (307 * screenW / 390).clamp(260.0, 420.0);
    const fullH = 58.0;
    const startW = 126.0;
    const startH = 34.0;
    return Positioned(
      top: top > 0 ? top * 0.25 : 8,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = _c.value;
          // Drip: first stretch down, then swell out to the full pill.
          final grow = Curves.easeOutBack.transform((v * 1.25 - 0.25).clamp(0.0, 1.0));
          final drop = Curves.easeOutCubic.transform((v * 2).clamp(0.0, 1.0));
          final w = lerpDouble(startW, fullW, grow)!;
          final h = lerpDouble(startH, fullH, grow.clamp(0.0, 1.2))!;
          final dy = lerpDouble(-startH, top > 0 ? 6 : 12, drop)!;
          final content = ((v - 0.55) / 0.45).clamp(0.0, 1.0);
          return Transform.translate(
            offset: Offset(0, dy),
            child: Center(
              child: GestureDetector(
                onTap: _dismiss,
                onVerticalDragEnd: (_) => _dismiss(),
                child: Container(
                  width: w,
                  height: h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(h / 2),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF000000), Color(0xFF0B0B0B)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35 * drop),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: content == 0
                      ? null
                      : Opacity(
                          opacity: content,
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: 3 * (1 - content), sigmaY: 3 * (1 - content)),
                            child: _body(t),
                          ),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _body(_Toast t) => ClipRRect(
    borderRadius: BorderRadius.circular(29),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(color: t.accent.withValues(alpha: 0.18), shape: BoxShape.circle),
            child: Icon(t.icon ?? Icons.check_rounded, size: 17, color: t.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.f(14, weight: FontWeight.w800, color: Colors.white),
                ),
                if (t.subtitle != null)
                  Text(
                    t.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.f(11.5, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.6)),
                  ),
              ],
            ),
          ),
          if (t.action != null)
            GestureDetector(
              onTap: () {
                t.onAction?.call();
                _dismiss();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Text(t.action!, style: AppTheme.f(13, weight: FontWeight.w800, color: t.accent)),
              ),
            ),
        ],
      ),
    ),
  );
}
