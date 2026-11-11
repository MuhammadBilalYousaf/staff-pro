import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:staffpro/core/theme/app_colors.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.prefix,
    this.suffix,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.onChanged,
    this.readOnly = false,
    this.onTap,
    this.textInputAction,
    this.enabled = true,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final IconData? prefix;
  final Widget? suffix;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final VoidCallback? onTap;
  final TextInputAction? textInputAction;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.text,
            fontSize: 13.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          maxLines: maxLines,
          onChanged: onChanged,
          readOnly: readOnly,
          onTap: onTap,
          enabled: enabled,
          style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
          textInputAction: textInputAction ?? TextInputAction.next,
          inputFormatters: keyboardType == TextInputType.number
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
              : null,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefix == null ? null : Icon(prefix, color: AppColors.placeholder, size: 22),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.outlined = false,
    this.destructive = false,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool outlined;
  final bool destructive;
  final IconData? icon;
  final bool expand;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final bg = widget.outlined
        ? AppColors.glassStrong
        : widget.destructive
            ? AppColors.dangerSoft
            : AppColors.primary;
    final fg = widget.outlined
        ? AppColors.primary
        : widget.destructive
            ? AppColors.danger
            : Colors.white;

    final child = AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 90),
      child: SizedBox(
        width: widget.expand ? double.infinity : null,
        height: 54,
        child: ElevatedButton(
          onPressed: enabled ? widget.onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            disabledBackgroundColor: AppColors.navyMuted,
            elevation: widget.outlined || widget.destructive ? 0 : 4,
            shadowColor: AppColors.primary.withValues(alpha: 0.45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: widget.outlined ? const BorderSide(color: AppColors.primary, width: 1.4) : BorderSide.none,
            ),
          ),
          child: widget.loading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: widget.outlined ? AppColors.primary : Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(width: 8),
                    Icon(widget.icon ?? Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
        ),
      ),
    );

    return Listener(
      onPointerDown: enabled ? (_) => setState(() => _scale = 0.97) : null,
      onPointerUp: (_) => setState(() => _scale = 1),
      onPointerCancel: (_) => setState(() => _scale = 1),
      child: child,
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color, this.soft});

  final String label;
  final Color color;
  final Color? soft;

  factory StatusBadge.active(bool isActive) {
    return isActive
        ? const StatusBadge(label: 'Active', color: AppColors.success, soft: AppColors.successSoft)
        : const StatusBadge(label: 'Inactive', color: AppColors.danger, soft: AppColors.dangerSoft);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: soft ?? color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.radius = 24,
    this.border,
    this.shadow = true,
    this.blur = true,
  });

  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;
  final Border? border;
  final bool shadow;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: color ?? AppColors.glass,
      borderRadius: BorderRadius.circular(radius),
      border: border ?? Border.all(color: AppColors.borderGlow, width: 1),
      boxShadow: shadow ? AppColors.softShadow : null,
    );

    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: blur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: double.infinity,
                padding: padding ?? const EdgeInsets.all(16),
                decoration: decoration,
                child: DefaultTextStyle.merge(
                  style: const TextStyle(color: AppColors.text),
                  child: child,
                ),
              ),
            )
          : Container(
              width: double.infinity,
              padding: padding ?? const EdgeInsets.all(16),
              decoration: decoration,
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: AppColors.text),
                child: child,
              ),
            ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class HeroMetricCard extends StatelessWidget {
  const HeroMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.trend,
    this.trendUp,
    this.subtitle,
    this.onTap,
    this.showSparkline = true,
  });

  final String label;
  final String value;
  final String? trend;
  final bool? trendUp;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool showSparkline;

  @override
  Widget build(BuildContext context) {
    final up = trendUp ?? true;
    return AppCard(
      onTap: onTap,
      color: AppColors.glassStrong,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 32, letterSpacing: -0.8)),
          if (trend != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle == null ? trend! : '$trend $subtitle',
              style: TextStyle(
                color: up ? AppColors.success : AppColors.danger,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
          if (showSparkline) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 44,
              width: double.infinity,
              child: CustomPaint(
                painter: _SparklinePainter(
                  color: AppColors.primary,
                  upward: up,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.color, required this.upward});
  final Color color;
  final bool upward;

  @override
  void paint(Canvas canvas, Size size) {
    final points = upward
        ? [0.15, 0.35, 0.28, 0.55, 0.48, 0.72, 0.68, 0.92]
        : [0.85, 0.70, 0.78, 0.55, 0.60, 0.40, 0.45, 0.22];
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = size.width * (i / (points.length - 1));
      final y = size.height * (1 - points[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.4),
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.upward != upward;
}

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.trend,
    this.trendUp,
    this.icon,
    this.iconColor,
    this.trailing,
  });

  final String label;
  final String value;
  final String? trend;
  final bool? trendUp;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final accent = iconColor ?? AppColors.primary;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              ?trailing,
              if (trailing == null && icon != null)
                SoftIconBox(icon: icon!, color: accent, size: 34),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.text)),
          if (trend != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: ((trendUp ?? true) ? AppColors.successSoft : AppColors.dangerSoft),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                trend!,
                style: TextStyle(
                  color: (trendUp ?? true) ? AppColors.success : AppColors.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.title, this.subtitle, this.icon, this.action});

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SoftIconBox(icon: icon ?? Icons.inbox_outlined, color: AppColors.primary, size: 72),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyView(
      title: 'Something went wrong',
      subtitle: message,
      icon: Icons.error_outline,
      action: onRetry == null ? null : TextButton(onPressed: onRetry, child: const Text('Retry')),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = 'Loading...'});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}

class PeriodChips extends StatelessWidget {
  const PeriodChips({
    super.key,
    required this.value,
    required this.onChanged,
    this.showCustom = true,
    this.extended = true,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool showCustom;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final items = [
      'Today',
      if (extended) 'Yesterday',
      'This Week',
      if (extended) 'Last Week',
      'This Month',
      if (showCustom) 'Custom',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((e) {
          final selected = e == value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(e),
              selected: selected,
              onSelected: (_) => onChanged(e),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.text,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              backgroundColor: AppColors.glass,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class FilterChips extends StatelessWidget {
  const FilterChips({super.key, required this.items, required this.value, required this.onChanged});

  final List<String> items;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((e) {
          final selected = e == value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(e),
              selected: selected,
              onSelected: (_) => onChanged(e),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.text,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              backgroundColor: AppColors.glass,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.controller, this.hint = 'Search', this.onChanged});
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: AppColors.text),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.placeholder),
        filled: true,
        fillColor: AppColors.glassStrong,
      ),
    );
  }
}

class MenuTile extends StatelessWidget {
  const MenuTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.color,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: SoftIconBox(icon: icon, color: c, size: 44),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.placeholder),
    );
  }
}

class SoftIconBox extends StatelessWidget {
  const SoftIconBox({super.key, required this.icon, this.color = AppColors.primary, this.size = 44});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Icon(icon, color: color, size: size * 0.45),
    );
  }
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel, style: TextStyle(color: destructive ? AppColors.danger : AppColors.primary)),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.danger : AppColors.navyMuted,
    ),
  );
}
