import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/di/di.dart';
import 'package:tt_mail_assistant/core/localization/app_localizations.dart';
import 'package:tt_mail_assistant/core/state/load_state.dart';
import 'package:tt_mail_assistant/core/theme/app_palette.dart';
import 'package:tt_mail_assistant/data/models/planning.dart';
import 'package:tt_mail_assistant/data/services/planning_api_service.dart';
import 'package:tt_mail_assistant/presentation/viewmodels/formations_view_model.dart';
import 'package:tt_mail_assistant/presentation/widgets/app_bottom_navigation_bar.dart';

class FormationsScreen extends StatefulWidget {
  const FormationsScreen({super.key});

  @override
  State<FormationsScreen> createState() => _FormationsScreenState();
}

class _FormationsScreenState extends State<FormationsScreen> {
  late final FormationsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = getIt<FormationsViewModel>()..addListener(_onChanged);
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _pickPlanningFiles() async {
    final l10n = context.l10n;
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final picked =
        result.files
            .take(5)
            .map((file) {
              final bytes = file.bytes;
              if (bytes == null) return null;
              return PlanningPickedFile(name: file.name, bytes: bytes);
            })
            .whereType<PlanningPickedFile>()
            .toList();

    if (picked.isEmpty) {
      _showMessage(l10n.t('formations.pickError'));
      return;
    }
    if (result.files.length > 5) {
      _showMessage(l10n.t('formations.uploadLimit'));
    }

    final preview = await _viewModel.previewImportFiles(picked);
    if (!mounted || preview == null) return;
    final shouldImport = await _openImportPreview(preview);
    if (!mounted || shouldImport != true) return;

    await _viewModel.importFiles(picked);
    if (!mounted) return;
    if (_viewModel.errorMessage == null) {
      await _openImportFeedback();
    }
  }

  Future<void> _pickContactFiles() async {
    final l10n = context.l10n;
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final picked =
        result.files
            .take(5)
            .map((file) {
              final bytes = file.bytes;
              if (bytes == null) return null;
              return PlanningPickedFile(name: file.name, bytes: bytes);
            })
            .whereType<PlanningPickedFile>()
            .toList();

    if (picked.isEmpty) {
      _showMessage(l10n.t('formations.contactPickError'));
      return;
    }
    if (result.files.length > 5) {
      _showMessage(l10n.t('formations.uploadLimit'));
    }

    await _viewModel.importContactFiles(picked);
    if (!mounted) return;
    if (_viewModel.errorMessage == null) {
      _showMessage(l10n.t('formations.contactsImported'));
    }
  }

  Future<void> _generateDrafts() async {
    await _viewModel.generateDrafts(replaceExisting: true);
    if (!mounted) return;
    if (_viewModel.errorMessage == null) {
      _showMessage(context.l10n.t('formations.automationDone'));
    }
  }

  Future<void> _openAutomationSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AutomationSettingsSheet(viewModel: _viewModel),
    );
  }

  Future<bool?> _openImportPreview(PlanningImportSummary summary) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _ImportFeedbackSheet(
            summary: summary,
            automation: null,
            mode: _ImportFeedbackMode.preview,
          ),
    );
  }

  Future<void> _openImportFeedback() async {
    final summary = _viewModel.lastImportResult;
    if (summary == null) {
      _showMessage(context.l10n.t('formations.importDone'));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _ImportFeedbackSheet(
            summary: summary,
            automation: _viewModel.lastAutomation,
            mode: _ImportFeedbackMode.result,
          ),
    );
  }

  Future<void> _openDraft(TrainingDraft draft) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _DraftReviewSheet(viewModel: _viewModel, draft: draft),
    );
  }

  Future<void> _openContactReview(PlanningContactReview contact) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) =>
              _ContactFixSheet(viewModel: _viewModel, contact: contact),
    );
  }

  Future<void> _openPlanningImportPage() async {
    await _openFormationPage(
      _FormationDetailPage(
        viewModel: _viewModel,
        titleKey: 'formations.importPageTitle',
        subtitleKey: 'formations.importPageSubtitle',
        builder:
            (context, tone) => [
              _UploadPanel(onUpload: _pickPlanningFiles, tone: tone),
              const SizedBox(height: 14),
              _CandidateListPanel(onUpload: _pickContactFiles, tone: tone),
              const SizedBox(height: 18),
              _MonthOverview(viewModel: _viewModel, tone: tone),
              if (_viewModel.activeImport == null) ...[
                const SizedBox(height: 18),
                _EmptyPlanningState(tone: tone),
              ],
            ],
      ),
    );
  }

  Future<void> _openCalendarPage() async {
    await _openFormationPage(
      _FormationDetailPage(
        viewModel: _viewModel,
        titleKey: 'formations.calendarPageTitle',
        subtitleKey: 'formations.calendarPageSubtitle',
        builder:
            (context, tone) => [
              _TrainingCalendarSection(
                sessions: _viewModel.trainingSessions,
                tone: tone,
              ),
            ],
      ),
    );
  }

  Future<void> _openDraftsPage() async {
    await _openFormationPage(
      _FormationDetailPage(
        viewModel: _viewModel,
        titleKey: 'formations.draftsPageTitle',
        subtitleKey: 'formations.draftsPageSubtitle',
        builder:
            (context, tone) => [
              _ActionPanel(
                viewModel: _viewModel,
                tone: tone,
                onGenerate: _generateDrafts,
                onSettings: _openAutomationSettings,
              ),
              const SizedBox(height: 18),
              _DraftsSection(
                drafts: _viewModel.drafts,
                tone: tone,
                statusFilter: _viewModel.draftStatusFilter,
                emailTypeFilter: _viewModel.draftEmailTypeFilter,
                onStatusFilterChanged: _viewModel.setDraftStatusFilter,
                onEmailTypeFilterChanged: _viewModel.setDraftEmailTypeFilter,
                onOpen: _openDraft,
              ),
            ],
      ),
    );
  }

  Future<void> _openContactsPage() async {
    await _openFormationPage(
      _FormationDetailPage(
        viewModel: _viewModel,
        titleKey: 'formations.contactsPageTitle',
        subtitleKey: 'formations.contactsPageSubtitle',
        builder:
            (context, tone) => [
              _CandidateListPanel(onUpload: _pickContactFiles, tone: tone),
              const SizedBox(height: 18),
              _ContactMatchingReviewSection(
                summary: _viewModel.contactReviewSummary,
                contacts: _viewModel.contactReviews,
                tone: tone,
                onFix: _openContactReview,
              ),
            ],
      ),
    );
  }

  Future<void> _openSendHistoryPage() async {
    await _openFormationPage(
      _FormationDetailPage(
        viewModel: _viewModel,
        titleKey: 'formations.historyPageTitle',
        subtitleKey: 'formations.historyPageSubtitle',
        builder:
            (context, tone) => [
              _SendHistorySection(history: _viewModel.sendHistory, tone: tone),
            ],
      ),
    );
  }

  Future<void> _openFormationPage(Widget page) async {
    final selectedTab = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (selectedTab != null && mounted) {
      Navigator.of(context).pop(selectedTab);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tone = _FormationTone.of(context);
    final isLoading = _viewModel.state == LoadState.loading;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _viewModel.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _FormationHeader(
                onBack: () => Navigator.of(context).maybePop(),
                onRefresh: _viewModel.load,
              ),
              const SizedBox(height: 18),
              if (isLoading) const LinearProgressIndicator(minHeight: 3),
              if (_viewModel.errorMessage != null) ...[
                const SizedBox(height: 14),
                _InlineMessage(
                  icon: Icons.error_outline_rounded,
                  message: _viewModel.errorMessage!,
                  tone: tone,
                  accent: AppPalette.clay,
                ),
              ],
              const SizedBox(height: 18),
              _FormationHubSummary(viewModel: _viewModel, tone: tone),
              const SizedBox(height: 18),
              _FormationWorkflowSection(
                viewModel: _viewModel,
                tone: tone,
                onImport: _openPlanningImportPage,
                onContacts: _openContactsPage,
                onCalendar: _openCalendarPage,
                onDrafts: _openDraftsPage,
                onHistory: _openSendHistoryPage,
                onSettings: _openAutomationSettings,
              ),
              if (_viewModel.activeImport == null) ...[
                const SizedBox(height: 20),
                _EmptyPlanningState(tone: tone),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        selectedIndex: 0,
        reviewCount: 0,
        showAssistantSpace: false,
        items: _formationNavItems(l10n),
        onItemSelected: (index) => Navigator.of(context).pop(index),
      ),
    );
  }
}

class _FormationTone {
  const _FormationTone({
    required this.surface,
    required this.softSurface,
    required this.border,
    required this.text,
    required this.muted,
  });

