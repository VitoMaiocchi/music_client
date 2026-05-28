import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';

abstract final class AppColors {
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF141414); // cards, tiles
  static const elevated = Color(0xFF1F1F1F); // bottom sheets, modals
  static const divider = Color(0xFF2A2A2A); // subtle separators
  static const progressIndicators = Color(0xFF3E3E3E); // progress bars, sliders

  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0x99FFFFFF); // artists, metadata

  static const accentFallback = Color.fromARGB(255, 208, 69, 226);
}

abstract final class AppTextStyles {
  static const pageTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const listTitle = TextStyle(
    fontSize: 15,
    color: AppColors.textPrimary,
  );
  static const listSubtitle = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
  );
}
