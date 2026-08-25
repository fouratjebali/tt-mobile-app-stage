import 'package:flutter/foundation.dart';
import 'package:tt_mail_assistant/core/state/load_state.dart';
import 'package:tt_mail_assistant/data/models/planning.dart';
import 'package:tt_mail_assistant/data/services/planning_api_service.dart';

class FormationsViewModel extends ChangeNotifier {
  FormationsViewModel({required PlanningApiService planningApiService})
    : _planningApiService = planningApiService;

  final PlanningApiService _planningApiService;

  LoadState state = LoadState.idle;
  String? errorMessage;
  PlanningImportSummary? activeImport;
  PlanningImportSummary? lastImportResult;
  TrainingAutomationSettings? automationSettings;
  List<PlanningImportSummary> imports = const [];
  List<TrainingDraft> drafts = const [];
  List<TrainingSendHistory> sendHistory = const [];
  List<MissingPlanningContact> missingContacts = const [];
  PlanningContactReviewSummary? contactReviewSummary;
  List<PlanningContactReview> contactReviews = const [];
  Map<String, dynamic>? lastAutomation;
  String draftStatusFilter = 'all';
  String draftEmailTypeFilter = 'all';

  int get sessions => activeImport?.totalSessions ?? 0;
  int get participants => activeImport?.totalParticipants ?? 0;
  int get missingCount => activeImport?.missingEmailCount ?? 0;
  int get draftsCount => drafts.length;
  int get waitingReviewCount =>
      drafts
          .where(
            (draft) =>
                draft.status == 'WAITING_REVIEW' || draft.status == 'EDITED',
          )
          .length;
  int get approvedCount =>
      drafts.where((draft) => draft.status == 'APPROVED').length;
  int get sentCount => drafts.where((draft) => draft.status == 'SENT').length;
  int get sentHistoryCount => sendHistory.where((item) => item.isSent).length;
  int get blockedCount =>
      drafts.where((draft) => draft.status == 'NEEDS_CONTACTS').length;
  int get contactReviewCount => contactReviewSummary?.needsReview ?? 0;
  int get contactMatchedCount => contactReviewSummary?.matched ?? 0;

  Future<void> load() async {
    state = LoadState.loading;
    errorMessage = null;
    notifyListeners();
    try {
      automationSettings = await _planningApiService.getAutomationSettings();
      imports = await _planningApiService.listImports();
      activeImport = imports.isNotEmpty ? imports.first : null;
      await _loadDetails();
      state = LoadState.success;
    } catch (error) {
      errorMessage = error.toString();
      state = LoadState.error;
    }
    notifyListeners();
  }

  Future<void> importFiles(List<PlanningPickedFile> files) async {
    state = LoadState.loading;
    errorMessage = null;
    notifyListeners();
    try {
      lastImportResult = null;
      automationSettings ??= await _planningApiService.getAutomationSettings();
      final imported = await _planningApiService.importPlanningFiles(
        files: files,
      );
      lastImportResult = imported;
      activeImport = imported;
      imports = [
        activeImport!,
        ...imports.where((item) => item.importId != activeImport!.importId),
      ];
      if (automationSettings?.autoRunAfterImport ?? true) {
        lastAutomation = await _planningApiService.runAutomation(
          importId: activeImport!.importId,
        );
      } else {
        lastAutomation = null;
      }
      imports = await _planningApiService.listImports();
      activeImport = imports.firstWhere(
        (item) => item.importId == activeImport!.importId,
        orElse: () => activeImport!,
      );
      await _loadDetails();
      state = LoadState.success;
    } catch (error) {
      errorMessage = error.toString();
      state = LoadState.error;
    }
    notifyListeners();
  }

  Future<PlanningImportSummary?> previewImportFiles(
    List<PlanningPickedFile> files,
  ) async {
    state = LoadState.loading;
    errorMessage = null;
    notifyListeners();
    try {
      final preview = await _planningApiService.previewPlanningFiles(
        files: files,
      );
      state = LoadState.success;
      return preview;
    } catch (error) {
      errorMessage = error.toString();
      state = LoadState.error;
      return null;
    } finally {
      notifyListeners();
    }
  }

