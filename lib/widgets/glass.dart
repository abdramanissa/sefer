import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Frosted surface (DESIGN.md §5.2): blur, a tint, a top-lit sheen and a
/// hairline rim.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 28,
    this.sigma = 22,
    this.shadow = true,
  });

  final Widget child;
  final double radius;
  final double sigma;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final dark = c.isDark;
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: shadow
            ? [BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.3 : 0.08), blurRadius: 32, offset: const Offset(0, 12))]
            : null,
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: r,
              color: c.bgRaised.withValues(alpha: dark ? 0.66 : 0.74),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.6],
                colors: [
                  Colors.white.withValues(alpha: dark ? 0.07 : 0.30),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: dark ? 0.08 : 0.5), width: 0.8),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
