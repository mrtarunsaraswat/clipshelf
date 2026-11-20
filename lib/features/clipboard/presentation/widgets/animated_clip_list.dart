import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../domain/clipboard_item.dart';

/// A scrolling list of clips that animates changes:
/// - new copies at the front slide in while the others move aside,
/// - deleted items collapse away,
/// - anything else (search, filters, collection switch) cross-fades.
class AnimatedClipList extends StatefulWidget {
  const AnimatedClipList({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.controller,
    this.axis = Axis.horizontal,
    this.spacing = 14,
    this.extent,
    this.padding = EdgeInsets.zero,
  });

  final List<ClipItem> items;
  final Widget Function(BuildContext context, ClipItem item, int index)
  itemBuilder;
  final ScrollController controller;
  final Axis axis;
  final double spacing;

  /// Fixed main-axis size of each item (card width); null sizes to content.
  final double? extent;
  final EdgeInsets padding;

  @override
  State<AnimatedClipList> createState() => _AnimatedClipListState();
}

class _AnimatedClipListState extends State<AnimatedClipList> {
  static const _duration = Duration(milliseconds: 380);
  var _listKey = GlobalKey<AnimatedListState>();
  late List<ClipItem> _items = widget.items;

  /// Bumped on non-incremental changes so the whole list cross-fades.
  int _generation = 0;

  @override
  void didUpdateWidget(AnimatedClipList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.items;
    if (identical(next, _items)) return;
    final oldIds = [for (final item in _items) item.id];
    final newIds = [for (final item in next) item.id];
    if (_sameOrder(oldIds, newIds)) {
      _items = next; // Same items, new data (e.g. a link preview, a pin).
      return;
    }
    final list = _listKey.currentState;
    // New copies arrive at the front; the rest keep their order.
    final added = newIds.length - oldIds.length;
    if (list != null &&
        added > 0 &&
        _sameOrder(oldIds, newIds.sublist(added))) {
      _items = next;
      for (var i = 0; i < added; i++) {
        list.insertItem(i, duration: _duration);
      }
      return;
    }
    // Deletions: the survivors keep their order.
    final removed = oldIds.where((id) => !newIds.contains(id)).toList();
    if (list != null &&
        removed.isNotEmpty &&
        removed.length == oldIds.length - newIds.length &&
        _sameOrder(oldIds.where(newIds.contains).toList(), newIds)) {
      final old = _items;
      _items = next;
      for (var i = old.length - 1; i >= 0; i--) {
        if (!removed.contains(old[i].id)) continue;
        final gone = old[i];
        list.removeItem(
          i,
          (context, animation) => _wrap(context, gone, i, animation),
          duration: const Duration(milliseconds: 240),
        );
      }
      return;
    }
    setState(() {
      _items = next;
      _generation++;
      _listKey = GlobalKey<AnimatedListState>();
    });
  }

  static bool _sameOrder(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Widget _wrap(
    BuildContext context,
    ClipItem item,
    int index,
    Animation<double> animation,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    final horizontal = widget.axis == Axis.horizontal;
    final child = Padding(
      padding: horizontal
          ? EdgeInsets.only(right: widget.spacing)
          : EdgeInsets.only(bottom: widget.spacing),
      child: SizedBox(
        width: horizontal ? widget.extent : null,
        height: horizontal ? null : widget.extent,
        child: widget.itemBuilder(context, item, index),
      ),
    );
    return SizeTransition(
      sizeFactor: curved,
      axis: widget.axis,
      axisAlignment: -1,
      child: AnimatedBuilder(
        animation: curved,
        child: child,
        builder: (context, child) {
          final t = curved.value;
          // Arriving cards sharpen from a soft blur, like a focus pull.
          final blur = (1 - t) * 8;
          return Opacity(
            opacity: t,
            child: Transform.scale(
              scale: 0.92 + 0.08 * t,
              child: blur < 0.1
                  ? child
                  : ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                      child: child,
                    ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    // A rebuilt list (new filter or search) fades in; one list at a time,
    // because both would share the scroll controller.
    key: ValueKey(_generation),
    tween: Tween(begin: _generation == 0 ? 1 : 0, end: 1),
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOut,
    builder: (context, opacity, child) =>
        Opacity(opacity: opacity, child: child),
    child: AnimatedList(
      key: _listKey,
      controller: widget.controller,
      scrollDirection: widget.axis,
      padding: widget.padding,
      // Clip to the list's own area: anything scrolled out of view must not
      // paint over the search field or the window edges. Callers give the
      // list enough padding for card shadows instead.
      clipBehavior: Clip.hardEdge,
      initialItemCount: _items.length,
      itemBuilder: (context, index, animation) => index < _items.length
          ? _wrap(context, _items[index], index, animation)
          : const SizedBox.shrink(),
    ),
  );
}
