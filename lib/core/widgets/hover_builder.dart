import 'package:flutter/material.dart';

import 'package:codegraph/core/theme/app_colors.dart';

class HoverBuilder extends StatefulWidget {
  const HoverBuilder({
    super.key,
    required this.builder,
    this.cursor = SystemMouseCursors.basic,
    this.onEnter,
    this.onExit,
  });

  final Widget Function(BuildContext context, bool hovered) builder;
  final MouseCursor cursor;
  final VoidCallback? onEnter;
  final VoidCallback? onExit;

  @override
  State<HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
    if (value) {
      widget.onEnter?.call();
    } else {
      widget.onExit?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: widget.builder(context, _hovered),
    );
  }
}

class HoverSurface extends StatelessWidget {
  const HoverSurface({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(12),
    this.radius = 12,
    this.selected = false,
    this.accent = AppColors.primary,
    this.tooltip,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool selected;
  final Color accent;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      builder: (context, hovered) {
        final surface = AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: padding,
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.10)
                : hovered
                ? AppColors.surfaceRaised
                : Colors.transparent,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.45)
                  : hovered
                  ? AppColors.borderStrong
                  : Colors.transparent,
            ),
          ),
          child: child,
        );
        return tooltip == null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(radius),
                child: surface,
              )
            : Tooltip(
                message: tooltip!,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(radius),
                  child: surface,
                ),
              );
      },
    );
  }
}
