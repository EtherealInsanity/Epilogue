enum LinterSeverity {
  error,
  warning,
  info,
}

class LinterIssue {
  final String ruleId;
  final String message;
  final LinterSeverity severity;
  final int? chapterIndex;
  final String? targetHref;
  final bool canAutoFix;

  const LinterIssue({
    required this.ruleId,
    required this.message,
    required this.severity,
    this.chapterIndex,
    this.targetHref,
    this.canAutoFix = false,
  });
}
