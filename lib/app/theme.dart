import 'package:flutter/material.dart';

const accent = Color(0xFF167D70);
ThemeData buildAppTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: accent),
  scaffoldBackgroundColor: const Color(0xFFFAFBF9),
  fontFamily: '.AppleSystemUIFont',
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFDEE7E2)),
    ),
  ),
);
