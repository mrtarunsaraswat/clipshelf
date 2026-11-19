import 'package:flutter/material.dart';

import '../tokens.dart';

/// Rounded surface that animates hover and selection, and reports hover to
/// [builder] so children can reveal secondary controls.
class HoverSurface extends StatefulWidget {
  const HoverSurface({
    super.key,
    required this.builder,
    this.selected = false,
    this.radius = ShelfRadius.md,
    this.color,
    this.hoverColor,
    this.selectedColor,
    this.border = false,
    this.lift = false,
    this.padding = EdgeInsets.zero,
  });

  final Widget Function(BuildContext context, bool hovered) builder;
  final bool selected, border, lift;
  final double radius;
  final Color? color, hoverColor, selectedColor;
  final EdgeInsetsGeometry padding;

  @override
  State<HoverSurface> createState() => _HoverSurfaceState();
}

class _HoverSurfaceState extends State<HoverSurface> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.shelf;
    final base = widget.color ?? Colors.transparent;
    final fill = widget.selected
        ? (widget.selectedColor ?? colors.surfaceSelected)
        : _hovered
        ? (widget.hoverColor ?? Color.alphaBlend(colors.surfaceHover, base))
        : base;
    final raised = widget.lift && (_hovered || widget.selected);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(widget.radius),
          border: widget.border || widget.selected
              ? Border.all(
                  color: widget.selected ? colors.accent : colors.stroke,
                  width: widget.selected ? 2 : 1,
                )
              : null,
          boxShadow: [
            if (widget.lift)
              BoxShadow(
                color: colors.shadow,
                blurRadius: raised ? 18 : 6,
                offset: Offset(0, raised ? 6 : 2),
              ),
            if (widget.selected && widget.lift)
              BoxShadow(
                color: colors.accent.withValues(alpha: 0.25),
                blurRadius: 14,
              ),
          ],
        ),
        child: widget.builder(context, _hovered),
      ),
    );
  }
}