  final Color surface;
  final Color softSurface;
  final Color border;
  final Color text;
  final Color muted;

  static _FormationTone of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _FormationTone(
      surface: isDark ? const Color(0xFF151C1A) : AppPalette.white,
      softSurface: isDark ? const Color(0xFF202A27) : AppPalette.sage,
      border:
          isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppPalette.line.withValues(alpha: 0.88),
      text: isDark ? AppPalette.white : AppPalette.ink,
      muted:
          isDark
              ? Colors.white.withValues(alpha: 0.66)
              : AppPalette.pine.withValues(alpha: 0.72),
    );
  }
}

List<AppNavigationItemData> _formationNavItems(AppLocalizations l10n) {
  return [
    AppNavigationItemData(
      label: l10n.t('nav.home'),
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    AppNavigationItemData(
      label: l10n.t('nav.today'),
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today_rounded,
    ),
    AppNavigationItemData(
      label: l10n.t('nav.review'),
      icon: Icons.mark_email_unread_outlined,
      activeIcon: Icons.mark_email_unread_rounded,
    ),
    AppNavigationItemData(
      label: l10n.t('nav.profile'),
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];
}

class _FormationDetailPage extends StatelessWidget {
  const _FormationDetailPage({
    required this.viewModel,
    required this.titleKey,
    required this.subtitleKey,
    required this.builder,
  });

  final FormationsViewModel viewModel;
  final String titleKey;
  final String subtitleKey;
  final List<Widget> Function(BuildContext context, _FormationTone tone)
  builder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tone = _FormationTone.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: viewModel,
          builder: (context, _) {
            final isLoading = viewModel.state == LoadState.loading;
            return RefreshIndicator(
              onRefresh: viewModel.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                children: [
                  _FormationDetailHeader(
                    title: l10n.t(titleKey),
                    subtitle: l10n.t(subtitleKey),
                    onBack: () => Navigator.of(context).maybePop(),
                    onRefresh: viewModel.load,
                  ),
                  const SizedBox(height: 18),
                  if (isLoading) const LinearProgressIndicator(minHeight: 3),
                  if (viewModel.errorMessage != null) ...[
                    const SizedBox(height: 14),
                    _InlineMessage(
                      icon: Icons.error_outline_rounded,
                      message: viewModel.errorMessage!,
                      tone: tone,
                      accent: AppPalette.clay,
                    ),
                  ],
                  const SizedBox(height: 18),
                  ...builder(context, tone),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        selectedIndex: 0,
        reviewCount: 0,
        showAssistantSpace: false,
        items: _formationNavItems(l10n),
        onItemSelected: (index) => Navigator.of(context).pop(index),
      ),
    );
  }
}

class _FormationDetailHeader extends StatelessWidget {
  const _FormationDetailHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onRefresh,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final tone = _FormationTone.of(context);
    final l10n = context.l10n;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton.filledTonal(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: l10n.t('common.back'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tone.text,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tone.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: l10n.t('formations.refresh'),
        ),
      ],
    );
  }
}

class _FormationHeader extends StatelessWidget {
  const _FormationHeader({required this.onBack, required this.onRefresh});

  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tone = _FormationTone.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton.filledTonal(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: l10n.t('common.back'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('formations.title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tone.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                l10n.t('formations.subtitle'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tone.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: l10n.t('formations.refresh'),
        ),
      ],
    );
  }
}

class _FormationHubSummary extends StatelessWidget {
  const _FormationHubSummary({required this.viewModel, required this.tone});

  final FormationsViewModel viewModel;
  final _FormationTone tone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasImport = viewModel.activeImport != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppPalette.deepTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: AppPalette.deepTeal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasImport
                          ? l10n.t('formations.activePlan')
                          : l10n.t('formations.noActivePlan'),
                      style: TextStyle(
                        color: tone.text,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasImport
                          ? l10n.t('formations.activePlanHint')
                          : l10n.t('formations.noActivePlanHint'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tone.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  label: l10n.t('formations.sessions'),
                  value: '${viewModel.sessions}',
                  tone: tone,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniMetric(
                  label: l10n.t('formations.responsibles'),
                  value: '${viewModel.responsibleCount}',
                  tone: tone,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniMetric(
                  label: l10n.t('formations.toReview'),
                  value: '${viewModel.actionableDraftCount}',
                  tone: tone,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormationWorkflowSection extends StatelessWidget {
  const _FormationWorkflowSection({
    required this.viewModel,
    required this.tone,
    required this.onImport,
    required this.onContacts,
    required this.onCalendar,
    required this.onDrafts,
    required this.onHistory,
    required this.onSettings,
  });

  final FormationsViewModel viewModel;
  final _FormationTone tone;
  final VoidCallback onImport;
  final VoidCallback onContacts;
  final VoidCallback onCalendar;
  final VoidCallback onDrafts;
  final VoidCallback onHistory;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('formations.workflowTitle'),
          style: TextStyle(
            color: tone.text,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        _WorkflowTile(
          icon: Icons.upload_file_rounded,
          title: l10n.t('formations.importStepTitle'),
          subtitle: l10n.t('formations.importStepSubtitle'),
          metric: '${viewModel.imports.length}',
          metricLabel: l10n.t('formations.imports'),
          tone: tone,
          color: AppPalette.deepTeal,
          onTap: onImport,
        ),
        const SizedBox(height: 10),
        _WorkflowTile(
          icon: Icons.contact_mail_rounded,
          title: l10n.t('formations.contactsStepTitle'),
          subtitle: l10n.t('formations.contactsStepSubtitle'),
          metric: '${viewModel.contactReviewCount}',
          metricLabel: l10n.t('formations.toCheck'),
          tone: tone,
          color:
              viewModel.contactReviewCount > 0
                  ? AppPalette.amber
                  : AppPalette.deepTeal,
          onTap: onContacts,
        ),
        const SizedBox(height: 10),
        _WorkflowTile(
          icon: Icons.calendar_month_rounded,
          title: l10n.t('formations.calendarStepTitle'),
          subtitle: l10n.t('formations.calendarStepSubtitle'),
          metric: '${viewModel.trainingSessions.length}',
          metricLabel: l10n.t('formations.sessions'),
          tone: tone,
          color: AppPalette.blue,
          onTap: onCalendar,
        ),
        const SizedBox(height: 10),
        _WorkflowTile(
          icon: Icons.edit_document,
          title: l10n.t('formations.draftsStepTitle'),
          subtitle: l10n.t('formations.draftsStepSubtitle'),
          metric: '${viewModel.waitingReviewCount}',
          metricLabel: l10n.t('formations.waitingReview'),
          tone: tone,
          color:
              viewModel.waitingReviewCount > 0
                  ? AppPalette.clay
                  : AppPalette.deepTeal,
          onTap: onDrafts,
        ),
        const SizedBox(height: 10),
        _WorkflowTile(
          icon: Icons.history_rounded,
          title: l10n.t('formations.historyStepTitle'),
          subtitle: l10n.t('formations.historyStepSubtitle'),
          metric: '${viewModel.sentHistoryCount}',
          metricLabel: l10n.t('formations.sent'),
          tone: tone,
          color: AppPalette.deepTeal,
          onTap: onHistory,
        ),
        const SizedBox(height: 10),
        _WorkflowTile(
          icon: Icons.tune_rounded,
          title: l10n.t('formations.settingsStepTitle'),
          subtitle: l10n.t('formations.settingsStepSubtitle'),
          metric: '',
          metricLabel: '',
          tone: tone,
          color: AppPalette.pine,
          onTap: onSettings,
        ),
      ],
    );
  }
}

class _WorkflowTile extends StatelessWidget {
  const _WorkflowTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.metric,
    required this.metricLabel,
    required this.tone,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String metric;
  final String metricLabel;
  final _FormationTone tone;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasMetric = metric.isNotEmpty && metricLabel.isNotEmpty;

    return Material(
      color: tone.surface,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: tone.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tone.text,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tone.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (hasMetric)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      metric,
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      metricLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tone.muted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                )
              else
                Icon(Icons.chevron_right_rounded, color: tone.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadPanel extends StatelessWidget {
  const _UploadPanel({required this.onUpload, required this.tone});

  final VoidCallback onUpload;
  final _FormationTone tone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppPalette.deepTeal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.upload_file_rounded,
              color: AppPalette.deepTeal,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('formations.uploadTitle'),
                  style: TextStyle(
                    color: tone.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  l10n.t('formations.uploadSubtitle'),
                  style: TextStyle(
                    color: tone.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            onPressed: onUpload,
            icon: const Icon(Icons.add_rounded),
            tooltip: l10n.t('formations.uploadAction'),
          ),
        ],
      ),
    );
  }
}

class _CandidateListPanel extends StatelessWidget {
  const _CandidateListPanel({required this.onUpload, required this.tone});

  final VoidCallback onUpload;
  final _FormationTone tone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.softSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppPalette.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.groups_2_rounded,
              color: AppPalette.blue,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('formations.contactsTitle'),
                  style: TextStyle(
                    color: tone.text,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.t('formations.contactsSubtitle'),
                  style: TextStyle(
                    color: tone.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            onPressed: onUpload,
            icon: const Icon(Icons.upload_rounded),
            tooltip: l10n.t('formations.contactsUpload'),
          ),
        ],
      ),
    );
  }
}

