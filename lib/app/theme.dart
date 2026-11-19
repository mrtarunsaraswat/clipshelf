import 'package:flutter/material.dart';

import 'tokens.dart';

export 'tokens.dart';

/// Material 3 theme for one appearance. [glass] is true when the native
/// frosted window is behind Flutter; previews and tests pass false.
ThemeData buildAppTheme(
  Brightness brightness, {
  Color accent = brandAccent,
  bool glass = true,
}) {
  final dark = brightness == Brightness.dark;
  final colors = dark
      ? ShelfColors.dark(accent, glass: glass)
      : ShelfColors.light(accent, glass: glass);
  final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: brightness)
      .copyWith(
        primary: colors.accentText,
        onPrimary: ShelfColors.onColor(colors.accentText),
      );
  final popupSurface = dark ? const Color(0xFF2B2B2F) : const Color(0xFFF7F7F9);
  final radius = BorderRadius.circular(ShelfRadius.sm + 2);
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: '.AppleSystemUIFont',
  );
  return base.copyWith(
    extensions: [colors],
    scaffoldBackgroundColor: colors.canvas,
    canvasColor: colors.canvas,
    dividerColor: colors.stroke,
    dividerTheme: DividerThemeData(
      color: colors.stroke,
      space: 1,
      thickness: 1,
    ),
    iconTheme: IconThemeData(color: colors.textSecondary, size: 18),
    listTileTheme: ListTileThemeData(
      titleTextStyle: TextStyle(
        fontFamily: '.AppleSystemUIFont',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: colors.textPrimary,
      displayColor: colors.textPrimary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      isDense: true,
      hintStyle: TextStyle(
        color: colors.textTertiary,
        fontSize: ShelfType.body,
      ),
      prefixIconColor: colors.textTertiary,
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: colors.stroke),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: colors.stroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: popupSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ShelfRadius.lg),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: popupSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: colors.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ShelfRadius.sm + 2),
        side: BorderSide(color: colors.stroke),
      ),
      textStyle: TextStyle(color: colors.textPrimary, fontSize: ShelfType.body),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(popupSurface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      textStyle: TextStyle(
        color: dark ? Colors.black : Colors.white,
        fontSize: ShelfType.caption,
      ),
      decoration: BoxDecoration(
        color: dark ? const Color(0xF2E8E8EC) : const Color(0xF21D1D1F),
        borderRadius: BorderRadius.circular(6),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF3A3A3F) : const Color(0xFF1D1D1F),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ShelfRadius.sm + 2),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? accent : null,
      ),
    ),
  );
}
