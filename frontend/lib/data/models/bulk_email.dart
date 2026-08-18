class BulkEmail {
  final String id;
  final String recipient;
  final String subject;
  final String body;

  BulkEmail({
    required this.id,
    required this.recipient,
    required this.subject,
    required this.body,
  });

  factory BulkEmail.fromJson(Map<String, dynamic> json) {
    final recipientData = json['recipient'];
    final recipientEmail =
        recipientData is Map ? recipientData['email']?.toString() : null;

    return BulkEmail(
      id:
          json['id']?.toString() ??
          json['email_id']?.toString() ??
          json['message_id']?.toString() ??
          json['to']?.toString() ??
          json['email']?.toString() ??
          recipientEmail ??
          '',
      recipient:
          recipientEmail ??
          json['to']?.toString() ??
          json['email']?.toString() ??
          json['recipient']?.toString() ??
          '',
      subject: json['subject']?.toString() ?? '',
      body:
          json['body']?.toString() ??
          json['body_preview']?.toString() ??
          json['reply_body']?.toString() ??
          json['suggested_reply']?.toString() ??
          '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipient': recipient,
      'to': recipient,
      'email': recipient,
      'subject': subject,
      'body': body,
    };
  }

  BulkEmail copyWith({
    String? id,
    String? recipient,
    String? subject,
    String? body,
  }) {
    return BulkEmail(
      id: id ?? this.id,
      recipient: recipient ?? this.recipient,
      subject: subject ?? this.subject,
      body: body ?? this.body,
    );
  }
}
