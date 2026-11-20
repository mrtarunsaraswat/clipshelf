import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipshelf/app/tokens.dart';
import 'package:clipshelf/app/widgets/hover_surface.dart';
import 'package:clipshelf/app/widgets/keycap.dart';
import 'package:clipshelf/features/clipboard/data/clip_media.dart';
import 'package:clipshelf/features/clipboard/domain/clipboard_item.dart';
import 'package:clipshelf/features/clipboard/domain/pinboard.dart';
import 'package:clipshelf/features/clipboard/presentation/clipboard_actions.dart';
import 'package:clipshelf/features/clipboard/presentation/clipboard_style.dart';
import 'package:clipshelf/features/clipboard/presentation/widgets/item_context_menu.dart';

class ClipboardCard extends StatelessWidget {
  const ClipboardCard({
    super.key,
    required this.item,
    required this.index,
    required this.active,
    required this.actions,
    required this.boards,
    required this.onSelected,
  });
  final ClipItem item;
  final int index;
  final bool active;
  final ClipboardActions actions;
  final List<Pinboard> boards;
  final VoidCallback onSelected;

  String get _kindLabel => item.snippet
      ? 'Snippet'
      : isLink(item)
      ? 'Link'
      : switch (item.kind) {
          'text' => 'Text',
          'image' => 'Image',
          'file' => 'File',
          _ => 'Content',
        };

  @override
  Widget build(BuildContext context) {
    final colors = context.shelf;
    final tint = cardColor(item, boards, colors);
    final content = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          onSelected();
          actions.paste(item);
        },
        child: _CardBody(item: item, tint: tint),
      ),
    );
    return GestureDetector(
      onSecondaryTapDown: (details) async {
        final value = await showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(
            details.globalPosition.dx,
            details.globalPosition.dy,
            0,
            0,
          ),
          items: itemContextMenu(item, boards, colors),
        );
        if (value != null) actions.handleItem(value, item);
      },
      child: HoverSurface(
        selected: active,
        lift: true,
        border: true,
        radius: 14,
        color: colors.surfaceRaised,
        hoverColor: colors.surfaceRaised,
        selectedColor: colors.surfaceRaised,
        builder: (context, hovered) => ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: tint),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
                      child: Row(
                        children: [
                          _KindChip(
                            icon: clipIcon(item),
                            label: _kindLabel,
                            tint: tint,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              formatClipAge(item.date),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: ShelfType.caption,
                                color: colors.textTertiary,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // The actions button replaces the shortcut on hover,
                          // so the header never gets crowded.
                          if (hovered || active)
                            SizedBox(
                              width: 26,
                              height: 22,
                              child: PopupMenuButton<String>(
                                tooltip: 'Item actions',
                                padding: EdgeInsets.zero,
                                iconSize: 18,
                                onSelected: (value) =>
                                    actions.handleItem(value, item),
                                itemBuilder: (_) =>
                                    itemContextMenu(item, boards, colors),
                                icon: Icon(
                                  Icons.more_horiz,
                                  color: colors.textSecondary,
                                ),
                              ),
                            )
                          else if (index < 9)
                            Keycap('⌘${index + 1}', dense: true),
                          _AppIcon(item: item),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Draggable<String>(
                        data: item.id,
                        feedback: _DragFeedback(item: item, tint: tint),
                        childWhenDragging: Opacity(
                          opacity: 0.35,
                          child: content,
                        ),
                        child: content,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.icon,
    required this.label,
    required this.tint,
  });
  final IconData icon;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
    decoration: BoxDecoration(
      color: tint.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: tint),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: ShelfType.caption,
            fontWeight: FontWeight.w600,
            color: tint,
          ),
        ),
      ],
    ),
  );
}

/// The source app's real icon, with its name as the tooltip.
class _AppIcon extends ConsumerWidget {
  const _AppIcon({required this.item});
  final ClipItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = ref.watch(appIconProvider(item.sourceBundleID)).value;
    // Only a real app icon; snippets and older items without one show nothing.
    if (icon == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: item.source,
        child: Image.memory(icon, width: 22, height: 22, gaplessPlayback: true),
      ),
    );
  }
}

/// Content area, shaped by what was copied.
class _CardBody extends ConsumerWidget {
  const _CardBody({required this.item, required this.tint});
  final ClipItem item;
  final Color tint;

