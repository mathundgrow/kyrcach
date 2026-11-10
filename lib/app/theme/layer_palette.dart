import 'package:flutter/material.dart';

import 'package:codegraph/features/project_scan/models/architecture_layer.dart';
import 'package:codegraph/core/theme/app_colors.dart';

extension ArchitectureLayerPalette on ArchitectureLayer {
  Color get color => switch (this) {
    ArchitectureLayer.presentation => const Color(0xFF5FC9D6),
    ArchitectureLayer.application => const Color(0xFFE58E52),
    ArchitectureLayer.domain => const Color(0xFF8DD17E),
    ArchitectureLayer.data => const Color(0xFF68A7FF),
    ArchitectureLayer.core => const Color(0xFFB58CFF),
    ArchitectureLayer.unknown => const Color(0xFF8A8478),
  };

  Color get softColor => color.withValues(alpha: 0.12);

  IconData get icon => switch (this) {
    ArchitectureLayer.presentation => Icons.desktop_windows_outlined,
    ArchitectureLayer.application => Icons.account_tree_outlined,
    ArchitectureLayer.domain => Icons.hub_outlined,
    ArchitectureLayer.data => Icons.storage_outlined,
    ArchitectureLayer.core => Icons.settings_suggest_outlined,
    ArchitectureLayer.unknown => Icons.help_outline_rounded,
  };

  String get shortLabel => switch (this) {
    ArchitectureLayer.presentation => 'UI',
    ArchitectureLayer.application => 'App',
    ArchitectureLayer.domain => 'Domain',
    ArchitectureLayer.data => 'Data',
    ArchitectureLayer.core => 'Core',
    ArchitectureLayer.unknown => 'Other',
  };
}

extension AppColorX on Color {
  Color get onDarkSurface => AppColors.textPrimary;
}