class _MonthOverview extends StatelessWidget {
  const _MonthOverview({required this.viewModel, required this.tone});

  final FormationsViewModel viewModel;
  final _FormationTone tone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('formations.monthPlan'),
          style: TextStyle(
            color: tone.text,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 1.48,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _FormationStatCard(
              icon: Icons.event_available_rounded,
              label: l10n.t('formations.sessions'),
              value: '${viewModel.sessions}',
            ),
            _FormationStatCard(
              icon: Icons.groups_2_rounded,
              label: l10n.t('formations.participants'),
              value: '${viewModel.participants}',
            ),
            _FormationStatCard(
              icon: Icons.supervisor_account_rounded,
              label: l10n.t('formations.responsibles'),
              value: '${viewModel.responsibleCount}',
            ),
            _FormationStatCard(
              icon: Icons.mark_email_unread_rounded,
              label: l10n.t('formations.missingResponsibleEmails'),
              value: '${viewModel.responsibleMissingCount}',
              accent: AppPalette.clay,
            ),
          ],
        ),
      ],
    );
  }
}

class _FormationStatCard extends StatelessWidget {
  const _FormationStatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = AppPalette.deepTeal,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final tone = _FormationTone.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: accent, size: 23),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: accent,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tone.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.viewModel,
    required this.tone,
    required this.onGenerate,
    required this.onSettings,
  });

  final FormationsViewModel viewModel;
  final _FormationTone tone;
  final VoidCallback onGenerate;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasImport = viewModel.activeImport != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.softSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.t('formations.reviewBeforeSend'),
                  style: TextStyle(
                    color: tone.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: onSettings,
                icon: const Icon(Icons.tune_rounded),
                tooltip: l10n.t('formations.automationSettings'),
              ),
              const SizedBox(width: 4),
              _StatusPill(
                label:
                    hasImport
                        ? l10n.t('formations.importReady')
                        : l10n.t('formations.waitingImport'),
                color: hasImport ? AppPalette.deepTeal : AppPalette.amber,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.t('formations.reviewBeforeSendHint'),
            style: TextStyle(
              color: tone.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: hasImport ? onGenerate : null,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text(l10n.t('formations.runAutomation')),
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.deepTeal,
                foregroundColor: AppPalette.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  label: l10n.t('formations.waitingReview'),
                  value: '${viewModel.waitingReviewCount}',
                  tone: tone,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniMetric(
                  label: l10n.t('formations.approved'),
                  value: '${viewModel.approvedCount}',
                  tone: tone,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniMetric(
                  label: l10n.t('formations.blocked'),
                  value: '${viewModel.blockedCount}',
                  tone: tone,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final _FormationTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: tone.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppPalette.deepTeal,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tone.muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingCalendarSection extends StatefulWidget {
  const _TrainingCalendarSection({required this.sessions, required this.tone});

  final List<TrainingCalendarSession> sessions;
  final _FormationTone tone;

  @override
  State<_TrainingCalendarSection> createState() =>
      _TrainingCalendarSectionState();
}

class _TrainingCalendarSectionState extends State<_TrainingCalendarSection> {
  static const double _monthChipWidth = 112;
  static const double _monthChipSpacing = 8;
  static const int _sessionsPerPage = 8;
  static const int _startYear = 2024;
  static const int _endYear = 2027;

  final ScrollController _monthScrollController = ScrollController();
  int? _selectedYear;
  int? _selectedMonth;
  int _page = 0;
  String? _lastAlignedMonthKey;

  @override
  void dispose() {
    _monthScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _TrainingCalendarSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sessions == oldWidget.sessions) return;
    if (_selectedYear != null &&
        (_selectedYear! < _startYear || _selectedYear! > _endYear)) {
      _selectedYear = null;
    }
    _page = 0;
    _lastAlignedMonthKey = null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sessions = widget.sessions;
    final sortedSessions = _sortSessionsByDate(sessions);
    final selectedYear = _selectedYear ?? _defaultCalendarYear(sortedSessions);
    final selectedMonth =
        _selectedMonth ??
        _defaultCalendarMonthNumber(sortedSessions, selectedYear);
    final selectedDate = DateTime(selectedYear, selectedMonth);
    final monthSessions = _sessionsForMonth(sortedSessions, selectedDate);
    final pageCount = _calendarPageCount(
      monthSessions.length,
      _sessionsPerPage,
    );
    final pageIndex = _page.clamp(0, pageCount - 1).toInt();
    final pageSessions =
        monthSessions
            .skip(pageIndex * _sessionsPerPage)
            .take(_sessionsPerPage)
            .toList();
    _alignSelectedMonth(selectedMonth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: l10n.t('formations.calendarTitle'),
          count: monthSessions.length,
          tone: widget.tone,
        ),
        const SizedBox(height: 8),
        Text(
          l10n
              .t('formations.calendarSubtitle')
              .replaceAll('{count}', '${monthSessions.length}'),
          style: TextStyle(
            color: widget.tone.muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        if (sessions.isEmpty)
          _InlineMessage(
            icon: Icons.calendar_month_outlined,
            message: l10n.t('formations.noCalendarSessions'),
            tone: widget.tone,
          )
        else ...[
          Text(
            l10n.t('formations.calendarYear'),
            style: TextStyle(
              color: widget.tone.text,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _endYear - _startYear + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final year = _startYear + index;
                final count = _sessionsForYear(sessions, year).length;
                return _CalendarYearChip(
                  year: year,
                  count: count,
                  selected: year == selectedYear,
                  tone: widget.tone,
                  onTap:
                      () => setState(() {
                        _selectedYear = year;
                        _selectedMonth = _defaultCalendarMonthNumber(
                          sortedSessions,
                          year,
                        );
                        _page = 0;
                        _lastAlignedMonthKey = null;
                      }),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.t('formations.calendarMonth'),
            style: TextStyle(
              color: widget.tone.text,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView.separated(
              controller: _monthScrollController,
              scrollDirection: Axis.horizontal,
              itemCount: 12,
              separatorBuilder:
                  (_, __) => const SizedBox(width: _monthChipSpacing),
              itemBuilder: (context, index) {
                final month = DateTime(selectedYear, index + 1);
                final count = _sessionsForMonth(sessions, month).length;
                return _CalendarMonthChip(
                  month: month,
                  count: count,
                  selected: month.month == selectedMonth,
                  tone: widget.tone,
                  onTap:
                      () => setState(() {
                        _selectedMonth = month.month;
                        _page = 0;
                      }),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (monthSessions.isEmpty)
            _InlineMessage(
              icon: Icons.event_busy_outlined,
              message: l10n.t('formations.noSessionsForMonth'),
              tone: widget.tone,
            )
          else ...[
            _CalendarPaginationControls(
              pageIndex: pageIndex,
              pageCount: pageCount,
              totalCount: monthSessions.length,
              pageSize: _sessionsPerPage,
              tone: widget.tone,
              onPrevious:
                  pageIndex == 0
                      ? null
                      : () => setState(() => _page = pageIndex - 1),
              onNext:
                  pageIndex >= pageCount - 1
                      ? null
                      : () => setState(() => _page = pageIndex + 1),
            ),
            const SizedBox(height: 12),
            for (final session in pageSessions) ...[
              _TrainingSessionCard(session: session, tone: widget.tone),
              const SizedBox(height: 10),
            ],
            if (pageCount > 1) ...[
              const SizedBox(height: 2),
              _CalendarPaginationControls(
                pageIndex: pageIndex,
                pageCount: pageCount,
                totalCount: monthSessions.length,
                pageSize: _sessionsPerPage,
                tone: widget.tone,
                onPrevious:
                    pageIndex == 0
                        ? null
                        : () => setState(() => _page = pageIndex - 1),
                onNext:
                    pageIndex >= pageCount - 1
                        ? null
                        : () => setState(() => _page = pageIndex + 1),
              ),
            ],
          ],
        ],
      ],
    );
  }

  void _alignSelectedMonth(int selectedMonth) {
    final key =
        '${_selectedYear ?? _defaultCalendarYear(widget.sessions)}-$selectedMonth';
    if (_lastAlignedMonthKey == key) return;
    final index = selectedMonth - 1;
    _lastAlignedMonthKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_monthScrollController.hasClients) return;
      final maxOffset = _monthScrollController.position.maxScrollExtent;
      final target = index * (_monthChipWidth + _monthChipSpacing);
      _monthScrollController.jumpTo(target.clamp(0.0, maxOffset));
    });
  }
}

class _CalendarYearChip extends StatelessWidget {
  const _CalendarYearChip({
    required this.year,
    required this.count,
    required this.selected,
    required this.tone,
    required this.onTap,
  });

  final int year;
  final int count;
  final bool selected;
  final _FormationTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = selected ? AppPalette.deepTeal : tone.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 96,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color:
              selected
                  ? AppPalette.deepTeal.withValues(alpha: 0.12)
                  : tone.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                selected
                    ? AppPalette.deepTeal.withValues(alpha: 0.55)
                    : tone.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$year',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 6),
            _CalendarCountBadge(count: count, color: accent),
          ],
        ),
      ),
    );
  }
}

class _CalendarMonthChip extends StatelessWidget {
  const _CalendarMonthChip({
    required this.month,
    required this.count,
    required this.selected,
    required this.tone,
    required this.onTap,
  });

  final DateTime month;
  final int count;
  final bool selected;
  final _FormationTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = selected ? AppPalette.deepTeal : tone.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: _TrainingCalendarSectionState._monthChipWidth,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color:
              selected
                  ? AppPalette.deepTeal.withValues(alpha: 0.12)
                  : tone.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                selected
                    ? AppPalette.deepTeal.withValues(alpha: 0.55)
                    : tone.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _formatMonthLabel(context, month),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 6),
            _CalendarCountBadge(count: count, color: accent),
          ],
        ),
      ),
    );
  }
}

