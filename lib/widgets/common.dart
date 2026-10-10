import 'package:flutter/material.dart';

import '../theme.dart';
import 'app_header.dart';

/// Cream page with soft warm glows and the app header on top.
class PageShell extends StatelessWidget {
  final Widget child;
  final bool showHeader;
  const PageShell({super.key, required this.child, this.showHeader = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.cream,
      body: Stack(
        children: [
          Positioned(
            top: 120,
            right: -140,
            child: IgnorePointer(child: _glow(C.gold.withOpacity(0.25), 380)),
          ),
          Positioned(
            bottom: -120,
            left: -120,
            child: IgnorePointer(child: _glow(C.orange.withOpacity(0.15), 320)),
          ),
          SafeArea(
            child: Column(
              children: [
                if (showHeader) const AppHeader(),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
        ),
      );
}

/// Scrollable area that vertically centres its child when there is spare room.
class ScrollCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ScrollCenter({super.key, required this.child, this.maxWidth = 440});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight - 24),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class GoldCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const GoldCard({super.key, required this.child, this.padding = const EdgeInsets.all(24)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: C.gold.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: C.maroon.withOpacity(0.16),
            blurRadius: 40,
            offset: const Offset(0, 16),
            spreadRadius: -16,
          ),
        ],
      ),
      child: child,
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final Color color;
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.color = C.maroon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: C.cream,
          disabledBackgroundColor: color.withOpacity(0.55),
          disabledForegroundColor: C.cream.withOpacity(0.8),
          padding: const EdgeInsets.symmetric(vertical: 15),
          elevation: 6,
          shadowColor: color.withOpacity(0.5),
          shape: StadiumBorder(
            side: BorderSide(color: color == C.maroon ? C.gold.withOpacity(0.6) : Colors.transparent),
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: C.cream),
              )
            : Text(label,
                textAlign: TextAlign.center,
                style: body(16, color: C.cream, weight: FontWeight.w600)),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const SecondaryButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.7),
          foregroundColor: C.maroon,
          padding: const EdgeInsets.symmetric(vertical: 13),
          side: const BorderSide(color: C.gold, width: 1.5),
          shape: const StadiumBorder(),
        ),
        child: Text(label, textAlign: TextAlign.center, style: body(14, weight: FontWeight.w600)),
      ),
    );
  }
}

InputDecoration inputDeco({String? hint, Widget? suffix, EdgeInsets? padding}) {
  OutlineInputBorder b(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: 2),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: body(16, color: const Color(0xFFD4D4D4)),
    filled: true,
    fillColor: Colors.white,
    suffixIcon: suffix,
    contentPadding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    enabledBorder: b(C.neutral200),
    disabledBorder: b(C.neutral200),
    focusedBorder: b(C.gold),
  );
}

class ErrorBox extends StatelessWidget {
  final String message;
  const ErrorBox(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        border: Border.all(color: const Color(0xFFFECACA)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: body(13, color: const Color(0xFFB91C1C))),
    );
  }
}

class Skeleton extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const Skeleton({super.key, this.width, this.height = 20, this.radius = 8});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: C.neutral200.withOpacity(0.7),
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

void goHome(BuildContext context) =>
    Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
