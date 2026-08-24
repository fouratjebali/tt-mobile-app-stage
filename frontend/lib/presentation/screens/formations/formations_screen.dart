import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/localization/app_localizations.dart';
import 'package:tt_mail_assistant/core/theme/app_palette.dart';
import 'package:tt_mail_assistant/presentation/widgets/app_bottom_navigation_bar.dart';

class FormationsScreen extends StatelessWidget {
  const FormationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tone = _FormationTone.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            _FormationHeader(onBack: () => Navigator.of(context).maybePop()),
            const SizedBox(height: 22),
            _UploadPanel(
              onUpload: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.t('formations.uploadNext'))),
                );
              },
            ),
            const SizedBox(height: 22),
            Text(
              l10n.t('formations.monthPlan'),
              style: TextStyle(
                color: tone.text,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            const _FormationStatsGrid(),
            const SizedBox(height: 22),
            _PipelineSection(tone: tone),
            const SizedBox(height: 22),
            _EmptyPlanningState(tone: tone),
          ],
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
  const _FormationHeader({required this.onBack});

  final VoidCallback onBack;

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
      ],
    );
  }
}

class _UploadPanel extends StatelessWidget {
  const _UploadPanel({required this.onUpload});

  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tone = _FormationTone.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppPalette.deepTeal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.upload_file_rounded,
              color: AppPalette.deepTeal,
              size: 26,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.t('formations.uploadTitle'),
            style: TextStyle(
              color: tone.text,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('formations.uploadSubtitle'),
            style: TextStyle(
              color: tone.muted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.t('formations.uploadAction')),
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
    );
  }
}

class _FormationStatsGrid extends StatelessWidget {
  const _FormationStatsGrid();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.45,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _FormationStatCard(
          icon: Icons.event_available_rounded,
          label: l10n.t('formations.sessions'),
          value: '0',
        ),
        _FormationStatCard(
          icon: Icons.groups_2_rounded,
          label: l10n.t('formations.participants'),
          value: '0',
        ),
        _FormationStatCard(
          icon: Icons.edit_document,
          label: l10n.t('formations.drafts'),
          value: '0',
        ),
        _FormationStatCard(
          icon: Icons.report_gmailerrorred_rounded,
          label: l10n.t('formations.missing'),
          value: '0',
          accent: AppPalette.clay,
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

class _PipelineSection extends StatelessWidget {
  const _PipelineSection({required this.tone});

  final _FormationTone tone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final steps = [
      (Icons.table_chart_rounded, l10n.t('formations.stepImport')),
      (Icons.fact_check_rounded, l10n.t('formations.stepValidate')),
      (Icons.mark_email_read_rounded, l10n.t('formations.stepDraft')),
      (Icons.outgoing_mail, l10n.t('formations.stepSend')),
    ];

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
          Text(
            l10n.t('formations.workflow'),
            style: TextStyle(
              color: tone.text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          for (final (index, step) in steps.indexed) ...[
            _WorkflowStep(
              icon: step.$1,
              label: step.$2,
              index: index + 1,
              isLast: index == steps.length - 1,
              tone: tone,
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkflowStep extends StatelessWidget {
  const _WorkflowStep({
    required this.icon,
    required this.label,
    required this.index,
    required this.isLast,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final int index;
  final bool isLast;
  final _FormationTone tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppPalette.deepTeal,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppPalette.white, size: 19),
            ),
            if (!isLast) Container(width: 2, height: 18, color: tone.border),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
            child: Text(
              '$index. $label',
              style: TextStyle(
                color: tone.text,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyPlanningState extends StatelessWidget {
  const _EmptyPlanningState({required this.tone});

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.folder_open_rounded,
            color: AppPalette.amber,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('formations.emptyTitle'),
                  style: TextStyle(
                    color: tone.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  l10n.t('formations.emptySubtitle'),
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
        ],
      ),
    );
  }
}
