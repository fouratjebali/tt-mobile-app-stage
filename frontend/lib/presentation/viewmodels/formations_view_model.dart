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
  List<PlanningImportSummary> imports = const [];
  List<TrainingDraft> drafts = const [];
  List<MissingPlanningContact> missingContacts = const [];

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
  int get blockedCount =>
      drafts.where((draft) => draft.status == 'NEEDS_CONTACTS').length;

  Future<void> load() async {
    state = LoadState.loading;
    errorMessage = null;
    notifyListeners();
    try {
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
      activeImport = await _planningApiService.importPlanningFiles(
        files: files,
      );
      imports = [
        activeImport!,
        ...imports.where((item) => item.importId != activeImport!.importId),
      ];
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
      drafts = await _planningApiService.listDrafts(importId: importId);
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
    final updated = await _planningApiService.sendDraft(draft.id);
    _replaceDraft(updated);
    return updated;
  }

  Future<void> _loadDetails() async {
    final importId = activeImport?.importId;
    if (importId == null || importId.isEmpty) {
      drafts = const [];
      missingContacts = const [];
      return;
    }
    drafts = await _planningApiService.listDrafts(importId: importId);
    missingContacts = await _planningApiService.listMissingContacts(
      importId: importId,
    );
  }

  void _replaceDraft(TrainingDraft updated) {
    drafts =
        drafts
            .map((draft) => draft.id == updated.id ? updated : draft)
            .toList();
    notifyListeners();
  }
}
