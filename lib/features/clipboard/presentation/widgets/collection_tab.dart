import 'package:flutter/material.dart';

import '../../../../app/tokens.dart';

/// One segment of the collection switcher (Clipboard, Snippets, pinboards).
class CollectionTab extends StatelessWidget {
  const CollectionTab({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.section,
    required this.onSelected,
  });
  final String value, label, section;
  final IconData icon;

  /// Board dot colour; null for the built-in collections, which show [icon].
  final Color? color;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.shelf;
    final selected = section == value;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: selected ? colors.surfaceRaised : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: colors.shadow,
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: TextButton.icon(
        onPressed: () => onSelected(value),
        style: TextButton.styleFrom(
          foregroundColor: selected ? colors.textPrimary : colors.textSecondary,
          overlayColor: colors.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 28),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: color == null
            ? Icon(icon, size: 15)
            : Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
        label: Text(
          label,
          style: TextStyle(
            fontSize: ShelfType.meta,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
