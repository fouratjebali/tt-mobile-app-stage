class SentimentResult {
  const SentimentResult({
    required this.text,
    required this.label,
    required this.score,
    required this.rawScores,
  });

  final String text;
  final String label;
  final double score;
  final Map<String, dynamic> rawScores;
}
