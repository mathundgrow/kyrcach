import 'package:flutter/material.dart';

import 'package:codegraph/core/theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'workspace_page.dart';

class CodeGraphApp extends StatelessWidget {
  const CodeGraphApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'архитектурный анализатор',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const WorkspacePage(),
      builder: (context, child) {
        return _AppShortcutTheme(child: child ?? const SizedBox.shrink());
      },
    );
  }
}

class _AppShortcutTheme extends StatelessWidget {
  const _AppShortcutTheme({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(
        decoration: TextDecoration.none,
        color: AppColors.textPrimary,
      ),
      child: child,
    );
  }
}
