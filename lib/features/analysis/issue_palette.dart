import 'package:flutter/material.dart';

import 'package:codegraph/core/theme/app_colors.dart';
import 'package:codegraph/features/analysis/architecture_issue.dart';

extension IssueKindVisuals on IssueKind {
  IconData get icon => switch (this) {
    IssueKind.isolatedFile => Icons.link_off_rounded,
    IssueKind.circularDependency => Icons.loop_rounded,
    IssueKind.layerViolation => Icons.layers_clear_rounded,
    IssueKind.highCoupling => Icons.hub_rounded,
  };
}

extension IssueSeverityVisuals on IssueSeverity {
  Color get color => switch (this) {
    IssueSeverity.critical => AppColors.danger,
    IssueSeverity.warning => AppColors.issueWarning,
    IssueSeverity.info => AppColors.info,
  };

  Color get wash => switch (this) {
    IssueSeverity.critical => AppColors.dangerWash,
    IssueSeverity.warning => AppColors.issueWarningWash,
    IssueSeverity.info => AppColors.surfaceHigh,
  };
}
