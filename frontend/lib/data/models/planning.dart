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
    required this.files,
  });

  final String importId;
  final String status;
  final int totalSessions;
  final int totalParticipants;
  final int missingEmailCount;
  final int warningCount;
  final int errorCount;
  final String createdAt;
  final List<PlanningImportFileSummary> files;

  bool get hasIssues =>
      status == 'error' ||
      status == 'needs_review' ||
      missingEmailCount > 0 ||
      warningCount > 0 ||
      errorCount > 0;

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
      files:
          _list(json['files'])
              .map((item) => PlanningImportFileSummary.fromJson(_map(item)))
              .toList(),
    );
  }
}

class PlanningImportFileSummary {
  const PlanningImportFileSummary({
    required this.filename,
    required this.status,
    required this.sessionCount,
    required this.warnings,
    required this.errors,
  });

  final String filename;
  final String status;
  final int sessionCount;
  final List<String> warnings;
  final List<String> errors;

  bool get hasIssues => warnings.isNotEmpty || errors.isNotEmpty;

  factory PlanningImportFileSummary.fromJson(Map<String, dynamic> json) {
    return PlanningImportFileSummary(
      filename: _string(json['filename']),
      status: _string(json['status']),
      sessionCount: _list(json['sessions']).length,
      warnings: _stringList(json['warnings']),
      errors: _stringList(json['errors']),
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

class TrainingCalendarSession {
  const TrainingCalendarSession({
    required this.importId,
    required this.sessionKey,
    required this.codeSession,
    required this.status,
    required this.module,
    required this.cabinet,
    required this.trainer,
    required this.trainingMode,
    required this.startDate,
    required this.endDate,
    required this.schedule,
    required this.location,
    required this.participantCount,
    required this.plannedCandidateCount,
    required this.missingEmailCount,
  });

  final String importId;
  final String sessionKey;
  final String codeSession;
  final String status;
  final String module;
  final String cabinet;
  final String trainer;
  final String trainingMode;
  final String startDate;
  final String endDate;
  final String schedule;
  final String location;
  final int participantCount;
  final int plannedCandidateCount;
  final int missingEmailCount;

  bool get hasMissingContacts => missingEmailCount > 0;
  bool get hasDetailedParticipants => participantCount > 0;
  bool get hasPlannedCandidatesOnly =>
      participantCount == 0 && plannedCandidateCount > 0;
  int get displayCandidateCount =>
      participantCount > 0 ? participantCount : plannedCandidateCount;

  factory TrainingCalendarSession.fromJson(Map<String, dynamic> json) {
    return TrainingCalendarSession(
      importId: _string(json['import_id']),
      sessionKey: _string(json['session_key']),
      codeSession: _string(json['code_session']),
      status: _string(json['status']),
      module: _string(json['module']),
      cabinet: _string(json['cabinet']),
      trainer:
          _string(json['trainer']).isEmpty
              ? _string(json['selected_trainer'])
              : _string(json['trainer']),
      trainingMode: _string(json['training_mode']),
      startDate: _string(json['start_date']),
      endDate: _string(json['end_date']),
      schedule: _string(json['schedule']),
      location: _string(json['location']),
      participantCount: _int(json['participant_count']),
      plannedCandidateCount: _int(json['candidate_count']),
      missingEmailCount: _int(json['missing_email_count']),
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

class PlanningContactReviewSummary {
  const PlanningContactReviewSummary({
    required this.total,
    required this.matched,
    required this.review,
    required this.missing,
    required this.contacts,
  });

  final int total;
  final int matched;
  final int review;
  final int missing;
  final List<PlanningContactReview> contacts;

  int get needsReview => review + missing;

  factory PlanningContactReviewSummary.fromJson(Map<String, dynamic> json) {
    return PlanningContactReviewSummary(
      total: _int(json['total']),
      matched: _int(json['matched']),
      review: _int(json['review']),
      missing: _int(json['missing']),
      contacts:
          _list(
            json['contacts'],
          ).map((item) => PlanningContactReview.fromJson(_map(item))).toList(),
    );
  }
}

class PlanningContactReview {
  const PlanningContactReview({
    required this.matricule,
    required this.fullName,
    required this.email,
    required this.suggestedEmail,
    required this.direction,
    required this.hrResponsible,
    required this.matchMethod,
    required this.status,
    required this.needsReview,
    required this.reason,
    required this.contactSource,
    required this.sessionCount,
    required this.sessions,
  });

  final String matricule;
  final String fullName;
  final String email;
  final String suggestedEmail;
  final String direction;
  final String hrResponsible;
  final String matchMethod;
  final String status;
  final bool needsReview;
  final String reason;
  final String contactSource;
  final int sessionCount;
  final List<PlanningContactReviewSession> sessions;

  String get displayEmail => email.isNotEmpty ? email : suggestedEmail;
  bool get isMissing => status == 'missing';
  bool get isNameMatch => matchMethod == 'name';

  factory PlanningContactReview.fromJson(Map<String, dynamic> json) {
    return PlanningContactReview(
      matricule: _string(json['matricule']),
      fullName: _string(json['full_name']),
      email: _string(json['email']),
      suggestedEmail: _string(json['suggested_email']),
      direction: _string(json['direction']),
      hrResponsible: _string(json['hr_responsible']),
      matchMethod: _string(json['match_method']),
      status: _string(json['status']),
      needsReview: _bool(json['needs_review']),
      reason: _string(json['reason']),
      contactSource: _string(json['contact_source']),
      sessionCount: _int(json['session_count']),
      sessions:
          _list(json['sessions'])
              .map((item) => PlanningContactReviewSession.fromJson(_map(item)))
              .toList(),
    );
  }
}

class PlanningContactReviewSession {
  const PlanningContactReviewSession({
    required this.sessionKey,
    required this.module,
    required this.startDate,
    required this.endDate,
  });

  final String sessionKey;
  final String module;
  final String startDate;
  final String endDate;

  factory PlanningContactReviewSession.fromJson(Map<String, dynamic> json) {
    return PlanningContactReviewSession(
      sessionKey: _string(json['session_key']),
      module: _string(json['module']),
      startDate: _string(json['start_date']),
      endDate: _string(json['end_date']),
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

List<dynamic> _list(Object? value) => value is List ? value : const [];

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
