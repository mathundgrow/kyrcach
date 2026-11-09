import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color background = Color(0xFF0C0A06);
  static const Color surface = Color(0xFF141007);
  static const Color surfaceAlt = Color(0xFF1A150C);
  static const Color surfaceRaised = Color(0xFF221B10);
  static const Color surfaceHigh = Color(0xFF2A2114);

  static const Color border = Color(0xFF342A17);
  static const Color borderStrong = Color(0xFF4A3A1E);

  static const Color primary = Color(0xFFF2C14E);
  static const Color primaryBright = Color(0xFFFFD563);
  static const Color primaryDim = Color(0xFFC79A2E);
  static const Color primaryWash = Color(0xFF3A2C10);

  static const Color textPrimary = Color(0xFFF4EAD4);
  static const Color textSecondary = Color(0xFFBCA982);
  static const Color textMuted = Color(0xFF7E7052);

  static const Color danger = Color(0xFFFF4D4F);
  static const Color dangerWash = Color(0xFF3A1212);
  static const Color warning = Color(0xFFF0A93B);
  static const Color warningWash = Color(0xFF3A2A0D);
  static const Color success = Color(0xFF9BCF6A);
  static const Color successWash = Color(0xFF1E2A12);
  static const Color info = Color(0xFF6FA8FF);

  /// Цвет предупреждений в аномалиях. Янтарный `warning` сливается с жёлтым
  /// интерфейсом, поэтому для проблем используется отдельный розово-красный.
  static const Color issueWarning = Color(0xFFFF6B8A);
  static const Color issueWarningWash = Color(0xFF3A1620);

  /// Рёбра в режиме фокуса: исходящие импорты и входящие использования.
  static const Color importEdge = Color(0xFF5CC8FF);
  static const Color usedByEdge = Color(0xFF57D9A3);
  static const Color bothEdge = Color(0xFFC792EA);

  static const Color shadow = Color(0xCC000000);

  static const LinearGradient amberGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBright, primary, Color(0xFFD79D22)],
  );

  static const LinearGradient panelGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A150C), Color(0xFF120F09)],
  );

  static const Gradient canvasGradient = RadialGradient(
    center: Alignment(-0.4, -0.6),
    radius: 1.2,
    colors: [Color(0xFF191307), Color(0xFF0C0A06)],
  );
}
