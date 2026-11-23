import 'package:flutter/material.dart';

/// Colour tokens. Dark is the primary theme: the photo should stand out.
abstract final class AppColors {
  static const bg = Color(0xFF0E0F13);
  static const surface = Color(0xFF17181D);
  static const surface2 = Color(0xFF1F2128);
  static const border = Color(0x14FFFFFF); // 8% white
  static const accent = Color(0xFF7C5CFF);
  static const ai = Color(0xFF22D3EE);
  static const textHi = Color(0xFFF4F5F8);
  static const textLo = Color(0xFFA3A8B8); // 7.6:1 on bg
  static const danger = Color(0xFFFF5C7A);

  static const lightBg = Color(0xFFF6F6FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurface2 = Color(0xFFEDEEF4);
  static const lightText = Color(0xFF15161B);
  static const lightTextLo = Color(0xFF555A6B);

  /// Used only for "AI moments": primary AI buttons and progress shimmer.
  static const aiGradient = LinearGradient(colors: [accent, ai]);
}
