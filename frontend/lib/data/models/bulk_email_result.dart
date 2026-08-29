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
    final recipientData = json['recipient'];
    final recipientEmail =
        recipientData is Map ? recipientData['email']?.toString() : null;
    final rawStatus = json['status']?.toString() ?? 'error';

    return BulkEmailResult(
      recipient:
          json['recipient']?.toString() ??
          json['to']?.toString() ??
          json['email']?.toString() ??
          recipientEmail ??
          '',
      status: rawStatus == 'sent' ? 'success' : rawStatus,
      errorMessage:
          json['errorMessage']?.toString() ?? json['error']?.toString(),
    );
  }

  bool get isSuccess => status == 'success';
}
