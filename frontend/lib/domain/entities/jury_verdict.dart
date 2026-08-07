class JuryVerdict {
  const JuryVerdict({
    required this.verdict,
    required this.confidenceScore,
    required this.comment,
    this.reasons = const [],
    this.riskFlags = const [],
  });

  final String verdict;
  final double confidenceScore;
  final String comment;
  final List<String> reasons;
  final List<String> riskFlags;
}
