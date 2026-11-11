import 'package:flutter/material.dart';
import 'package:staffpro/core/theme/app_colors.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 72,
    this.showWordmark = true,
    this.borderRadius,
  });

  static const assetPath = 'assets/staffpro_logo.png';

  final double size;
  final bool showWordmark;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? size * 0.22;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: AppColors.orangeGlow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Image.asset(
              assetPath,
              width: size,
              height: size,
              filterQuality: FilterQuality.high,
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (showWordmark) ...[
          const SizedBox(height: 10),
          Text(
            'Manage People. Grow Business.',
            style: TextStyle(
              fontSize: size * 0.13,
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: Image.asset(
          BrandLogo.assetPath,
          width: size,
          height: size,
          filterQuality: FilterQuality.high,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

/// Dark glass page backdrop with soft orange / blue glow blobs.
class DecorativeBackground extends StatelessWidget {
  const DecorativeBackground({super.key, required this.child, this.includeSafeArea = false});
  final Widget child;
  final bool includeSafeArea;

  @override
  Widget build(BuildContext context) {
    final content = includeSafeArea ? SafeArea(child: child) : child;
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF07111F),
                  Color(0xFF0A1628),
                  Color(0xFF050B14),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -120,
          left: -80,
          child: _blob(280, AppColors.primary.withValues(alpha: 0.22)),
        ),
        Positioned(
          top: 180,
          right: -100,
          child: _blob(260, AppColors.blue.withValues(alpha: 0.16)),
        ),
        Positioned(
          bottom: -80,
          left: -60,
          child: _blob(220, AppColors.purple.withValues(alpha: 0.10)),
        ),
        Positioned(
          bottom: 120,
          right: -40,
          child: _blob(160, AppColors.primary.withValues(alpha: 0.10)),
        ),
        content,
      ],
    );
  }

  static Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class GlassScaffold extends StatelessWidget {
  const GlassScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.extendBody = false,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool extendBody;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: extendBody,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: DecorativeBackground(child: body),
    );
  }
}