class _CalendarCountBadge extends StatelessWidget {
  const _CalendarCountBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _CalendarPaginationControls extends StatelessWidget {
  const _CalendarPaginationControls({
    required this.pageIndex,
    required this.pageCount,
    required this.totalCount,
    required this.pageSize,
    required this.tone,
    required this.onPrevious,
    required this.onNext,
  });

  final int pageIndex;
  final int pageCount;
  final int totalCount;
  final int pageSize;
  final _FormationTone tone;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final start = totalCount == 0 ? 0 : pageIndex * pageSize + 1;
    final end =
        totalCount == 0
            ? 0
            : ((pageIndex + 1) * pageSize).clamp(0, totalCount).toInt();
    final summary = l10n
        .t('formations.calendarPageSummary')
        .replaceAll('{start}', '$start')
        .replaceAll('{end}', '$end')
        .replaceAll('{total}', '$totalCount');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tone.softSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.border),
      ),
      child: Row(
        children: [
          _CalendarPageButton(
            icon: Icons.chevron_left_rounded,
            enabled: onPrevious != null,
            tooltip: l10n.t('formations.previousPage'),
            onTap: onPrevious,
          ),
          Expanded(
            child: Text(
              pageCount <= 1
                  ? summary
                  : '$summary - ${pageIndex + 1}/$pageCount',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tone.muted,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _CalendarPageButton(
            icon: Icons.chevron_right_rounded,
            enabled: onNext != null,
            tooltip: l10n.t('formations.nextPage'),
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class _CalendarPageButton extends StatelessWidget {
  const _CalendarPageButton({
    required this.icon,
    required this.enabled,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppPalette.deepTeal : Colors.grey;
    return Tooltip(
      message: tooltip,
      child: IconButton.filledTonal(
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          backgroundColor: color.withValues(alpha: enabled ? 0.12 : 0.08),
          foregroundColor: color,
        ),
        onPressed: onTap,
        icon: Icon(icon),
      ),
    );
  }
}

class _TrainingSessionCard extends StatelessWidget {
  const _TrainingSessionCard({required this.session, required this.tone});

  final TrainingCalendarSession session;
  final _FormationTone tone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dateLabel = _formatSessionDateRange(
      context,
      session.startDate,
      session.endDate,
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppPalette.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: AppPalette.blue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.module.isEmpty
                          ? l10n.t('formations.unknownModule')
                          : session.module,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tone.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      dateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tone.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (session.hasMissingContacts)
                _StatusPill(
                  label: l10n.t('formations.calendarMissing'),
                  color: AppPalette.clay,
                )
              else if (session.hasPlannedCandidatesOnly)
                _StatusPill(
                  label: l10n.t('formations.calendarPlanned'),
                  color: AppPalette.amber,
                )
              else
                _StatusPill(
                  label: l10n.t('formations.calendarReady'),
                  color: AppPalette.deepTeal,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SessionInfoPill(
                icon: Icons.place_outlined,
                label:
                    session.location.isEmpty
                        ? l10n.t('formations.locationMissing')
                        : session.location,
                tone: tone,
              ),
              _SessionInfoPill(
                icon: Icons.groups_2_outlined,
                label:
                    '${session.displayCandidateCount} ${l10n.t(session.hasDetailedParticipants ? 'formations.participantsShort' : 'formations.candidatesPlannedShort')}',
                tone: tone,
              ),
              if (session.trainer.isNotEmpty)
                _SessionInfoPill(
                  icon: Icons.person_outline_rounded,
                  label: session.trainer,
                  tone: tone,
                ),
              if (session.schedule.isNotEmpty)
                _SessionInfoPill(
                  icon: Icons.schedule_rounded,
                  label: session.schedule,
                  tone: tone,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionInfoPill extends StatelessWidget {
  const _SessionInfoPill({
    required this.icon,
    required this.label,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final _FormationTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tone.softSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tone.muted),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tone.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftsSection extends StatelessWidget {
  const _DraftsSection({
    required this.drafts,
    required this.tone,
    required this.statusFilter,
    required this.emailTypeFilter,
    required this.onStatusFilterChanged,
    required this.onEmailTypeFilterChanged,
    required this.onOpen,
  });

  final List<TrainingDraft> drafts;
  final _FormationTone tone;
  final String statusFilter;
  final String emailTypeFilter;
  final ValueChanged<String> onStatusFilterChanged;
  final ValueChanged<String> onEmailTypeFilterChanged;
  final ValueChanged<TrainingDraft> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: l10n.t('formations.draftsToReview'),
          count: drafts.length,
          tone: tone,
        ),
        const SizedBox(height: 12),
        _DraftFilterBar(
          statusFilter: statusFilter,
          emailTypeFilter: emailTypeFilter,
          tone: tone,
          onStatusFilterChanged: onStatusFilterChanged,
          onEmailTypeFilterChanged: onEmailTypeFilterChanged,
        ),
        const SizedBox(height: 12),
        if (drafts.isEmpty)
          _InlineMessage(
            icon: Icons.drafts_outlined,
            message: l10n.t('formations.noDrafts'),
            tone: tone,
          )
        else
          for (final draft in drafts) ...[
            _DraftCard(draft: draft, tone: tone, onTap: () => onOpen(draft)),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _DraftFilterBar extends StatelessWidget {
  const _DraftFilterBar({
    required this.statusFilter,
    required this.emailTypeFilter,
    required this.tone,
    required this.onStatusFilterChanged,
    required this.onEmailTypeFilterChanged,
  });

  final String statusFilter;
  final String emailTypeFilter;
  final _FormationTone tone;
  final ValueChanged<String> onStatusFilterChanged;
  final ValueChanged<String> onEmailTypeFilterChanged;

  @override
  Widget build(BuildContext context) {
    final statusFilters = const [
      'all',
      'review',
      'approved',
      'sent',
      'blocked',
      'rejected',
    ];
    final emailTypeFilters = const [
      'all',
      'sensibilisation',
      'confirmation_presence',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in statusFilters) ...[
                _FilterChipButton(
                  label: _draftStatusFilterLabel(context, filter),
                  selected: statusFilter == filter,
                  tone: tone,
                  onSelected: () => onStatusFilterChanged(filter),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: emailTypeFilter,
          isExpanded: true,
          dropdownColor: tone.surface,
          decoration: InputDecoration(
            labelText: context.l10n.t('formations.filterByType'),
            filled: true,
            fillColor: tone.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: tone.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: tone.border),
            ),
          ),
          items:
              emailTypeFilters
                  .map(
                    (filter) => DropdownMenuItem<String>(
                      value: filter,
                      child: Text(_draftEmailTypeFilterLabel(context, filter)),
                    ),
                  )
                  .toList(),
          onChanged: (value) {
            if (value != null) onEmailTypeFilterChanged(value);
          },
        ),
      ],
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.tone,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final _FormationTone tone;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppPalette.deepTeal : tone.surface;
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppPalette.deepTeal : tone.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppPalette.white : tone.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({
    required this.draft,
    required this.tone,
    required this.onTap,
  });

  final TrainingDraft draft;
  final _FormationTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = _statusLabel(context, draft.status);
    final statusColor = _statusColor(draft.status);
    final responsibleLabel = _draftResponsibleLabel(context, draft);
    final regionLabel = _draftRegionLabel(draft);

    return Material(
      color: tone.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tone.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      draft.subject.isEmpty
                          ? l10n.t('formations.noSubject')
                          : draft.subject,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tone.text,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StatusPill(label: status, color: statusColor),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                responsibleLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tone.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (regionLabel.isNotEmpty)
                    _StatusPill(label: regionLabel, color: AppPalette.deepTeal),
                  _StatusPill(
                    label:
                        '${draft.participantCount} ${l10n.t('formations.participantsShort')}',
                    color: AppPalette.sage,
                  ),
                  _StatusPill(
                    label: _draftEmailTypeFilterLabel(context, draft.emailType),
                    color: AppPalette.blue,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                draft.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tone.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendHistorySection extends StatelessWidget {
  const _SendHistorySection({required this.history, required this.tone});

  final List<TrainingSendHistory> history;
  final _FormationTone tone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: l10n.t('formations.sendHistory'),
          count: history.length,
          tone: tone,
        ),
        const SizedBox(height: 12),
        if (history.isEmpty)
          _InlineMessage(
            icon: Icons.history_rounded,
            message: l10n.t('formations.noSendHistory'),
            tone: tone,
          )
        else
          for (final item in history.take(6)) ...[
            _SendHistoryCard(item: item, tone: tone),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _SendHistoryCard extends StatelessWidget {
  const _SendHistoryCard({required this.item, required this.tone});

  final TrainingSendHistory item;
  final _FormationTone tone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = item.isSent ? AppPalette.deepTeal : AppPalette.clay;
    final statusLabel =
        item.isSent
            ? l10n.t('formations.statusSent')
            : l10n.t('formations.statusError');

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.subject.isEmpty
                      ? l10n.t('formations.noSubject')
                      : item.subject,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tone.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(label: statusLabel, color: color),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.alternate_email_rounded, size: 15, color: tone.muted),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${l10n.t('formations.sentTo')} ${item.recipientEmail}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tone.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 15, color: tone.muted),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${l10n.t('formations.sentAt')} ${_formatHistoryDate(item.sentAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tone.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (item.isError && item.error.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              item.error,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppPalette.clay,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactMatchingReviewSection extends StatelessWidget {
  const _ContactMatchingReviewSection({
    required this.summary,
    required this.contacts,
    required this.tone,
    required this.onFix,
  });

  final PlanningContactReviewSummary? summary;
  final List<PlanningContactReview> contacts;
  final _FormationTone tone;
  final ValueChanged<PlanningContactReview> onFix;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currentSummary = summary;
    if (currentSummary == null || currentSummary.total == 0) {
      return const SizedBox.shrink();
    }
    final visibleContacts =
        contacts.where((contact) => contact.needsReview).isEmpty
            ? contacts.take(4).toList()
            : contacts.where((contact) => contact.needsReview).take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: l10n.t('formations.contactReviewTitle'),
          count: currentSummary.needsReview,
          tone: tone,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tone.softSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tone.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currentSummary.needsReview == 0
                    ? l10n.t('formations.contactReviewReady')
                    : l10n.t('formations.contactReviewSubtitle'),
                style: TextStyle(
                  color: tone.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _CompactMetric(
                      label: l10n.t('formations.contactReviewMatched'),
                      value: '${currentSummary.matched}',
                      tone: tone,
                      accent: AppPalette.deepTeal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CompactMetric(
                      label: l10n.t('formations.contactReviewNameMatch'),
                      value: '${currentSummary.review}',
                      tone: tone,
                      accent: AppPalette.amber,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CompactMetric(
                      label: l10n.t('formations.contactReviewMissing'),
                      value: '${currentSummary.missing}',
                      tone: tone,
                      accent: AppPalette.clay,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final contact in visibleContacts) ...[
          _ContactReviewCard(contact: contact, tone: tone, onFix: onFix),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ContactReviewCard extends StatelessWidget {
  const _ContactReviewCard({
    required this.contact,
    required this.tone,
    required this.onFix,
  });

  final PlanningContactReview contact;
  final _FormationTone tone;
  final ValueChanged<PlanningContactReview> onFix;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent =
        contact.isMissing
            ? AppPalette.clay
            : contact.needsReview
            ? AppPalette.amber
            : AppPalette.deepTeal;
    final icon =
        contact.isMissing
            ? Icons.person_search_rounded
            : contact.needsReview
            ? Icons.manage_search_rounded
            : Icons.verified_user_outlined;
    final email =
        contact.displayEmail.isEmpty
            ? l10n.t('formations.contactReviewNoEmail')
            : contact.displayEmail;
    final firstSession =
        contact.sessions.isEmpty ? null : contact.sessions.first;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        contact.fullName.isEmpty
                            ? l10n.t('settings.user')
                            : contact.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tone.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusPill(
                      label: _contactMatchLabel(context, contact),
                      color: accent,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tone.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (contact.matricule.isNotEmpty) contact.matricule,
                    '${contact.sessionCount} session(s)',
                    if (firstSession?.module.isNotEmpty ?? false)
                      firstSession!.module,
                  ].join(' - '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tone.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => onFix(contact),
            icon: const Icon(Icons.edit_rounded),
            tooltip: l10n.t('formations.contactReviewEdit'),
          ),
        ],
      ),
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({
    required this.label,
    required this.value,
    required this.tone,
    required this.accent,
  });

  final String label;
  final String value;
  final _FormationTone tone;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tone.muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ImportFeedbackMode { preview, result }

class _ImportFeedbackSheet extends StatelessWidget {
  const _ImportFeedbackSheet({
    required this.summary,
    required this.automation,
    required this.mode,
  });

  final PlanningImportSummary summary;
  final Map<String, dynamic>? automation;
  final _ImportFeedbackMode mode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tone = _FormationTone.of(context);
    final generated = _intFromMap(automation, 'generated');
    final skipped = _intFromMap(automation, 'skipped_existing');
    final autoRan = automation != null;
    final isPreview = mode == _ImportFeedbackMode.preview;
    final detectedEmails =
        summary.totalParticipants - summary.missingEmailCount;
    final noCandidateEmailsYet =
        summary.totalParticipants > 0 && detectedEmails <= 0;

    return Container(
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: tone.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    l10n.t(
                      isPreview
                          ? 'formations.importPreviewTitle'
                          : 'formations.importFeedbackTitle',
                    ),
                    style: TextStyle(
                      color: tone.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _StatusPill(
                  label: _importStatusLabel(context, summary.status),
                  color: _importStatusColor(summary.status),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              noCandidateEmailsYet
                  ? l10n.t('formations.importNoEmailsDetectedSummary')
                  : summary.hasIssues
                  ? l10n.t(
                    isPreview
                        ? 'formations.importPreviewNeedsReview'
                        : 'formations.importFeedbackNeedsReview',
                  )
                  : l10n.t(
                    isPreview
                        ? 'formations.importPreviewClean'
                        : 'formations.importFeedbackClean',
                  ),
              style: TextStyle(
                color: tone.muted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.55,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _FeedbackMetric(
                  label: l10n.t('formations.feedbackFiles'),
                  value: '${summary.files.length}',
                  icon: Icons.upload_file_rounded,
                  tone: tone,
                ),
                _FeedbackMetric(
                  label: l10n.t('formations.sessions'),
                  value: '${summary.totalSessions}',
                  icon: Icons.event_available_rounded,
                  tone: tone,
                ),
                _FeedbackMetric(
                  label: l10n.t('formations.participants'),
                  value: '${summary.totalParticipants}',
                  icon: Icons.groups_2_rounded,
                  tone: tone,
                ),
                _FeedbackMetric(
                  label: l10n.t('formations.feedbackEmailsDetected'),
                  value: '$detectedEmails',
                  icon: Icons.person_search_rounded,
                  tone: tone,
                  accent:
                      noCandidateEmailsYet
                          ? AppPalette.amber
                          : AppPalette.deepTeal,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (noCandidateEmailsYet) ...[
              _InlineMessage(
                icon: Icons.info_outline_rounded,
                message: l10n.t('formations.feedbackNoEmailsDetected'),
                tone: tone,
                accent: AppPalette.amber,
              ),
              const SizedBox(height: 12),
            ],
            if (isPreview)
              _InlineMessage(
                icon: Icons.visibility_outlined,
                message: l10n.t('formations.importPreviewNotSaved'),
                tone: tone,
                accent: AppPalette.blue,
              )
            else
              _InlineMessage(
                icon:
                    autoRan
                        ? Icons.auto_awesome_rounded
                        : Icons.pause_circle_outline_rounded,
                message:
                    autoRan
                        ? l10n
                            .t('formations.feedbackAutomationRan')
                            .replaceAll('{generated}', '$generated')
                            .replaceAll('{skipped}', '$skipped')
                        : l10n.t('formations.feedbackAutomationSkipped'),
                tone: tone,
                accent: autoRan ? AppPalette.deepTeal : AppPalette.amber,
              ),
            if (summary.warningCount > 0 || summary.errorCount > 0) ...[
              const SizedBox(height: 12),
              _InlineMessage(
                icon: Icons.warning_amber_rounded,
                message: l10n
                    .t('formations.feedbackIssueCount')
                    .replaceAll('{warnings}', '${summary.warningCount}')
                    .replaceAll('{errors}', '${summary.errorCount}'),
                tone: tone,
                accent: AppPalette.clay,
              ),
            ],
            const SizedBox(height: 16),
            Text(
              l10n.t('formations.feedbackFilesTitle'),
              style: TextStyle(
                color: tone.text,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            for (final file in summary.files) ...[
              _ImportFileResultCard(file: file, tone: tone),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            if (isPreview)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(l10n.t('settings.cancel')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.deepTeal,
                        foregroundColor: AppPalette.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(l10n.t('formations.confirmImport')),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.deepTeal,
                    foregroundColor: AppPalette.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(l10n.t('common.close')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackMetric extends StatelessWidget {
  const _FeedbackMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    this.accent = AppPalette.deepTeal,
  });

  final String label;
  final String value;
  final IconData icon;
  final _FormationTone tone;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: tone.softSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: accent, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: accent,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tone.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImportFileResultCard extends StatelessWidget {
  const _ImportFileResultCard({required this.file, required this.tone});

  final PlanningImportFileSummary file;
  final _FormationTone tone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final issues = [...file.errors, ...file.warnings];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.softSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                file.hasIssues
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline_rounded,
                color: file.hasIssues ? AppPalette.clay : AppPalette.deepTeal,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.filename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tone.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n
                          .t('formations.feedbackFileSessions')
                          .replaceAll('{count}', '${file.sessionCount}'),
                      style: TextStyle(
                        color: tone.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(
                label: _importStatusLabel(context, file.status),
                color: _importStatusColor(file.status),
              ),
            ],
          ),
          if (issues.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final issue in issues.take(3)) ...[
              Text(
                issue,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tone.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
            ],
          ],
        ],
      ),
    );
  }
}

class _AutomationSettingsSheet extends StatefulWidget {
  const _AutomationSettingsSheet({required this.viewModel});

  final FormationsViewModel viewModel;

  @override
  State<_AutomationSettingsSheet> createState() =>
      _AutomationSettingsSheetState();
}

class _AutomationSettingsSheetState extends State<_AutomationSettingsSheet> {
  late bool _autoRunAfterImport;
  late String _defaultEmailType;
  late bool _includePopulation;
  late int _maxDraftsPerRun;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final settings =
        widget.viewModel.automationSettings ?? _defaultAutomationSettings();
    _autoRunAfterImport = settings.autoRunAfterImport;
    _defaultEmailType = settings.defaultEmailType;
    _includePopulation = settings.includePopulation;
    _maxDraftsPerRun =
        settings.maxDraftsPerRun == 0 ? 100 : settings.maxDraftsPerRun;
    if (![25, 50, 100, 200, 500].contains(_maxDraftsPerRun)) {
      _maxDraftsPerRun = 100;
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.viewModel.saveAutomationSettings(
        TrainingAutomationSettings(
          autoRunAfterImport: _autoRunAfterImport,
          defaultEmailType: _defaultEmailType,
          includePopulation: _includePopulation,
          maxDraftsPerRun: _maxDraftsPerRun,
          updatedAt: '',
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tone = _FormationTone.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: tone.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.t('formations.automationSettings'),
              style: TextStyle(
                color: tone.text,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              l10n.t('formations.automationSettingsSubtitle'),
              style: TextStyle(
                color: tone.muted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            _SwitchSettingRow(
              title: l10n.t('formations.autoRunAfterImport'),
              subtitle: l10n.t('formations.autoRunAfterImportHint'),
              value: _autoRunAfterImport,
              tone: tone,
              onChanged: (value) => setState(() => _autoRunAfterImport = value),
            ),
            const SizedBox(height: 12),
            _SettingsDropdown<String>(
              label: l10n.t('formations.defaultEmailType'),
              value: _defaultEmailType,
              items: const ['auto', 'sensibilisation', 'confirmation_presence'],
              itemLabel: (value) => _automationEmailTypeLabel(context, value),
              tone: tone,
              onChanged: (value) => setState(() => _defaultEmailType = value),
            ),
            const SizedBox(height: 12),
            _SwitchSettingRow(
              title: l10n.t('formations.includePopulation'),
              subtitle: l10n.t('formations.includePopulationHint'),
              value: _includePopulation,
              tone: tone,
              onChanged: (value) => setState(() => _includePopulation = value),
            ),
            const SizedBox(height: 12),
            _SettingsDropdown<int>(
              label: l10n.t('formations.maxDraftsPerRun'),
              value: _maxDraftsPerRun,
              items: const [25, 50, 100, 200, 500],
              itemLabel: (value) => '$value',
              tone: tone,
              onChanged: (value) => setState(() => _maxDraftsPerRun = value),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon:
                    _saving
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.save_rounded),
                label: Text(l10n.t('formations.saveAutomationSettings')),
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.deepTeal,
                  foregroundColor: AppPalette.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchSettingRow extends StatelessWidget {
  const _SwitchSettingRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.tone,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final _FormationTone tone;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: tone.softSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: tone.text,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: tone.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SettingsDropdown<T> extends StatelessWidget {
  const _SettingsDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.tone,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T value) itemLabel;
  final _FormationTone tone;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      dropdownColor: tone.surface,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: tone.softSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: tone.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: tone.border),
        ),
      ),
      items:
          items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(itemLabel(item)),
                ),
              )
              .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _ContactFixSheet extends StatefulWidget {
  const _ContactFixSheet({required this.viewModel, required this.contact});

  final FormationsViewModel viewModel;
  final PlanningContactReview contact;

  @override
  State<_ContactFixSheet> createState() => _ContactFixSheetState();
}

class _ContactFixSheetState extends State<_ContactFixSheet> {
  late final TextEditingController _emailController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.contact.displayEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      _showMessage(context.l10n.t('formations.invalidEmail'));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.viewModel.saveReviewedContact(
        contact: widget.contact,
        email: email,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tone = _FormationTone.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: tone.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.t('formations.contactReviewEdit'),
              style: TextStyle(
                color: tone.text,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.contact.fullName,
              style: TextStyle(
                color: tone.text,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (widget.contact.matricule.isNotEmpty)
                  widget.contact.matricule,
                _contactMatchLabel(context, widget.contact),
              ].join(' - '),
              style: TextStyle(
                color: tone.muted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (widget.contact.reason.isNotEmpty) ...[
              const SizedBox(height: 12),
              _InlineMessage(
                icon:
                    widget.contact.needsReview
                        ? Icons.info_outline_rounded
                        : Icons.verified_outlined,
                message: widget.contact.reason,
                tone: tone,
                accent:
                    widget.contact.needsReview
                        ? AppPalette.amber
                        : AppPalette.deepTeal,
              ),
            ],
            const SizedBox(height: 16),
            _LabeledField(
              label: l10n.t('formations.emailAddress'),
              controller: _emailController,
              hint: 'nom.prenom@tunisietelecom.tn',
              tone: tone,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon:
                    _saving
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.save_rounded),
                label: Text(l10n.t('formations.saveContact')),
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.deepTeal,
                  foregroundColor: AppPalette.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftReviewSheet extends StatefulWidget {
  const _DraftReviewSheet({required this.viewModel, required this.draft});

  final FormationsViewModel viewModel;
  final TrainingDraft draft;

  @override
  State<_DraftReviewSheet> createState() => _DraftReviewSheetState();
}

class _DraftReviewSheetState extends State<_DraftReviewSheet> {
  late final TextEditingController _subjectController;
  late final TextEditingController _recipientsController;
  late final TextEditingController _ccController;
  late final TextEditingController _bodyController;
  late TrainingDraft _draft;
  late String _regenerateEmailType;
  bool _regenerateWithPopulation = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.draft;
    _regenerateEmailType = widget.draft.emailType;
    _subjectController = TextEditingController(text: _draft.subject);
    _recipientsController = TextEditingController(
      text: _draft.recipients.join(', '),
    );
    _ccController = TextEditingController(text: _draft.cc.join(', '));
    _bodyController = TextEditingController(text: _draft.body);
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _recipientsController.dispose();
    _ccController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<TrainingDraft?> _save() async {
    setState(() => _saving = true);
    try {
      return await widget.viewModel.saveDraft(
        draft: _draft,
        subject: _subjectController.text,
        body: _bodyController.text,
        recipients: _splitEmails(_recipientsController.text),
        cc: _splitEmails(_ccController.text),
      );
    } catch (error) {
      if (mounted) _showSheetMessage(error.toString());
      return null;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _approve() async {
    final saved = await _save();
    if (saved == null) return;
    setState(() => _saving = true);
    try {
      await widget.viewModel.approveDraft(saved);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _showSheetMessage(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _send() async {
    final confirmed = await _openSendConfirmation();
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await widget.viewModel.sendDraft(_draft);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _showSheetMessage(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool?> _openSendConfirmation() {
    var checked = false;
    final recipients = _draft.recipients;
    final visibleRecipients = recipients.take(4).join('\n');
    return showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              final l10n = context.l10n;
              return AlertDialog(
                title: Text(l10n.t('formations.sendSafetyTitle')),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.t('formations.sendSafetyMessage')),
                      const SizedBox(height: 14),
                      _SafetyLine(
                        label: l10n.t('formations.subject'),
                        value: _draft.subject,
                      ),
                      const SizedBox(height: 10),
                      _SafetyLine(
                        label: l10n.t('formations.recipients'),
                        value:
                            '${recipients.length} ${l10n.t('formations.sendSafetyRecipients')}',
                      ),
                      if (visibleRecipients.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          visibleRecipients,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: checked,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(l10n.t('formations.sendSafetyCheckbox')),
                        onChanged:
                            (value) =>
                                setDialogState(() => checked = value ?? false),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(l10n.t('settings.cancel')),
                  ),
                  FilledButton.icon(
                    onPressed:
                        checked ? () => Navigator.of(context).pop(true) : null,
                    icon: const Icon(Icons.send_rounded),
                    label: Text(l10n.t('formations.sendWithOutlook')),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _reject() async {
    setState(() => _saving = true);
    try {
      await widget.viewModel.rejectDraft(
        _draft,
        reason: 'Rejected from mobile review',
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _showSheetMessage(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _regenerate() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(context.l10n.t('formations.regenerateDraft')),
            content: Text(context.l10n.t('formations.regenerateWarning')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.t('settings.cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.l10n.t('formations.regenerateAction')),
              ),
            ],
          ),
    );
    if (confirm != true) return;

    setState(() => _saving = true);
    try {
      final regenerated = await widget.viewModel.regenerateDraft(
        _draft,
        emailType: _regenerateEmailType,
        includePopulation: _regenerateWithPopulation,
      );
      _applyDraft(regenerated);
      if (mounted) {
        _showSheetMessage(context.l10n.t('formations.regenerateDone'));
      }
    } catch (error) {
      if (mounted) _showSheetMessage(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _applyDraft(TrainingDraft draft) {
    setState(() {
      _draft = draft;
      _regenerateEmailType = draft.emailType;
      _subjectController.text = draft.subject;
      _recipientsController.text = draft.recipients.join(', ');
      _ccController.text = draft.cc.join(', ');
      _bodyController.text = draft.body;
    });
  }

  void _showSheetMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tone = _FormationTone.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final canEdit = _draft.canReview;
    final canSend = _draft.isApproved;
    final canRegenerate = !_draft.isSent;

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: tone.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.t('formations.reviewDraft'),
                    style: TextStyle(
                      color: tone.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _StatusPill(
                  label: _statusLabel(context, _draft.status),
                  color: _statusColor(_draft.status),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _RegenerateDraftPanel(
              emailType: _regenerateEmailType,
              includePopulation: _regenerateWithPopulation,
              tone: tone,
              enabled: !_saving && canRegenerate,
              onEmailTypeChanged:
                  (value) => setState(() => _regenerateEmailType = value),
              onIncludePopulationChanged:
                  (value) => setState(() => _regenerateWithPopulation = value),
              onRegenerate: _regenerate,
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: l10n.t('formations.recipients'),
              controller: _recipientsController,
              hint: 'responsable@tunisietelecom.tn',
              tone: tone,
              enabled: canEdit,
            ),
            const SizedBox(height: 12),
            _LabeledField(
              label: l10n.t('formations.cc'),
              controller: _ccController,
              hint: l10n.t('formations.optional'),
              tone: tone,
              enabled: canEdit,
            ),
            const SizedBox(height: 12),
            _LabeledField(
              label: l10n.t('formations.subject'),
              controller: _subjectController,
              hint: l10n.t('formations.subject'),
              tone: tone,
              enabled: canEdit,
            ),
            const SizedBox(height: 12),
            _LabeledField(
              label: l10n.t('formations.message'),
              controller: _bodyController,
              hint: l10n.t('formations.message'),
              tone: tone,
              minLines: 8,
              maxLines: 14,
              enabled: canEdit,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving || !_draft.canReview ? null : _reject,
                    icon: const Icon(Icons.close_rounded),
                    label: Text(l10n.t('formations.reject')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving || !_draft.canReview ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(l10n.t('formations.save')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    _saving
                        ? null
                        : canSend
                        ? _send
                        : canEdit
                        ? _approve
                        : null,
                icon:
                    _saving
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Icon(
                          canSend
                              ? Icons.outgoing_mail
                              : Icons.verified_rounded,
                        ),
                label: Text(
                  l10n.t(
                    canSend
                        ? 'formations.sendWithOutlook'
                        : 'formations.approve',
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.deepTeal,
                  foregroundColor: AppPalette.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegenerateDraftPanel extends StatelessWidget {
  const _RegenerateDraftPanel({
    required this.emailType,
    required this.includePopulation,
    required this.tone,
    required this.enabled,
    required this.onEmailTypeChanged,
    required this.onIncludePopulationChanged,
    required this.onRegenerate,
  });

  final String emailType;
  final bool includePopulation;
  final _FormationTone tone;
  final bool enabled;
  final ValueChanged<String> onEmailTypeChanged;
  final ValueChanged<bool> onIncludePopulationChanged;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.softSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.refresh_rounded, color: tone.muted, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.t('formations.regenerateDraft'),
                  style: TextStyle(
                    color: tone.text,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: enabled ? onRegenerate : null,
                icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                label: Text(l10n.t('formations.regenerateAction')),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value:
                [
                      'auto',
                      'sensibilisation',
                      'confirmation_presence',
                    ].contains(emailType)
                    ? emailType
                    : 'auto',
            isExpanded: true,
            dropdownColor: tone.surface,
            decoration: InputDecoration(
              labelText: l10n.t('formations.defaultEmailType'),
              filled: true,
              fillColor: tone.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: tone.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: tone.border),
              ),
            ),
            items:
                const ['auto', 'sensibilisation', 'confirmation_presence']
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(_automationEmailTypeLabel(context, value)),
                      ),
                    )
                    .toList(),
            onChanged:
                enabled
                    ? (value) {
                      if (value != null) onEmailTypeChanged(value);
                    }
                    : null,
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: includePopulation,
            onChanged:
                enabled
                    ? (value) => onIncludePopulationChanged(value ?? true)
                    : null,
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              l10n.t('formations.includePopulation'),
              style: TextStyle(
                color: tone.text,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyLine extends StatelessWidget {
  const _SafetyLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          value.isEmpty ? '-' : value,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.tone,
    this.minLines = 1,
    this.maxLines = 1,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final _FormationTone tone;
  final int minLines;
  final int maxLines;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: tone.text,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          enabled: enabled,
          minLines: minLines,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: tone.softSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: tone.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: tone.border),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.tone,
  });

  final String title;
  final int count;
  final _FormationTone tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: tone.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        _StatusPill(label: '$count', color: AppPalette.deepTeal),
      ],
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.icon,
    required this.message,
    required this.tone,
    this.accent = AppPalette.amber,
  });

  final IconData icon;
  final String message;
  final _FormationTone tone;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: tone.muted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPlanningState extends StatelessWidget {
  const _EmptyPlanningState({required this.tone});

  final _FormationTone tone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _InlineMessage(
      icon: Icons.folder_open_rounded,
      message:
          '${l10n.t('formations.emptyTitle')}\n${l10n.t('formations.emptySubtitle')}',
      tone: tone,
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

String _statusLabel(BuildContext context, String status) {
  final l10n = context.l10n;
  return switch (status) {
    'APPROVED' => l10n.t('formations.statusApproved'),
    'EDITED' => l10n.t('formations.statusEdited'),
    'NEEDS_CONTACTS' => l10n.t('formations.statusNeedsContacts'),
    'REJECTED' => l10n.t('formations.statusRejected'),
    'SENT' => l10n.t('formations.statusSent'),
    _ => l10n.t('formations.statusWaiting'),
  };
}

Color _statusColor(String status) {
  return switch (status) {
    'APPROVED' => AppPalette.deepTeal,
    'EDITED' => AppPalette.blue,
    'NEEDS_CONTACTS' => AppPalette.clay,
    'REJECTED' => AppPalette.clay,
    'SENT' => AppPalette.deepTeal,
    _ => AppPalette.amber,
  };
}

String _importStatusLabel(BuildContext context, String status) {
  final l10n = context.l10n;
  return switch (status) {
    'ok' => l10n.t('formations.importStatusOk'),
    'needs_review' => l10n.t('formations.importStatusReview'),
    'error' => l10n.t('formations.importStatusError'),
    _ => status.isEmpty ? l10n.t('formations.importStatusUnknown') : status,
  };
}

Color _importStatusColor(String status) {
  return switch (status) {
    'ok' => AppPalette.deepTeal,
    'needs_review' => AppPalette.amber,
    'error' => AppPalette.clay,
    _ => AppPalette.blue,
  };
}

int _intFromMap(Map<String, dynamic>? value, String key) {
  final raw = value?[key];
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw) ?? 0;
  return 0;
}

TrainingAutomationSettings _defaultAutomationSettings() {
  return const TrainingAutomationSettings(
    autoRunAfterImport: true,
    defaultEmailType: 'auto',
    includePopulation: true,
    maxDraftsPerRun: 100,
    updatedAt: '',
  );
}

String _automationEmailTypeLabel(BuildContext context, String value) {
  final l10n = context.l10n;
  return switch (value) {
    'sensibilisation' => l10n.t('formations.emailTypeAwareness'),
    'confirmation_presence' => l10n.t('formations.emailTypeConfirmation'),
    _ => l10n.t('formations.emailTypeAuto'),
  };
}

String _draftStatusFilterLabel(BuildContext context, String value) {
  final l10n = context.l10n;
  return switch (value) {
    'review' => l10n.t('formations.filterReview'),
    'approved' => l10n.t('formations.filterApproved'),
    'sent' => l10n.t('formations.filterSent'),
    'blocked' => l10n.t('formations.filterBlocked'),
    'rejected' => l10n.t('formations.filterRejected'),
    _ => l10n.t('formations.filterAll'),
  };
}

String _draftEmailTypeFilterLabel(BuildContext context, String value) {
  if (value == 'all') return context.l10n.t('formations.filterAllTypes');
  return _automationEmailTypeLabel(context, value);
}

String _draftResponsibleLabel(BuildContext context, TrainingDraft draft) {
  final l10n = context.l10n;
  final recipient = draft.primaryRecipient;
  final name = draft.responsibleName;
  final label = l10n.t('formations.responsibleRecipient');

  if (name.isNotEmpty && recipient.isNotEmpty) {
    return '$label: $name <$recipient>';
  }
  if (recipient.isNotEmpty) return '$label: $recipient';
  if (name.isNotEmpty) return '$label: $name';
  return l10n.t('formations.noResponsibleRecipient');
}

String _draftRegionLabel(TrainingDraft draft) {
  final residence = draft.responsibleResidence;
  if (residence.isNotEmpty) return residence;
  return draft.responsibleDirection;
}

String _contactMatchLabel(BuildContext context, PlanningContactReview contact) {
  final l10n = context.l10n;
  if (contact.isMissing) return l10n.t('formations.contactMatchMissing');
  return switch (contact.matchMethod) {
    'matricule' => l10n.t('formations.contactMatchMatricule'),
    'name' => l10n.t('formations.contactMatchName'),
    'planning' => l10n.t('formations.contactMatchPlanning'),
    _ => l10n.t('formations.contactMatchReview'),
  };
}

List<TrainingCalendarSession> _sessionsForMonth(
  List<TrainingCalendarSession> sessions,
  DateTime? month,
) {
  if (month == null) return sessions;
  return sessions.where((session) {
    final start = _parsePlanningDate(session.startDate);
    return _sameMonth(start, month);
  }).toList();
}

List<TrainingCalendarSession> _sessionsForYear(
  List<TrainingCalendarSession> sessions,
  int year,
) {
  return sessions.where((session) {
    final start = _parsePlanningDate(session.startDate);
    return start?.year == year;
  }).toList();
}

List<TrainingCalendarSession> _sortSessionsByDate(
  List<TrainingCalendarSession> sessions,
) {
  final sorted = sessions.toList();
  sorted.sort((left, right) {
    final leftDate = _parsePlanningDate(left.startDate);
    final rightDate = _parsePlanningDate(right.startDate);
    if (leftDate == null && rightDate == null) {
      return left.module.compareTo(right.module);
    }
    if (leftDate == null) return 1;
    if (rightDate == null) return -1;
    final dateComparison = leftDate.compareTo(rightDate);
    if (dateComparison != 0) return dateComparison;
    return left.module.compareTo(right.module);
  });
  return sorted;
}

int _defaultCalendarYear(List<TrainingCalendarSession> sessions) {
  const preferredYear = 2026;
  if (sessions.any(
    (session) => _parsePlanningDate(session.startDate)?.year == preferredYear,
  )) {
    return preferredYear;
  }
  for (final session in sessions) {
    final year = _parsePlanningDate(session.startDate)?.year;
    if (year != null && year >= 2024 && year <= 2027) return year;
  }
  return preferredYear;
}

int _defaultCalendarMonthNumber(
  List<TrainingCalendarSession> sessions,
  int year,
) {
  const preferredMonth = 5;
  if (year == 2026 &&
      sessions.any((session) {
        final start = _parsePlanningDate(session.startDate);
        return start?.year == year && start?.month == preferredMonth;
      })) {
    return preferredMonth;
  }
  final yearSessions = _sessionsForYear(sessions, year);
  if (yearSessions.isEmpty) return 1;
  final firstDate = _parsePlanningDate(yearSessions.first.startDate);
  return firstDate?.month ?? 1;
}

int _calendarPageCount(int totalCount, int pageSize) {
  if (totalCount <= 0) return 1;
  return ((totalCount - 1) ~/ pageSize) + 1;
}

DateTime? _parsePlanningDate(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final normalized = trimmed.replaceFirst(' ', 'T');
  final parsed = DateTime.tryParse(normalized);
  if (parsed != null) {
    return DateTime(parsed.year, parsed.month, parsed.day);
  }
  final slashMatch = RegExp(
    r'^(\d{1,2})/(\d{1,2})/(\d{4})$',
  ).firstMatch(trimmed);
  if (slashMatch == null) return null;
  final day = int.tryParse(slashMatch.group(1) ?? '');
  final month = int.tryParse(slashMatch.group(2) ?? '');
  final year = int.tryParse(slashMatch.group(3) ?? '');
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

bool _sameDay(DateTime? left, DateTime? right) {
  if (left == null || right == null) return false;
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

bool _sameMonth(DateTime? left, DateTime? right) {
  if (left == null || right == null) return false;
  return left.year == right.year && left.month == right.month;
}

String _formatMonthLabel(BuildContext context, DateTime date) {
  final monthKeys = const [
    'date.jan',
    'date.feb',
    'date.mar',
    'date.apr',
    'date.may',
    'date.jun',
    'date.jul',
    'date.aug',
    'date.sep',
    'date.oct',
    'date.nov',
    'date.dec',
  ];
  return '${context.l10n.t(monthKeys[date.month - 1])} ${date.year}';
}

String _formatSessionDateRange(
  BuildContext context,
  String startValue,
  String endValue,
) {
  final start = _parsePlanningDate(startValue);
  final end = _parsePlanningDate(endValue);
  if (start == null && end == null) {
    return startValue.isEmpty ? '-' : startValue;
  }
  if (start != null && end != null && !_sameDay(start, end)) {
    return '${_formatSessionDate(context, start)} - ${_formatSessionDate(context, end)}';
  }
  return _formatSessionDate(context, start ?? end!);
}

String _formatSessionDate(BuildContext context, DateTime date) {
  final monthKeys = const [
    'date.jan',
    'date.feb',
    'date.mar',
    'date.apr',
    'date.may',
    'date.jun',
    'date.jul',
    'date.aug',
    'date.sep',
    'date.oct',
    'date.nov',
    'date.dec',
  ];
  return '${date.day} ${context.l10n.t(monthKeys[date.month - 1])} ${date.year}';
}

String _formatHistoryDate(String value) {
  final normalized = value.replaceFirst(' ', 'T');
  final parsed = DateTime.tryParse(normalized);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(local.day)}/${twoDigits(local.month)}/${local.year} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

List<String> _splitEmails(String value) {
  return value
      .split(RegExp(r'[,;\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}
