import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../../app/tokens.dart';

/// The shelf header's search button that stretches into the search field.
///
/// Opening: the round button grows left and right into the capsule while the
/// field's content is revealed (not squeezed), the tabs fade and slide aside,
/// and the compact collection icons fade in last. Closing reverses it.
class SearchMorph extends StatefulWidget {
  const SearchMorph({
    super.key,
    required this.open,
    required this.onOpen,
    required this.focusNode,
    required this.tabs,
    required this.compact,
    required this.field,
    this.height = 34,
  });

  final bool open;
  final VoidCallback onOpen;
  final FocusNode focusNode;

  /// The full collection tabs shown while search is closed.
  final Widget tabs;

  /// Icon-only collections shown beside the open field.
  final Widget compact;

  /// The search field, drawn without its own border (the capsule draws it).
  final Widget field;
  final double height;

  @override
  State<SearchMorph> createState() => _SearchMorphState();
}

class _SearchMorphState extends State<SearchMorph>
    with SingleTickerProviderStateMixin {
  static const _button = 32.0, _gap = 6.0;
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 320),
    value: widget.open ? 1 : 0,
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  final _tabsKey = GlobalKey(), _compactKey = GlobalKey();
  double _tabsWidth = 360, _compactWidth = 120;

  @override
  void didUpdateWidget(SearchMorph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != oldWidget.open) {
      widget.open ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Measures the tabs and compact icons after layout so the capsule knows
  /// where it starts (the centred button) and how far it may grow.
  void _measure() {
    double? width(GlobalKey key) =>
        (key.currentContext?.findRenderObject() as RenderBox?)?.size.width;
    final tabs = width(_tabsKey), compact = width(_compactKey);
    if ((tabs != null && (tabs - _tabsWidth).abs() > 0.5) ||
        (compact != null && (compact - _compactWidth).abs() > 0.5)) {
      setState(() {
        _tabsWidth = tabs ?? _tabsWidth;
        _compactWidth = compact ?? _compactWidth;
      });
    }
  }

  static double _interval(double t, double begin, double end) =>
      ((t - begin) / (end - begin)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final colors = context.shelf;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final closedLeft = ((width - (_button + _gap + _tabsWidth)) / 2).clamp(
          0.0,
          width,
        );
        final openWidth = (width - _compactWidth - 10).clamp(_button, width);
        return SizedBox(
          height: widget.height + 2,
          child: AnimatedBuilder(
            animation: Listenable.merge([_curve, widget.focusNode]),
            builder: (context, _) {
              final t = _curve.value;
              final left = lerpDouble(closedLeft, 0, t)!;
              final capsuleWidth = lerpDouble(_button, openWidth, t)!;
              final capsuleHeight = lerpDouble(_button, widget.height, t)!;
              final tabsOut = _interval(t, 0, 0.45);
              final compactIn = _interval(t, 0.55, 1);
              final fieldIn = _interval(t, 0.15, 0.6);
              final focused = widget.focusNode.hasFocus && t > 0.5;
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  if (t < 1)
                    Positioned(
                      left: closedLeft + _button + _gap + 28 * t,
                      child: IgnorePointer(
                        ignoring: t > 0,
                        child: Opacity(
                          opacity: 1 - tabsOut,
                          child: KeyedSubtree(
                            key: _tabsKey,
                            child: widget.tabs,
                          ),
                        ),
                      ),
                    ),
                  if (t > 0)
                    Positioned(
                      right: 0,
                      child: Opacity(
                        opacity: compactIn,
                        child: Transform.translate(
                          offset: Offset(16 * (1 - compactIn), 0),
                          child: KeyedSubtree(
                            key: _compactKey,
                            child: widget.compact,
                          ),
                        ),
                      ),
                    )
                  else
                    // Keep measuring the compact icons while closed.
                    Positioned(
                      right: 0,
                      child: Offstage(
                        child: KeyedSubtree(
                          key: _compactKey,
                          child: widget.compact,
                        ),
                      ),
                    ),
                  Positioned(
                    left: left,
                    width: capsuleWidth,
                    height: capsuleHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        // Fade the fill in from the same colour at zero
                        // alpha, so it never passes through grey.
                        color: colors.surface.withValues(
                          alpha: colors.surface.a * t,
                        ),
                        borderRadius: BorderRadius.circular(capsuleHeight / 2),
                        border: Border.all(
                          color: focused
                              ? colors.accent
                              : colors.stroke.withValues(
                                  alpha: colors.stroke.a * t,
                                ),
                          width: focused ? 2 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(capsuleHeight / 2),
                        child: Stack(
                          children: [
                            if (t > 0)
                              OverflowBox(
                                alignment: Alignment.centerLeft,
                                minWidth: openWidth,
                                maxWidth: openWidth,
                                child: Opacity(
                                  opacity: fieldIn,
                                  child: widget.field,
                                ),
                              ),
                            if (t < 0.4)
                              Opacity(
                                opacity: 1 - _interval(t, 0, 0.4),
                                child: Tooltip(
                                  message: 'Search (⌘F)',
                                  child: Material(
                                    type: MaterialType.transparency,
                                    child: InkWell(
                                      onTap: t == 0 ? widget.onOpen : null,
                                      customBorder: const StadiumBorder(),
                                      hoverColor: colors.surfaceHover,
                                      child: SizedBox(
                                        width: _button,
                                        height: capsuleHeight,
                                        child: Icon(
                                          Icons.search,
                                          size: 19,
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
