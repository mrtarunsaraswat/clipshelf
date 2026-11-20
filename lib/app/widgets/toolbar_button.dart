import 'package:flutter/material.dart';

import '../tokens.dart';

/// Compact, rounded hover style for toolbar icon buttons.
ButtonStyle toolbarButtonStyle(ShelfColors colors, {Color? foreground}) =>
    IconButton.styleFrom(
      fixedSize: const Size(30, 30),
      minimumSize: const Size(30, 30),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      foregroundColor: foreground ?? colors.textSecondary,
      hoverColor: colors.surfaceHover,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
