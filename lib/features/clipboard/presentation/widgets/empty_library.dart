import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipshelf/app/theme.dart';
import 'package:clipshelf/app/widgets/keycap.dart';
import 'package:clipshelf/features/clipboard/application/library_view_controller.dart';

class EmptyLibrary extends ConsumerWidget {
  const EmptyLibrary({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(libraryViewProvider);
    final section = view.collection.key;
    final filter = view.filter.label;
    final query = view.query;
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: context.shelf.surfaceSelected,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  section == 'Snippets'
                      ? Icons.bookmark_add_outlined
                      : query.isNotEmpty || filter != 'All'
                      ? Icons.search_off_rounded
                      : Icons.content_paste_rounded,
                  size: 28,
                  color: context.shelf.accentText,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                query.isNotEmpty || filter != 'All'
                    ? 'Nothing matches just yet.'
                    : section == 'Snippets'
                    ? 'Your words, on speed dial.'
                    : section == 'All items'
                    ? 'Your next copy starts here.'
                    : 'Keep the useful things here.',
                style: const TextStyle(
                  fontSize: ShelfType.heading,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                query.isNotEmpty || filter != 'All'
                    ? 'Try another search or format.'
                    : section == 'All items'
                    ? 'Copy text, images, or files in any app.'
                    : section == 'Snippets'
                    ? 'Save text you use again and again.'
                    : 'Drag a card here or use its Pin action.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: context.shelf.textSecondary,
                ),
              ),
              if (section == 'All items' &&
                  query.isEmpty &&
                  filter == 'All') ...[
                const SizedBox(height: 14),
                const Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    KeyHint(keys: ['⌘', 'C'], label: 'Copy anywhere'),
                    KeyHint(keys: ['⌥', '⌘', 'V'], label: 'Open ClipShelf'),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
