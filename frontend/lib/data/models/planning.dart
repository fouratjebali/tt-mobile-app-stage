class PlanningImportSummary {
  const PlanningImportSummary({
    required this.importId,
    required this.status,
    required this.totalSessions,
    required this.totalParticipants,
    required this.missingEmailCount,
    required this.warningCount,
    required this.errorCount,
    required this.createdAt,
  });

  final String importId;
  final String status;
  final int totalSessions;
  final int totalParticipants;
  final int missingEmailCount;
  final int warningCount;
  final int errorCount;
  final String createdAt;

  factory PlanningImportSummary.fromJson(Map<String, dynamic> json) {
    return PlanningImportSummary(
      importId: _string(json['import_id']),
      status: _string(json['status']),
      totalSessions: _int(json['total_sessions']),
      totalParticipants: _int(json['total_participants']),
      missingEmailCount: _int(json['missing_email_count']),
      warningCount: _int(json['warning_count']),
      errorCount: _int(json['error_count']),
      createdAt: _string(json['created_at']),
    );
  }
}

class TrainingAutomationSettings {
  const TrainingAutomationSettings({
    required this.autoRunAfterImport,
    required this.defaultEmailType,
    required this.includePopulation,
    required this.maxDraftsPerRun,
    required this.updatedAt,
  });

  final bool autoRunAfterImport;
  final String defaultEmailType;
  final bool includePopulation;
  final int maxDraftsPerRun;
  final String updatedAt;

  TrainingAutomationSettings copyWith({
    bool? autoRunAfterImport,
    String? defaultEmailType,
    bool? includePopulation,
    int? maxDraftsPerRun,
    String? updatedAt,
  }) {
    return TrainingAutomationSettings(
      autoRunAfterImport: autoRunAfterImport ?? this.autoRunAfterImport,
      defaultEmailType: defaultEmailType ?? this.defaultEmailType,
      includePopulation: includePopulation ?? this.includePopulation,
      maxDraftsPerRun: maxDraftsPerRun ?? this.maxDraftsPerRun,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory TrainingAutomationSettings.fromJson(Map<String, dynamic> json) {
    final maxDrafts = _int(json['max_drafts_per_run']);
    return TrainingAutomationSettings(
      autoRunAfterImport: _bool(json['auto_run_after_import']),
      defaultEmailType:
          _string(json['default_email_type']).isEmpty
              ? 'auto'
              : _string(json['default_email_type']),
      includePopulation: _bool(json['include_population']),
      maxDraftsPerRun: maxDrafts == 0 ? 100 : maxDrafts,
      updatedAt: _string(json['updated_at']),
    );
  }
}

class TrainingDraft {
  const TrainingDraft({
    required this.id,
    required this.importId,
    required this.sessionKey,
    required this.emailType,
    required this.subject,
    required this.body,
    required this.htmlBody,
    required this.recipients,
    required this.cc,
    required this.status,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String importId;
  final String sessionKey;
  final String emailType;
  final String subject;
  final String body;
  final String htmlBody;
  final List<String> recipients;
  final List<String> cc;
  final String status;
  final Map<String, dynamic> metadata;
  final String createdAt;
  final String updatedAt;

  bool get isApproved => status == 'APPROVED';
  bool get isSent => status == 'SENT';
  bool get needsContacts => status == 'NEEDS_CONTACTS';
  bool get isRejected => status == 'REJECTED';
  bool get canReview => !isApproved && !isRejected && !isSent;

  factory TrainingDraft.fromJson(Map<String, dynamic> json) {
    return TrainingDraft(
      id: _int(json['id']),
      importId: _string(json['import_id']),
      sessionKey: _string(json['session_key']),
      emailType: _string(json['email_type']),
      subject: _string(json['subject']),
      body: _string(json['body']),
      htmlBody: _string(json['html_body']),
      recipients: _stringList(json['recipients']),
      cc: _stringList(json['cc']),
      status: _string(json['status']),
      metadata: _map(json['metadata']),
      createdAt: _string(json['created_at']),
      updatedAt: _string(json['updated_at']),
    );
  }
}

class TrainingSendHistory {
  const TrainingSendHistory({
    required this.id,
    required this.draftId,
    required this.importId,
    required this.sessionKey,
    required this.emailType,
    required this.subject,
    required this.recipientEmail,
    required this.status,
    required this.providerMessageId,
    required this.error,
    required this.sentAt,
  });

  final int id;
  final int draftId;
  final String importId;
  final String sessionKey;
  final String emailType;
  final String subject;
  final String recipientEmail;
  final String status;
  final String providerMessageId;
  final String error;
  final String sentAt;

  bool get isSent => status.toLowerCase() == 'sent';
  bool get isError => status.toLowerCase() == 'error';

  factory TrainingSendHistory.fromJson(Map<String, dynamic> json) {
    return TrainingSendHistory(
      id: _int(json['id']),
      draftId: _int(json['draft_id']),
      importId: _string(json['import_id']),
      sessionKey: _string(json['session_key']),
      emailType: _string(json['email_type']),
      subject: _string(json['subject']),
      recipientEmail: _string(json['recipient_email']),
      status: _string(json['status']),
      providerMessageId: _string(json['provider_message_id']),
      error: _string(json['error']),
      sentAt: _string(json['sent_at']),
    );
  }
}

class MissingPlanningContact {
  const MissingPlanningContact({
    required this.matricule,
    required this.fullName,
    required this.direction,
    required this.hrResponsible,
    required this.sessionCount,
  });

  final String matricule;
  final String fullName;
  final String direction;
  final String hrResponsible;
  final int sessionCount;

  factory MissingPlanningContact.fromJson(Map<String, dynamic> json) {
    return MissingPlanningContact(
      matricule: _string(json['matricule']),
      fullName: _string(json['full_name']),
      direction: _string(json['direction']),
      hrResponsible: _string(json['hr_responsible']),
      sessionCount: _int(json['session_count']),
    );
  }
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _string(Object? value) => value?.toString() ?? '';

List<String> _stringList(Object? value) {
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

bool _bool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    return {'1', 'true', 'yes', 'on'}.contains(value.toLowerCase().trim());
  }
  return false;
}
