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
      allowedExtensions: const ['xlsx', 'xls'],
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
      allowedExtensions: const ['xlsx', 'xls', 'csv'],
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
    await _viewModel.runAutomation();
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

  Future<void> _openContactFix(MissingPlanningContact contact) async {
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
              _UploadPanel(onUpload: _pickPlanningFiles, tone: tone),
              const SizedBox(height: 12),
              _ContactDirectoryPanel(onUpload: _pickContactFiles, tone: tone),
              const SizedBox(height: 20),
              _MonthOverview(viewModel: _viewModel, tone: tone),
              const SizedBox(height: 20),
              _ActionPanel(
                viewModel: _viewModel,
                tone: tone,
                onGenerate: _generateDrafts,
                onSettings: _openAutomationSettings,
              ),
              const SizedBox(height: 20),
              _DraftsSection(
                drafts: _viewModel.drafts,
                tone: tone,
                statusFilter: _viewModel.draftStatusFilter,
                emailTypeFilter: _viewModel.draftEmailTypeFilter,
                onStatusFilterChanged: _viewModel.setDraftStatusFilter,
                onEmailTypeFilterChanged: _viewModel.setDraftEmailTypeFilter,
                onOpen: _openDraft,
              ),
              const SizedBox(height: 20),
              _SendHistorySection(history: _viewModel.sendHistory, tone: tone),
              const SizedBox(height: 20),
              _MissingContactsSection(
                contacts: _viewModel.missingContacts,
                tone: tone,
                onFix: _openContactFix,
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
        items: [
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
        ],
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

class _ContactDirectoryPanel extends StatelessWidget {
  const _ContactDirectoryPanel({required this.onUpload, required this.tone});

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
              Icons.contact_mail_rounded,
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
              icon: Icons.edit_document,
              label: l10n.t('formations.drafts'),
              value: '${viewModel.draftsCount}',
            ),
            _FormationStatCard(
              icon: Icons.report_gmailerrorred_rounded,
              label: l10n.t('formations.missing'),
              value: '${viewModel.missingCount}',
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
                draft.recipients.isEmpty
                    ? l10n.t('formations.noRecipients')
                    : draft.recipients.join(', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tone.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
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

class _MissingContactsSection extends StatelessWidget {
  const _MissingContactsSection({
    required this.contacts,
    required this.tone,
    required this.onFix,
  });

  final List<MissingPlanningContact> contacts;
  final _FormationTone tone;
  final ValueChanged<MissingPlanningContact> onFix;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (contacts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: l10n.t('formations.contactsToComplete'),
          count: contacts.length,
          tone: tone,
        ),
        const SizedBox(height: 12),
        for (final contact in contacts.take(6)) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tone.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tone.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_search_rounded, color: AppPalette.clay),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.fullName,
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
                        '${contact.matricule} - ${contact.sessionCount} session(s)',
                        style: TextStyle(
                          color: tone.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => onFix(contact),
                  icon: const Icon(Icons.edit_rounded),
                  tooltip: l10n.t('formations.fixContact'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ImportFeedbackSheet extends StatelessWidget {
  const _ImportFeedbackSheet({required this.summary, required this.automation});

  final PlanningImportSummary summary;
  final Map<String, dynamic>? automation;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tone = _FormationTone.of(context);
    final generated = _intFromMap(automation, 'generated');
    final skipped = _intFromMap(automation, 'skipped_existing');
    final autoRan = automation != null;

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
                    l10n.t('formations.importFeedbackTitle'),
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
              summary.hasIssues
                  ? l10n.t('formations.importFeedbackNeedsReview')
                  : l10n.t('formations.importFeedbackClean'),
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
                  label: l10n.t('formations.feedbackMissingEmails'),
                  value: '${summary.missingEmailCount}',
                  icon: Icons.person_search_rounded,
                  tone: tone,
                  accent:
                      summary.missingEmailCount > 0
                          ? AppPalette.clay
                          : AppPalette.deepTeal,
                ),
              ],
            ),
            const SizedBox(height: 16),
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
  final MissingPlanningContact contact;

  @override
  State<_ContactFixSheet> createState() => _ContactFixSheetState();
}

class _ContactFixSheetState extends State<_ContactFixSheet> {
  late final TextEditingController _emailController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
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
      await widget.viewModel.saveMissingContact(
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
              l10n.t('formations.fixContact'),
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
              widget.contact.matricule,
              style: TextStyle(
                color: tone.muted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController(text: widget.draft.subject);
    _recipientsController = TextEditingController(
      text: widget.draft.recipients.join(', '),
    );
    _ccController = TextEditingController(text: widget.draft.cc.join(', '));
    _bodyController = TextEditingController(text: widget.draft.body);
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
        draft: widget.draft,
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
    setState(() => _saving = true);
    try {
      await widget.viewModel.sendDraft(widget.draft);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _showSheetMessage(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _saving = true);
    try {
      await widget.viewModel.rejectDraft(
        widget.draft,
        reason: 'Rejected from mobile review',
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _showSheetMessage(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
    final canEdit = widget.draft.canReview;
    final canSend = widget.draft.isApproved;

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
                  label: _statusLabel(context, widget.draft.status),
                  color: _statusColor(widget.draft.status),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: l10n.t('formations.recipients'),
              controller: _recipientsController,
              hint: 'nom.prenom@tunisietelecom.tn',
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
                    onPressed:
                        _saving || !widget.draft.canReview ? null : _reject,
                    icon: const Icon(Icons.close_rounded),
                    label: Text(l10n.t('formations.reject')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _saving || !widget.draft.canReview ? null : _save,
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
