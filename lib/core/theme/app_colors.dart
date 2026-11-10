import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color background = Color.fromARGB(255, 15, 13, 10);
  static const Color surface = Color.fromARGB(255, 17, 14, 8);
  static const Color surfaceAlt = Color.fromARGB(255, 31, 26, 17);
  static const Color surfaceRaised = Color.fromARGB(255, 28, 23, 16);
  static const Color surfaceHigh = Color.fromARGB(255, 44, 37, 26);

  static const Color border = Color.fromARGB(255, 53, 45, 31);
  static const Color borderStrong = Color.fromARGB(255, 72, 55, 24);

  static const Color primary = Color.fromARGB(255, 243, 204, 111);
  static const Color primaryBright = Color.fromARGB(255, 253, 220, 129);
  static const Color primaryDim = Color.fromARGB(255, 195, 160, 80);
  static const Color primaryWash = Color.fromARGB(255, 62, 50, 26);

  static const Color textPrimary = Color.fromARGB(255, 245, 238, 223);
  static const Color textSecondary = Color.fromARGB(255, 190, 174, 141);
  static const Color textMuted = Color.fromARGB(255, 132, 122, 99);

  static const Color danger = Color.fromARGB(255, 188, 56, 58);
  static const Color dangerWash = Color.fromARGB(255, 73, 25, 25);
  static const Color warning = Color.fromARGB(255, 236, 159, 44);
  static const Color warningWash = Color.fromARGB(255, 54, 40, 14);
  static const Color success = Color.fromARGB(255, 132, 193, 75);
  static const Color successWash = Color.fromARGB(255, 34, 44, 24);
  static const Color info = Color.fromARGB(255, 74, 138, 235);

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
    colors: [primaryBright, bothEdge, Color.fromARGB(255, 141, 59, 182)],
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
