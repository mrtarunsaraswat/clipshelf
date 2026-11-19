import 'package:flutter/material.dart';

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
  final Color? color;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () => onSelected(value),
    style: TextButton.styleFrom(
      foregroundColor: section == value
          ? const Color(0xFF263744)
          : const Color(0xFF75808B),
      backgroundColor: section == value ? Colors.white : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    ),
    icon: Icon(icon, size: color == null ? 16 : 8, color: color),
    label: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: section == value ? FontWeight.w600 : FontWeight.w400,
      ),
    ),
  );
}
