import 'package:flutter/material.dart';

import '../tokens.dart';

/// Dialog header: a gradient icon tile beside a left-aligned title and
/// subtitle, over a faint wash of [tint].
class ShelfDialogHeader extends StatelessWidget {
  const ShelfDialogHeader({
    super.key,
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final Color tint;
  final String title, subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.shelf;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tint.withValues(alpha: 0.13), tint.withValues(alpha: 0)],
        ),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(tint, Colors.white, 0.18)!, tint],
              ),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: tint.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 22, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: ShelfType.heading,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: ShelfType.meta + 0.5,
                    height: 1.35,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small label above a field, with optional trailing text (e.g. "Optional").
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.shelf;
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: ShelfType.meta,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// Field look for dialogs: placeholder inside, no built-in counter.
InputDecoration dialogFieldDecoration(BuildContext context, String hint) =>
    InputDecoration(
      hintText: hint,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      hintStyle: TextStyle(
        fontSize: ShelfType.body,
        color: context.shelf.textTertiary,
      ),
    );

/// Keycap tinted for a filled (accent) button, e.g. "⌘↩" on Save.
class OnFilledKeycap extends StatelessWidget {
  const OnFilledKeycap({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final foreground = DefaultTextStyle.of(context).style.color ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          color: foreground.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}
