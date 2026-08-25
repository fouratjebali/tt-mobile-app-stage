import 'dart:typed_data';

import 'package:tt_mail_assistant/core/errors/error_message.dart';
import 'package:tt_mail_assistant/data/datasources/remote/api_service.dart';
import 'package:tt_mail_assistant/data/models/planning.dart';

class PlanningPickedFile {
  const PlanningPickedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class PlanningApiService {
  PlanningApiService({required ApiService apiService})
    : _apiService = apiService;

  final ApiService _apiService;
  static const _planningTimeout = Duration(minutes: 3);

  Future<PlanningImportSummary> previewPlanningFiles({
    required List<PlanningPickedFile> files,
  }) async {
    return _planningRequest(
      action: _PlanningAction.previewPlanning,
      request: () async {
        final data = await _apiService.uploadFiles(
          '/planning/import/preview',
          fieldName: 'files',
          files:
              files
                  .map(
                    (file) =>
                        ApiUploadFile(filename: file.name, bytes: file.bytes),
                  )
                  .toList(),
          timeout: _planningTimeout,
        );
        return PlanningImportSummary.fromJson(_map(data));
      },
    );
  }

  Future<PlanningImportSummary> importPlanningFiles({
    required List<PlanningPickedFile> files,
  }) async {
    return _planningRequest(
      action: _PlanningAction.importPlanning,
      request: () async {
        final data = await _apiService.uploadFiles(
          '/planning/import',
          fieldName: 'files',
          files:
              files
                  .map(
                    (file) =>
                        ApiUploadFile(filename: file.name, bytes: file.bytes),
                  )
                  .toList(),
          timeout: _planningTimeout,
        );
        return PlanningImportSummary.fromJson(_map(data));
      },
    );
  }

  Future<Map<String, dynamic>> importContactFiles({
    required List<PlanningPickedFile> files,
  }) async {
    return _planningRequest(
      action: _PlanningAction.importContacts,
      request: () async {
        final data = await _apiService.uploadFiles(
          '/planning/contacts/import',
          fieldName: 'files',
          files:
              files
                  .map(
                    (file) =>
                        ApiUploadFile(filename: file.name, bytes: file.bytes),
                  )
                  .toList(),
          timeout: _planningTimeout,
        );
        return _map(data);
      },
    );
  }

  Future<List<PlanningImportSummary>> listImports() async {
    return _planningRequest(
      action: _PlanningAction.loadPlanning,
      request: () async {
        final data = await _apiService.get('/planning/imports');
        if (data is List) {
          return data
              .map((item) => PlanningImportSummary.fromJson(_map(item)))
              .toList();
        }
        return const [];
      },
    );
  }

  Future<TrainingAutomationSettings> getAutomationSettings() async {
    return _planningRequest(
      action: _PlanningAction.loadPlanning,
      request: () async {
        final data = await _apiService.get('/planning/automation/settings');
        return TrainingAutomationSettings.fromJson(
          _map(_map(data)['settings']),
        );
      },
    );
  }

  Future<TrainingAutomationSettings> updateAutomationSettings({
    bool? autoRunAfterImport,
    String? defaultEmailType,
    bool? includePopulation,
    int? maxDraftsPerRun,
  }) async {
    return _planningRequest(
      action: _PlanningAction.saveAutomationSettings,
      request: () async {
        final data = await _apiService.patch(
          '/planning/automation/settings',
          body: {
            if (autoRunAfterImport != null)
              'auto_run_after_import': autoRunAfterImport,
            if (defaultEmailType != null)
              'default_email_type': defaultEmailType,
            if (includePopulation != null)
              'include_population': includePopulation,
            if (maxDraftsPerRun != null) 'max_drafts_per_run': maxDraftsPerRun,
          },
        );
        return TrainingAutomationSettings.fromJson(
          _map(_map(data)['settings']),
        );
      },
    );
  }

  Future<List<MissingPlanningContact>> listMissingContacts({
    String? importId,
  }) async {
    return _planningRequest(
      action: _PlanningAction.loadPlanning,
      request: () async {
        final data = await _apiService.get(
          '/planning/missing-contacts',
          queryParameters: {
            if (importId != null && importId.isNotEmpty) 'import_id': importId,
          },
        );
        final contacts = _list(_map(data)['contacts']);
        return contacts
            .map((item) => MissingPlanningContact.fromJson(_map(item)))
            .toList();
      },
    );
  }

  Future<PlanningContactReviewSummary> listContactReview({
    String? importId,
    bool reviewOnly = false,
  }) async {
    return _planningRequest(
      action: _PlanningAction.loadPlanning,
      request: () async {
        final data = await _apiService.get(
          '/planning/contact-review',
          queryParameters: {
            if (importId != null && importId.isNotEmpty) 'import_id': importId,
            'review_only': reviewOnly,
          },
        );
        return PlanningContactReviewSummary.fromJson(_map(data));
      },
    );
  }

  Future<List<TrainingCalendarSession>> listSessions({String? importId}) async {
    return _planningRequest(
      action: _PlanningAction.loadPlanning,
      request: () async {
        final data = await _apiService.get(
          '/planning/sessions',
          queryParameters: {
            if (importId != null && importId.isNotEmpty) 'import_id': importId,
            'limit': 500,
          },
        );
        final sessions = _list(_map(data)['sessions']);
        return sessions
            .map((item) => TrainingCalendarSession.fromJson(_map(item)))
            .toList();
      },
    );
  }

  Future<void> saveContact({
    required String matricule,
    required String fullName,
    required String email,
    String direction = '',
    String hrResponsible = '',
  }) async {
    await _planningRequest(
      action: _PlanningAction.saveContact,
      request: () async {
        await _apiService.post(
          '/planning/contacts',
          body: {
            'matricule': matricule,
            'full_name': fullName,
            'email': email,
            'direction': direction,
            'hr_responsible': hrResponsible,
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> applyContactMapping({String? importId}) async {
    return _planningRequest(
      action: _PlanningAction.saveContact,
      request: () async {
        final encodedImportId = Uri.encodeQueryComponent(importId ?? '');
        final path =
            encodedImportId.isEmpty
                ? '/planning/contacts/apply'
                : '/planning/contacts/apply?import_id=$encodedImportId';
        final data = await _apiService.post(
          path,
          body: const <String, dynamic>{},
        );
        return _map(data);
      },
    );
  }

  Future<List<TrainingDraft>> listDrafts({
    String? importId,
    String? draftStatus,
    String? emailType,
  }) async {
    return _planningRequest(
      action: _PlanningAction.loadPlanning,
      request: () async {
        final data = await _apiService.get(
          '/planning/drafts',
          queryParameters: {
            if (importId != null && importId.isNotEmpty) 'import_id': importId,
            if (draftStatus != null && draftStatus.isNotEmpty)
              'draft_status': draftStatus,
            if (emailType != null && emailType.isNotEmpty)
              'email_type': emailType,
          },
        );
        final drafts = _list(_map(data)['drafts']);
        return drafts
            .map((item) => TrainingDraft.fromJson(_map(item)))
            .toList();
      },
    );
  }

  Future<List<TrainingSendHistory>> listSendHistory({String? importId}) async {
    return _planningRequest(
      action: _PlanningAction.loadPlanning,
      request: () async {
        final data = await _apiService.get(
          '/planning/send-history',
          queryParameters: {
            if (importId != null && importId.isNotEmpty) 'import_id': importId,
          },
        );
        final history = _list(_map(data)['history']);
        return history
            .map((item) => TrainingSendHistory.fromJson(_map(item)))
            .toList();
      },
    );
  }

  Future<List<TrainingDraft>> generateDrafts({
    required String importId,
    String emailType = 'auto',
  }) async {
    return _planningRequest(
      action: _PlanningAction.generateDrafts,
      request: () async {
        final data = await _apiService.post(
          '/planning/drafts/generate',
          body: {
            'import_id': importId,
            'email_type': emailType,
            'include_population': true,
          },
          timeout: _planningTimeout,
        );
        final drafts = _list(_map(data)['drafts']);
        return drafts
            .map((item) => TrainingDraft.fromJson(_map(item)))
            .toList();
      },
    );
  }

  Future<Map<String, dynamic>> runAutomation({
    required String importId,
    String? emailType,
    bool? includePopulation,
    int? limit,
  }) async {
    return _planningRequest(
      action: _PlanningAction.runAutomation,
      request: () async {
        final data = await _apiService.post(
          '/planning/automation/run',
          body: {
            'import_id': importId,
            if (emailType != null) 'email_type': emailType,
            if (includePopulation != null)
              'include_population': includePopulation,
            if (limit != null) 'limit': limit,
          },
          timeout: _planningTimeout,
        );
        return _map(data);
      },
    );
  }

  Future<TrainingDraft> updateDraft({
    required int draftId,
    String? subject,
    String? body,
    String? htmlBody,
    List<String>? recipients,
    List<String>? cc,
  }) async {
    return _planningRequest(
      action: _PlanningAction.saveDraft,
      request: () async {
        final data = await _apiService.patch(
          '/planning/drafts/$draftId',
          body: {
            if (subject != null) 'subject': subject,
            if (body != null) 'body': body,
            if (htmlBody != null) 'html_body': htmlBody,
            if (recipients != null) 'recipients': recipients,
            if (cc != null) 'cc': cc,
          },
        );
        return TrainingDraft.fromJson(_map(_map(data)['draft']));
      },
    );
  }

  Future<TrainingDraft> regenerateDraft({
    required int draftId,
    String emailType = 'auto',
    bool includePopulation = true,
  }) async {
    return _planningRequest(
      action: _PlanningAction.regenerateDraft,
      request: () async {
        final data = await _apiService.post(
          '/planning/drafts/$draftId/regenerate',
          body: {
            'email_type': emailType,
            'include_population': includePopulation,
          },
          timeout: _planningTimeout,
        );
        return TrainingDraft.fromJson(_map(_map(data)['draft']));
      },
    );
  }

  Future<TrainingDraft> approveDraft(int draftId) async {
    return _planningRequest(
      action: _PlanningAction.approveDraft,
      request: () async {
        final data = await _apiService.post(
          '/planning/drafts/$draftId/approve',
        );
        return TrainingDraft.fromJson(_map(_map(data)['draft']));
      },
    );
  }

  Future<TrainingDraft> rejectDraft(int draftId, {String reason = ''}) async {
    return _planningRequest(
      action: _PlanningAction.rejectDraft,
      request: () async {
        final data = await _apiService.post(
          '/planning/drafts/$draftId/reject',
          body: {'reason': reason},
        );
        return TrainingDraft.fromJson(_map(_map(data)['draft']));
      },
    );
  }

  Future<TrainingDraft> sendDraft({
    required int draftId,
    required int confirmedRecipientCount,
    required String confirmedSubject,
  }) async {
    return _planningRequest(
      action: _PlanningAction.sendDraft,
      request: () async {
        final data = await _apiService.post(
          '/planning/drafts/$draftId/send',
          body: {
            'confirmed': true,
            'confirmed_recipient_count': confirmedRecipientCount,
            'confirmed_subject': confirmedSubject,
          },
        );
        return TrainingDraft.fromJson(_map(_map(data)['draft']));
      },
    );
  }

  Future<T> _planningRequest<T>({
    required Future<T> Function() request,
    required _PlanningAction action,
  }) async {
    try {
      return await request();
    } on ApiException catch (error) {
      throw UserFacingException(
        _planningMessage(error, action),
        statusCode: error.statusCode,
      );
    } catch (error) {
      throw UserFacingException(ErrorMessage.fromException(error));
    }
  }

  String _planningMessage(ApiException error, _PlanningAction action) {
    final message = error.message.trim();
    final lower = message.toLowerCase();

    if (error.statusCode == 401 || error.statusCode == 403) {
      return 'Your Outlook session expired. Sign in again, then retry the planning action.';
    }
    if (error.statusCode == 404) {
      return 'This planning item was not found. Refresh the formations screen and try again.';
    }
    if (error.statusCode >= 500) {
      if (lower.contains('outlook')) {
        return 'Outlook could not complete the send. Check your connection and retry from the send history.';
      }
      return 'The planning service had a problem. Please retry in a moment.';
    }
    if (lower.contains('not reachable') ||
        lower.contains('connection') ||
        lower.contains('backend')) {
      return 'The planning service is not reachable. Start the backend, then refresh Formations.';
    }
    if (lower.contains('taking longer') || lower.contains('timeout')) {
      return 'Planning is taking longer than expected. Large Excel files or draft generation can take a minute. Please retry.';
    }
    if (lower.contains('maximum of 5') ||
        lower.contains('maximum') && lower.contains('5')) {
      return 'You can upload up to 5 files at once. Remove extra files and try again.';
    }
    if (lower.contains('empty')) {
      return 'One selected file is empty. Choose the exported planning or contact file again.';
    }
    if (lower.contains('only .xlsx planning') ||
        lower.contains('unsupported planning file') ||
        lower.contains('xlsx planning')) {
      return 'Planning import accepts Excel .xlsx files only. Export the planning as .xlsx and upload it again.';
    }
    if (lower.contains('only .xlsx and .csv contact') ||
        lower.contains('unsupported contact file')) {
      return 'Contact import accepts .xlsx or .csv files only. Export the directory and upload it again.';
    }
    if (lower.contains('unable to read excel') ||
        lower.contains('could not be read')) {
      return 'The Excel file could not be read. Check that it is not protected or corrupted, then upload it again.';
    }
    if (lower.contains('no recognizable planning header') ||
        lower.contains('planning headers were not found')) {
      return 'The planning table headers were not found. The file should contain columns like Module, Date Debut, Date Fin, Lieu de formation, Matricule, and Nom & Prenom.';
    }
    if (lower.contains('no contact header') ||
        lower.contains('contact headers were not found')) {
      return 'The contact columns were not found. The directory should include Email plus Nom & Prenom or Matricule.';
    }
    if (lower.contains('no valid contacts')) {
      return 'No valid contacts were found. Each contact needs an email and either a matricule or a name.';
    }
    if (lower.contains('valid email')) {
      return 'Enter a valid email address before saving this contact.';
    }
    if (lower.contains('approved training drafts') ||
        lower.contains('only approved')) {
      return 'Approve this draft before sending it with Outlook.';
    }
    if (lower.contains('recipient')) {
      return 'This draft has no valid recipient yet. Complete the contact review first.';
    }
    if (lower.contains('send confirmation')) {
      return 'Confirm the recipients and subject before sending this draft.';
    }
    if (lower.contains('subject confirmation')) {
      return 'The draft changed before sending. Reopen it and confirm the latest subject.';
    }

    return switch (action) {
      _PlanningAction.previewPlanning =>
        'Unable to preview this planning file. Check the Excel format and try again.',
      _PlanningAction.importPlanning =>
        'Unable to import this planning file. Check the Excel format and try again.',
      _PlanningAction.importContacts =>
        'Unable to import the contact directory. Check the columns and try again.',
      _PlanningAction.generateDrafts =>
        'Unable to generate training drafts. Complete missing contacts, then try again.',
      _PlanningAction.runAutomation =>
        'Automation could not finish. Check contact matching and retry.',
      _PlanningAction.saveContact =>
        'Unable to save this contact. Check the email and try again.',
      _PlanningAction.saveDraft =>
        'Unable to save this draft. Refresh it and try again.',
      _PlanningAction.regenerateDraft =>
        'Unable to regenerate this draft. Refresh it and try again.',
      _PlanningAction.approveDraft =>
        'Unable to approve this draft. Complete recipients and try again.',
      _PlanningAction.rejectDraft =>
        'Unable to reject this draft. Refresh it and try again.',
      _PlanningAction.sendDraft =>
        'Unable to send this draft. Confirm the recipients and try again.',
      _PlanningAction.saveAutomationSettings =>
        'Unable to save automation settings. Check the values and try again.',
      _PlanningAction.loadPlanning =>
        message.isEmpty
            ? 'Unable to load planning data. Pull down to refresh.'
            : message,
    };
  }
}

enum _PlanningAction {
  loadPlanning,
  previewPlanning,
  importPlanning,
  importContacts,
  generateDrafts,
  runAutomation,
  saveAutomationSettings,
  saveContact,
  saveDraft,
  regenerateDraft,
  approveDraft,
  rejectDraft,
  sendDraft,
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<dynamic> _list(Object? value) => value is List ? value : const [];
