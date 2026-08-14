class BulkEmailResult {
  final String recipient;
  final String status;
  final String? errorMessage;

  BulkEmailResult({
    required this.recipient,
    required this.status,
    this.errorMessage,
  });

  factory BulkEmailResult.fromJson(Map<String, dynamic> json) {
    return BulkEmailResult(
      recipient: json['recipient']?.toString() ?? '',
      status: json['status']?.toString() ?? 'error',
      errorMessage: json['errorMessage']?.toString(),
    );
  }

  bool get isSuccess => status == 'success';
}