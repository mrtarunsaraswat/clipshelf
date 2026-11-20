import 'package:flutter/material.dart';

/// ClipShelf's fallback accent, used until macOS reports the user's accent colour.
const brandAccent = Color(0xFF167D70);

/// Colour tokens for the glass UI. The window behind Flutter is a native
/// NSVisualEffectView, so surfaces are translucent layers over that blur.
@immutable
class ShelfColors extends ThemeExtension<ShelfColors> {
  const ShelfColors({
    required this.accent,
    required this.onAccent,
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceHover,
    required this.surfaceSelected,
    required this.stroke,
    required this.strokeStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.shadow,
    required this.warningSurface,
    required this.warningText,
    required this.danger,
    required this.kindText,
    required this.kindLink,
    required this.kindImage,
    required this.kindFile,
    required this.kindSnippet,
    required this.boards,
  });

  final Color accent, onAccent;

  /// Accent for text and icons on the window surface; lifted in dark mode so
  /// deep accents (the default teal, graphite) stay readable.
  Color get accentText => textPrimary.computeLuminance() < 0.5
      ? accent
      : Color.lerp(accent, Colors.white, 0.35)!;

  /// Readable foreground for text on a [background] colour such as a card header.
  static Color onColor(Color background) => background.computeLuminance() > 0.3
      ? const Color(0xE6000000)
      : Colors.white;

  /// Painted behind everything: clear over the native glass, or an opaque
  /// fallback when there is no glass (tests, previews, Reduce Transparency).
  final Color canvas;
  final Color surface, surfaceRaised, surfaceHover, surfaceSelected;
  final Color stroke, strokeStrong;
  final Color textPrimary, textSecondary, textTertiary;
  final Color shadow, warningSurface, warningText, danger;
  final Color kindText, kindLink, kindImage, kindFile, kindSnippet;
  final List<Color> boards;

  static ShelfColors light(Color accent, {bool glass = true}) => ShelfColors(
    accent: accent,
    onAccent: Colors.white,
    canvas: glass ? Colors.transparent : const Color(0xFFF2F2F5),
    surface: const Color(0xC7FFFFFF),
    surfaceRaised: const Color(0xF2FFFFFF),
    surfaceHover: const Color(0x0D000000),
    surfaceSelected: accent.withValues(alpha: 0.12),
    stroke: const Color(0x14000000),
    strokeStrong: const Color(0x24000000),
    textPrimary: const Color(0xFF1D1D1F),
    textSecondary: const Color(0xFF5B5E66),
    textTertiary: const Color(0xFF8A8D94),
    shadow: const Color(0x1A000000),
    warningSurface: const Color(0xFFFFF3DC),
    warningText: const Color(0xFF7A5200),
    danger: const Color(0xFFD70015),
    kindText: const Color(0xFF64748B),
    kindLink: const Color(0xFF2F6FDB),
    kindImage: const Color(0xFF1F9C84),
    kindFile: const Color(0xFFD9822B),
    kindSnippet: const Color(0xFF9B5BC6),
    boards: const [
      Color(0xFF5B80DD),
      Color(0xFFE78A50),
      Color(0xFFAE75CD),
      Color(0xFF54A68D),
      Color(0xFFD67790),
      Color(0xFFC7A94A),
    ],
  );

  static ShelfColors dark(Color accent, {bool glass = true}) => ShelfColors(
    accent: accent,
    onAccent: Colors.white,
    canvas: glass ? Colors.transparent : const Color(0xFF1E1E21),
    surface: const Color(0x17FFFFFF),
    surfaceRaised: const Color(0x26FFFFFF),
    surfaceHover: const Color(0x12FFFFFF),
    surfaceSelected: accent.withValues(alpha: 0.24),
    stroke: const Color(0x1AFFFFFF),
    strokeStrong: const Color(0x33FFFFFF),
    textPrimary: const Color(0xFFF5F5F7),
    textSecondary: const Color(0xFFB3B5BC),
    textTertiary: const Color(0xFF85888F),
    shadow: const Color(0x59000000),
    warningSurface: const Color(0x33FFB020),
    warningText: const Color(0xFFFFD58A),
    danger: const Color(0xFFFF6961),
    kindText: const Color(0xFF94A3B8),
    kindLink: const Color(0xFF6EA2FF),
    kindImage: const Color(0xFF4CC9AE),
    kindFile: const Color(0xFFF5A65B),
    kindSnippet: const Color(0xFFC08BEA),
    boards: const [
      Color(0xFF7D9BF0),
      Color(0xFFF2A06E),
      Color(0xFFC495E0),
      Color(0xFF6CC3A6),
      Color(0xFFEB93A9),
      Color(0xFFE0C46A),
    ],
  );

  @override
  ShelfColors copyWith() => this;

  @override
  ShelfColors lerp(ShelfColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return ShelfColors(
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      canvas: c(canvas, other.canvas),
      surface: c(surface, other.surface),
      surfaceRaised: c(surfaceRaised, other.surfaceRaised),
      surfaceHover: c(surfaceHover, other.surfaceHover),
      surfaceSelected: c(surfaceSelected, other.surfaceSelected),
      stroke: c(stroke, other.stroke),
      strokeStrong: c(strokeStrong, other.strokeStrong),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      shadow: c(shadow, other.shadow),
      warningSurface: c(warningSurface, other.warningSurface),
      warningText: c(warningText, other.warningText),
      danger: c(danger, other.danger),
      kindText: c(kindText, other.kindText),
      kindLink: c(kindLink, other.kindLink),
      kindImage: c(kindImage, other.kindImage),
      kindFile: c(kindFile, other.kindFile),
      kindSnippet: c(kindSnippet, other.kindSnippet),
      boards: [
        for (var i = 0; i < boards.length; i++) c(boards[i], other.boards[i]),
      ],
    );
  }
}

/// Spacing scale (pt).
abstract final class ShelfSpace {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 24.0;
}

/// Corner radii (pt).
abstract final class ShelfRadius {
  static const sm = 8.0, md = 12.0, lg = 16.0;
}

/// Type scale. Numbers use tabular figures so ⌘1–⌘9 line up.
abstract final class ShelfType {
  /// Bundled Geist (Google Fonts). SF Pro fills in glyphs Geist lacks, such
  /// as ⌘ ⌥ ↩ and the arrows used on keycaps.
  static const family = 'Geist';
  static const monoFamily = 'GeistMono';
  static const fallback = ['.AppleSystemUIFont'];
  static const caption = 11.0, meta = 12.0, body = 13.0, title = 15.0;
  static const heading = 17.0;
  static const tabular = [FontFeature.tabularFigures()];
}

extension ShelfThemeContext on BuildContext {
  ShelfColors get shelf =>
      Theme.of(this).extension<ShelfColors>() ??
      ShelfColors.light(brandAccent, glass: false);
}
