/// Smooth right-to-left slide transition used app-wide.
///
/// • New page slides in from the right with a fast-then-decelerate curve.
/// • Old page slides slightly to the left (parallax, 30 % of width).
/// • Both motions run simultaneously for a fluid, native-app feel.
///
/// Usage:
///   Navigator.push(context, SlidePage(builder: (_) => SomePage()));
library;

import 'package:flutter/material.dart';

// ── Re-usable PageRoute ────────────────────────────────────────────────────

class SlidePage<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  SlidePage({required this.builder, super.settings})
      : super(
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: smoothSlideTransition,
        );
}

// ── Shared transition function ─────────────────────────────────────────────

/// Can be used directly in [PageRouteBuilder.transitionsBuilder] or via the
/// [SmoothSlideTransitionsBuilder] theme builder below.
Widget smoothSlideTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  // Incoming page: slide from right → centre
  final incoming = Tween<Offset>(
    begin: const Offset(1.0, 0.0),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: animation,
    curve:        Curves.fastEaseInToSlowEaseOut,
    reverseCurve: Curves.fastEaseInToSlowEaseOut.flipped,
  ));

  // Outgoing page: slides 30 % to the left (parallax)
  final outgoing = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(-0.30, 0.0),
  ).animate(CurvedAnimation(
    parent: secondaryAnimation,
    curve:        Curves.fastEaseInToSlowEaseOut,
    reverseCurve: Curves.fastEaseInToSlowEaseOut.flipped,
  ));

  return SlideTransition(
    position: outgoing,
    child: SlideTransition(
      position: incoming,
      child: child,
    ),
  );
}

// ── Theme-level builder (applied to every MaterialPageRoute) ───────────────

class SmoothSlideTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothSlideTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      smoothSlideTransition(context, animation, secondaryAnimation, child);
}
