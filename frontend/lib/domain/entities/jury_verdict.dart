class JuryVerdict {
  const JuryVerdict({
    required this.verdict,
    required this.confidenceScore,
    required this.comment,
  });

  final String verdict;
  final double confidenceScore;
  final String comment;
}
