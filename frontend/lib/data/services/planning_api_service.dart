import 'dart:typed_data';

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

  Future<PlanningImportSummary> importPlanningFiles({
    required List<PlanningPickedFile> files,
  }) async {
    final data = await _apiService.uploadFiles(
      '/planning/import',
      fieldName: 'files',
      files:
          files
              .map(
                (file) => ApiUploadFile(filename: file.name, bytes: file.bytes),
              )
              .toList(),
      timeout: _planningTimeout,
    );
    return PlanningImportSummary.fromJson(_map(data));
  }

  Future<Map<String, dynamic>> importContactFiles({
    required List<PlanningPickedFile> files,
  }) async {
    final data = await _apiService.uploadFiles(
      '/planning/contacts/import',
      fieldName: 'files',
      files:
          files
              .map(
                (file) => ApiUploadFile(filename: file.name, bytes: file.bytes),
              )
              .toList(),
      timeout: _planningTimeout,
    );
    return _map(data);
  }

  Future<List<PlanningImportSummary>> listImports() async {
    final data = await _apiService.get('/planning/imports');
    if (data is List) {
      return data
          .map((item) => PlanningImportSummary.fromJson(_map(item)))
          .toList();
    }
    return const [];
  }

  Future<List<MissingPlanningContact>> listMissingContacts({
    String? importId,
  }) async {
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
  }

  Future<void> saveContact({
    required String matricule,
    required String fullName,
    required String email,
    String direction = '',
    String hrResponsible = '',
  }) async {
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
  }

  Future<Map<String, dynamic>> applyContactMapping({String? importId}) async {
    final encodedImportId = Uri.encodeQueryComponent(importId ?? '');
    final path =
        encodedImportId.isEmpty
            ? '/planning/contacts/apply'
            : '/planning/contacts/apply?import_id=$encodedImportId';
    final data = await _apiService.post(path, body: const <String, dynamic>{});
    return _map(data);
  }

  Future<List<TrainingDraft>> listDrafts({String? importId}) async {
    final data = await _apiService.get(
      '/planning/drafts',
      queryParameters: {
        if (importId != null && importId.isNotEmpty) 'import_id': importId,
      },
    );
    final drafts = _list(_map(data)['drafts']);
    return drafts.map((item) => TrainingDraft.fromJson(_map(item))).toList();
  }

  Future<List<TrainingDraft>> generateDrafts({
    required String importId,
    String emailType = 'auto',
  }) async {
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
    return drafts.map((item) => TrainingDraft.fromJson(_map(item))).toList();
  }

  Future<Map<String, dynamic>> runAutomation({
    required String importId,
    String emailType = 'auto',
  }) async {
    final data = await _apiService.post(
      '/planning/automation/run',
      body: {
        'import_id': importId,
        'email_type': emailType,
        'include_population': true,
      },
      timeout: _planningTimeout,
    );
    return _map(data);
  }

  Future<TrainingDraft> updateDraft({
    required int draftId,
    String? subject,
    String? body,
    String? htmlBody,
    List<String>? recipients,
    List<String>? cc,
  }) async {
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
  }

  Future<TrainingDraft> approveDraft(int draftId) async {
    final data = await _apiService.post('/planning/drafts/$draftId/approve');
    return TrainingDraft.fromJson(_map(_map(data)['draft']));
  }

  Future<TrainingDraft> rejectDraft(int draftId, {String reason = ''}) async {
    final data = await _apiService.post(
      '/planning/drafts/$draftId/reject',
      body: {'reason': reason},
    );
    return TrainingDraft.fromJson(_map(_map(data)['draft']));
  }

  Future<TrainingDraft> sendDraft(int draftId) async {
    final data = await _apiService.post('/planning/drafts/$draftId/send');
    return TrainingDraft.fromJson(_map(_map(data)['draft']));
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<dynamic> _list(Object? value) => value is List ? value : const [];
