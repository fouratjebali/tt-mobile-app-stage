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
    return BulkEmail(
      id: json['id']?.toString() ?? '',
      recipient: json['recipient']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipient': recipient,
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