  Future<void> importContactFiles(List<PlanningPickedFile> files) async {
    state = LoadState.loading;
    errorMessage = null;
    notifyListeners();
    try {
      await _planningApiService.importContactFiles(files: files);
      final importId = activeImport?.importId;
      if (importId != null && importId.isNotEmpty) {
        await _planningApiService.applyContactMapping(importId: importId);
      }
      await _loadDetails();
      state = LoadState.success;
    } catch (error) {
      errorMessage = error.toString();
      state = LoadState.error;
    }
    notifyListeners();
  }

  Future<void> generateDrafts({String emailType = 'auto'}) async {
    final importId = activeImport?.importId;
    if (importId == null || importId.isEmpty) return;
    state = LoadState.loading;
    errorMessage = null;
    notifyListeners();
    try {
      await _planningApiService.generateDrafts(
        importId: importId,
        emailType: emailType,
      );
      drafts = await _loadDraftsForImport(importId);
      state = LoadState.success;
    } catch (error) {
      errorMessage = error.toString();
      state = LoadState.error;
    }
    notifyListeners();
  }

  Future<void> runAutomation({String emailType = 'auto'}) async {
    final importId = activeImport?.importId;
    if (importId == null || importId.isEmpty) return;
    state = LoadState.loading;
    errorMessage = null;
    notifyListeners();
    try {
      lastAutomation = await _planningApiService.runAutomation(
        importId: importId,
        emailType: emailType == 'auto' ? null : emailType,
      );
      imports = await _planningApiService.listImports();
      activeImport = imports.firstWhere(
        (item) => item.importId == importId,
        orElse: () => activeImport!,
      );
      await _loadDetails();
      state = LoadState.success;
    } catch (error) {
      errorMessage = error.toString();
      state = LoadState.error;
    }
    notifyListeners();
  }

  Future<void> setDraftStatusFilter(String value) async {
    if (draftStatusFilter == value) return;
    draftStatusFilter = value;
    await _reloadDrafts();
  }

  Future<void> setDraftEmailTypeFilter(String value) async {
    if (draftEmailTypeFilter == value) return;
    draftEmailTypeFilter = value;
    await _reloadDrafts();
  }

  Future<void> saveAutomationSettings(
    TrainingAutomationSettings settings,
  ) async {
    state = LoadState.loading;
    errorMessage = null;
    notifyListeners();
    try {
      automationSettings = await _planningApiService.updateAutomationSettings(
        autoRunAfterImport: settings.autoRunAfterImport,
        defaultEmailType: settings.defaultEmailType,
        includePopulation: settings.includePopulation,
        maxDraftsPerRun: settings.maxDraftsPerRun,
      );
      state = LoadState.success;
    } catch (error) {
      errorMessage = error.toString();
      state = LoadState.error;
    }
    notifyListeners();
  }

  Future<TrainingDraft> saveDraft({
    required TrainingDraft draft,
    required String subject,
    required String body,
    required List<String> recipients,
    required List<String> cc,
  }) async {
    final updated = await _planningApiService.updateDraft(
      draftId: draft.id,
      subject: subject,
      body: body,
      recipients: recipients,
      cc: cc,
    );
    _replaceDraft(updated);
    return updated;
  }

  Future<TrainingDraft> regenerateDraft(
    TrainingDraft draft, {
    String emailType = 'auto',
    bool includePopulation = true,
  }) async {
    final updated = await _planningApiService.regenerateDraft(
      draftId: draft.id,
      emailType: emailType,
      includePopulation: includePopulation,
    );
    _replaceDraft(updated);
    return updated;
  }

  Future<TrainingDraft> approveDraft(TrainingDraft draft) async {
    final updated = await _planningApiService.approveDraft(draft.id);
    _replaceDraft(updated);
    return updated;
  }

  Future<TrainingDraft> rejectDraft(
    TrainingDraft draft, {
    String reason = '',
  }) async {
    final updated = await _planningApiService.rejectDraft(
      draft.id,
      reason: reason,
    );
    _replaceDraft(updated);
    return updated;
  }