  static bool _looksLikeCode(String text) =>
      text.contains('{') ||
      text.contains('=>') ||
      RegExp(
        r'^\s*(import|const|final|let|var|def|func|class)\s',
        multiLine: true,
      ).hasMatch(text);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.preview != null) return _image(context);
    if (item.kind == 'file') return _file(context, ref);
    if (isLink(item)) {
      final preview = ref.watch(linkPreviewProvider(item.text.trim())).value;
      if (preview != null) return _linkPreview(context, preview);
    }
    return _text(context);
  }

  Widget _footer(BuildContext context, String text, {Color? color}) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: ShelfType.caption,
        color: color ?? context.shelf.textTertiary,
      ),
    ),
  );

  Widget _image(BuildContext context) {
    final colors = context.shelf;
    final size = item.pixelWidth > 0
        ? '${item.pixelWidth} × ${item.pixelHeight}'
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ShelfRadius.sm),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: colors.surfaceHover,
              child: Image.memory(
                item.preview!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, error, stack) =>
                    Icon(Icons.image_not_supported, color: colors.textTertiary),
              ),
            ),
            if (size != null)
              Positioned(right: 6, bottom: 6, child: _Badge(text: size)),
          ],
        ),
      ),
    );
  }

  Widget _file(BuildContext context, WidgetRef ref) {
    final colors = context.shelf;
    final reference = item.text.isNotEmpty ? item.text : item.title;
    final path = Uri.tryParse(reference)?.isScheme('file') == true
        ? Uri.parse(reference).toFilePath()
        : reference;
    final icon = ref.watch(fileIconProvider(path)).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: icon != null
                ? Image.memory(
                    icon,
                    width: 64,
                    height: 64,
                    gaplessPlayback: true,
                  )
                : Icon(
                    Icons.insert_drive_file_outlined,
                    size: 48,
                    color: colors.textTertiary,
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ShelfType.body,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ),
        _footer(context, path.replaceFirst(RegExp(r'^/Users/[^/]+'), '~')),
      ],
    );
  }

  Widget _linkPreview(BuildContext context, LinkPreview preview) {
    final colors = context.shelf;
    final uri = Uri.tryParse(item.text.trim());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (preview.image != null)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(ShelfRadius.sm),
                child: Image.memory(
                  preview.image!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Text(
            preview.title,
            maxLines: preview.image != null ? 1 : 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ShelfType.body,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ),
        if (preview.image == null) const Spacer(),
        _footer(
          context,
          uri == null
              ? item.text
              : '${uri.host.replaceFirst(RegExp(r'^www\.'), '')}${uri.path == '/' ? '' : uri.path}',
        ),
      ],
    );
  }

  Widget _text(BuildContext context) {
    final colors = context.shelf;
    final text = item.text.isNotEmpty ? item.text : item.title;
    final link = isLink(item) ? Uri.tryParse(item.text.trim()) : null;
    final code = link == null && _looksLikeCode(text);
    final characters = item.text.characters.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
            child: LayoutBuilder(
              builder: (context, size) {
                final lineHeight = code ? 18.0 : 19.0;
                final reserved = link != null ? 24.0 : 0.0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (link != null && link.host.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(Icons.public, size: 14, color: tint),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                link.host.replaceFirst(RegExp(r'^www\.'), ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: ShelfType.meta,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      text,
                      maxLines: ((size.maxHeight - reserved) / lineHeight)
                          .floor()
                          .clamp(1, 20),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: code ? ShelfType.meta : ShelfType.body,
                        height: code ? 1.5 : 1.45,
                        color: link != null
                            ? colors.textSecondary
                            : colors.textPrimary,
                        fontFamily: code ? ShelfType.monoFamily : null,
                        fontFamilyFallback: code
                            ? const ['Menlo', ...ShelfType.fallback]
                            : null,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        _footer(
          context,
          link != null
              ? item.source
              : '$characters ${characters == 1 ? 'character' : 'characters'}',
        ),
      ],
    );
  }
}

/// Small dark pill over images, e.g. "2400 × 1600".
class _Badge extends StatelessWidget {
  const _Badge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0x99000000),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w500,
        color: Colors.white,
        fontFeatures: ShelfType.tabular,
      ),
    ),
  );
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.item, required this.tint});
  final ClipItem item;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final colors = context.shelf;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(ShelfRadius.md),
          border: Border.all(color: tint, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          item.title,
          maxLines: 3,
          style: TextStyle(color: colors.textPrimary, fontSize: ShelfType.body),
        ),
      ),
    );
  }
}
