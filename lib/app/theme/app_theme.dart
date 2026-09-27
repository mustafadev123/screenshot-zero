import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

abstract final class AppTheme {
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.ink,
      onPrimary: AppColors.paper,
      secondary: AppColors.signal,
      onSecondary: AppColors.ink,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.graphite,
      outline: AppColors.border,
      error: Color(0xFFFF8A78),
      onError: AppColors.paper,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Roboto',
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.paper,
      textTheme: base.textTheme
          .copyWith(
            displayLarge: const TextStyle(
              fontSize: 160,
              height: .94,
              letterSpacing: -12,
              fontWeight: FontWeight.w300,
              color: AppColors.ink,
            ),
            displayMedium: const TextStyle(
              fontSize: 48,
              height: 1.02,
              letterSpacing: -2,
              fontWeight: FontWeight.w500,
              color: AppColors.ink,
            ),
            headlineLarge: const TextStyle(
              fontSize: 36,
              height: 1.08,
              letterSpacing: -1.5,
              fontWeight: FontWeight.w500,
              color: AppColors.ink,
            ),
            headlineMedium: const TextStyle(
              fontSize: 28,
              height: 1.12,
              letterSpacing: -.8,
              fontWeight: FontWeight.w500,
              color: AppColors.ink,
            ),
            bodyLarge: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: AppColors.graphite,
            ),
            bodyMedium: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.graphite,
            ),
            labelSmall: const TextStyle(
              fontSize: 10,
              height: 1.4,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w600,
              color: AppColors.graphite,
            ),
          )
          .apply(fontFamily: 'Roboto'),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.paper,
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radius),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: .2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppColors.ink,
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppColors.ink,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.transparent,
        selectedColor: AppColors.ink,
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        showDragHandle: true,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.elevated,
        contentTextStyle: TextStyle(color: AppColors.ink),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(color: AppColors.ink, fontSize: 24),
        contentTextStyle: TextStyle(color: AppColors.graphite, fontSize: 16),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppColors.elevated,
        textStyle: TextStyle(color: AppColors.ink),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.signal,
        linearTrackColor: AppColors.border,
      ),
    );
  }

  static ThemeData get light => dark;
}