  Future<TrainingDraft> sendDraft(TrainingDraft draft) async {
    final updated = await _planningApiService.sendDraft(
      draftId: draft.id,
      confirmedRecipientCount: draft.recipients.length,
      confirmedSubject: draft.subject,
    );
    _replaceDraft(updated);
    final importId = activeImport?.importId;
    if (importId != null && importId.isNotEmpty) {
      sendHistory = await _planningApiService.listSendHistory(
        importId: importId,
      );
    }
    return updated;
  }

  Future<void> saveMissingContact({
    required MissingPlanningContact contact,
    required String email,
  }) async {
    await _planningApiService.saveContact(
      matricule: contact.matricule,
      fullName: contact.fullName,
      email: email,
      direction: contact.direction,
      hrResponsible: contact.hrResponsible,
    );
    final importId = activeImport?.importId;
    if (importId != null && importId.isNotEmpty) {
      await _planningApiService.applyContactMapping(importId: importId);
    }
    await _loadDetails();
    notifyListeners();
  }

  Future<void> saveReviewedContact({
    required PlanningContactReview contact,
    required String email,
  }) async {
    await _planningApiService.saveContact(
      matricule: contact.matricule,
      fullName: contact.fullName,
      email: email,
      direction: contact.direction,
      hrResponsible: contact.hrResponsible,
    );
    final importId = activeImport?.importId;
    if (importId != null && importId.isNotEmpty) {
      await _planningApiService.applyContactMapping(importId: importId);
    }
    await _loadDetails();
    notifyListeners();
  }

  Future<void> _loadDetails() async {
    final importId = activeImport?.importId;
    if (importId == null || importId.isEmpty) {
      drafts = const [];
      sendHistory = const [];
      missingContacts = const [];
      contactReviewSummary = null;
      contactReviews = const [];
      return;
    }
    drafts = await _loadDraftsForImport(importId);
    sendHistory = await _planningApiService.listSendHistory(importId: importId);
    missingContacts = await _planningApiService.listMissingContacts(
      importId: importId,
    );
    contactReviewSummary = await _planningApiService.listContactReview(
      importId: importId,
    );
    contactReviews = contactReviewSummary?.contacts ?? const [];
  }

  Future<void> _reloadDrafts() async {
    final importId = activeImport?.importId;
    if (importId == null || importId.isEmpty) return;
    state = LoadState.loading;
    errorMessage = null;
    notifyListeners();
    try {
      drafts = await _loadDraftsForImport(importId);
      state = LoadState.success;
    } catch (error) {
      errorMessage = error.toString();
      state = LoadState.error;
    }
    notifyListeners();
  }

  Future<List<TrainingDraft>> _loadDraftsForImport(String importId) {
    return _planningApiService.listDrafts(
      importId: importId,
      draftStatus: _draftStatusQuery(draftStatusFilter),
      emailType: _draftEmailTypeQuery(draftEmailTypeFilter),
    );
  }

  void _replaceDraft(TrainingDraft updated) {
    if (_draftMatchesFilters(updated)) {
      final exists = drafts.any((draft) => draft.id == updated.id);
      drafts =
          exists
              ? drafts
                  .map((draft) => draft.id == updated.id ? updated : draft)
                  .toList()
              : [updated, ...drafts];
    } else {
      drafts = drafts.where((draft) => draft.id != updated.id).toList();
    }
    notifyListeners();
  }

  bool _draftMatchesFilters(TrainingDraft draft) {
    final statusQuery = _draftStatusQuery(draftStatusFilter);
    if (statusQuery != null && !statusQuery.split(',').contains(draft.status)) {
      return false;
    }
    final emailTypeQuery = _draftEmailTypeQuery(draftEmailTypeFilter);
    if (emailTypeQuery != null && draft.emailType != emailTypeQuery) {
      return false;
    }
    return true;
  }
}

String? _draftStatusQuery(String filter) {
  return switch (filter) {
    'review' => 'WAITING_REVIEW,EDITED',
    'approved' => 'APPROVED',
    'sent' => 'SENT',
    'blocked' => 'NEEDS_CONTACTS',
    'rejected' => 'REJECTED',
    _ => null,
  };
}

String? _draftEmailTypeQuery(String filter) {
  return filter == 'all' ? null : filter;
}
