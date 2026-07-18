enum Priority { URGENT, NORMAL, LOW }

enum Status { PENDING_ANALYSIS, PENDING_JURY, PENDING_USER_REVIEW, DONE }

enum JuryVerdict { APPROVED, REJECTED, UNCERTAIN }

class Sender {
  final String name;
  final String email;

  Sender({required this.name, required this.email});
}

class EmailBody {
  final String plain;
  final String html;

  EmailBody({required this.plain, required this.html});
}

class Attachment {
  final String id;
  final String filename;
  final String mimeType;
  final int size;

  Attachment({
    required this.id,
    required this.filename,
    required this.mimeType,
    required this.size,
  });
}

class Analysis {
  final String summary;
  final String suggestedReply;
  final Priority priority;
  final double confidence;

  Analysis({
    required this.summary,
    required this.suggestedReply,
    required this.priority,
    required this.confidence,
  });
}

class Jury {
  final JuryVerdict verdict;
  final String? reasoning;

  Jury({required this.verdict, this.reasoning});
}

class Email {
  final String id;
  final String threadId;
  final String subject;
  final Sender from;
  final List<Sender> to;
  final DateTime date;
  final EmailBody body;
  final List<Attachment> attachments;
  final Status status;
  final Analysis? analysis;
  final Jury? jury;

  Email({
    required this.id,
    required this.threadId,
    required this.subject,
    required this.from,
    required this.to,
    required this.date,
    required this.body,
    required this.attachments,
    required this.status,
    this.analysis,
    this.jury,
  });
}
