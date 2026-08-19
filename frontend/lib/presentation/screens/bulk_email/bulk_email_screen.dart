import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/di/di.dart';
import 'package:tt_mail_assistant/core/errors/error_message.dart';
import 'package:tt_mail_assistant/core/theme/app_palette.dart';
import 'package:tt_mail_assistant/data/datasources/remote/api_service.dart';
import 'package:tt_mail_assistant/data/models/bulk_email.dart';
import 'package:tt_mail_assistant/data/services/bulk_email_api_service.dart';
import 'package:tt_mail_assistant/domain/usecases/settings_usecase.dart';
import 'package:tt_mail_assistant/presentation/viewmodels/review_view_model.dart';
import 'package:tt_mail_assistant/presentation/widgets/app_bottom_navigation_bar.dart';

import 'bulk_email_controller.dart';

class BulkEmailScreen extends StatefulWidget {
  const BulkEmailScreen({super.key});

  @override
  State<BulkEmailScreen> createState() => _BulkEmailScreenState();
}

class _BulkEmailScreenState extends State<BulkEmailScreen> {
  late final BulkEmailController _controller;
  late final ReviewViewModel _reviewViewModel;
  late final SettingsUseCase _settingsUseCase;
  final TextEditingController _campaignController = TextEditingController();
  final List<Map<String, String>> _recipients = [];

  bool _isGenerating = false;
  _DraftTone _draftTone = _DraftTone.professional;
  _DraftLength _draftLength = _DraftLength.short;
  String _replyLanguage = 'English';

  static const _navItems = [
    AppNavigationItemData(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    AppNavigationItemData(
      label: 'Today',
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today_rounded,
    ),
    AppNavigationItemData(
      label: 'Review',
      icon: Icons.mark_email_unread_outlined,
      activeIcon: Icons.mark_email_unread_rounded,
    ),
    AppNavigationItemData(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = BulkEmailController(
      apiService: BulkEmailApiService(apiService: getIt<ApiService>()),
    );
    _reviewViewModel = getIt<ReviewViewModel>();
    _settingsUseCase = getIt<SettingsUseCase>();
    _reviewViewModel.addListener(_onReviewChanged);
    _loadDraftDefaults();
  }

  @override
  void dispose() {
    _reviewViewModel.removeListener(_onReviewChanged);
    _campaignController.dispose();
    super.dispose();
  }

  void _onReviewChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadDraftDefaults() async {
    final language = await _settingsUseCase.getReplyLanguage();
    if (!mounted) return;
    setState(() {
      _replyLanguage = _normalizeLanguage(language);
    });
  }

  Future<void> _showAddRecipientDialog() async {
    final recipient = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const _AddRecipientDialog(),
    );

    if (recipient == null) return;
    setState(() {
      _recipients.add(recipient);
    });
  }

  void _removeRecipient(int index) {
    setState(() {
      _recipients.removeAt(index);
    });
  }

  Future<void> _generateEmails() async {
    final campaign = _campaignController.text.trim();

    if (campaign.isEmpty) {
      _showMessage('Please enter a campaign topic.');
      return;
    }
    if (_recipients.isEmpty) {
      _showMessage('Please add at least one recipient.');
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      await _controller.generateEmails(
        recipients: _bulkRecipientsPayload(),
        topic: campaign,
        instructions: _draftInstructions(),
      );

      if (!mounted) return;
      if (_controller.error != null) {
        _showMessage(_friendlyError(_controller.error!));
        return;
      }

      _showMessage(
        '${_controller.generatedEmails.length} emails generated successfully.',
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(_friendlyError(e.toString()));
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  void _previewAndSend() {
    final campaign = _campaignController.text.trim();

    if (campaign.isEmpty) {
      _showMessage('Please enter a campaign topic.');
      return;
    }
    if (_recipients.isEmpty) {
      _showMessage('Please add at least one recipient.');
      return;
    }
    if (_controller.generatedEmails.isEmpty) {
      _showMessage('Generate drafts first, then preview and edit them.');
      return;
    }

    _showPreviewDialog();
  }

  Future<void> _sendGeneratedEmails() async {
    await _controller.sendGeneratedDrafts();

    if (!mounted) return;
    if (_controller.error != null) {
      _showMessage(_friendlyError(_controller.error!));
      return;
    }

    final sent = _controller.results.where((result) => result.isSuccess).length;
    _showMessage(
      'Bulk send completed: $sent/${_controller.results.length} sent.',
    );
  }

  List<Map<String, String>> _bulkRecipientsPayload() {
    return _recipients
        .map(
          (recipient) => {
            'name': recipient['name'] ?? '',
            'email': recipient['email'] ?? '',
            'role': recipient['role'] ?? 'Recipient',
            'context': recipient['role'] ?? '',
          },
        )
        .toList();
  }

  String _draftInstructions() {
    return [
      'Write in $_replyLanguage.',
      'Tone: ${_draftTone.instruction}.',
      'Length: ${_draftLength.instruction}.',
      'Personalize each draft using the recipient name, role, and context.',
      'Keep the subject clear and specific.',
      'Do not mention AI, automation, or internal tools.',
    ].join(' ');
  }

  String _normalizeLanguage(String value) {
    return value.toLowerCase() == 'french' ? 'French' : 'English';
  }

  void _showPreviewDialog() {
    showDialog<void>(
      context: context,
      builder:
          (context) => _PreviewAndEditDialog(
            campaign: _campaignController.text.trim(),
            drafts: _controller.generatedEmails,
            onSaveDrafts: _controller.replaceGenerated,
            onSend: _sendGeneratedEmails,
          ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _friendlyError(String message) {
    return ErrorMessage.fromException(message);
  }

  @override
  Widget build(BuildContext context) {
    final tone = _BulkTone.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          children: [
            _BulkHeader(
              recipientsCount: _recipients.length,
              draftsCount: _controller.generatedEmails.length,
            ),
            const SizedBox(height: 20),
            _SectionLabel(text: 'Campaign'),
            const SizedBox(height: 8),
            _CampaignField(controller: _campaignController),
            const SizedBox(height: 18),
            _DraftQualityControls(
              tone: _draftTone,
              length: _draftLength,
              language: _replyLanguage,
              onToneChanged: (value) {
                setState(() {
                  _draftTone = value;
                });
              },
              onLengthChanged: (value) {
                setState(() {
                  _draftLength = value;
                });
              },
              onLanguageChanged: (value) {
                setState(() {
                  _replyLanguage = value;
                });
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: _SectionLabel(text: 'Recipients')),
                _CountPill(label: '${_recipients.length} added'),
              ],
            ),
            const SizedBox(height: 10),
            if (_recipients.isEmpty)
              const _EmptyRecipients()
            else
              ...List.generate(_recipients.length, (index) {
                final recipient = _recipients[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _RecipientCard(
                    initials: recipient['initials']!,
                    name: recipient['name']!,
                    email: recipient['email']!,
                    role: recipient['role']!,
                    index: index,
                    onRemove: () => _removeRecipient(index),
                  ),
                );
              }),
            _AddRecipientButton(onTap: _showAddRecipientDialog),
            const SizedBox(height: 18),
            if (_isGenerating) ...[
              _GenerationProgress(recipientCount: _recipients.length),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: tone.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tone.border),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 50,
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isGenerating ? null : _generateEmails,
                      icon:
                          _isGenerating
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppPalette.white,
                                ),
                              )
                              : const Icon(Icons.auto_awesome_rounded),
                      label: Text(
                        _isGenerating
                            ? 'Preparing your drafts'
                            : 'Generate drafts',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 50,
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isGenerating ? null : _previewAndSend,
                      icon: const Icon(Icons.edit_note_rounded, size: 20),
                      label: const Text('Preview and edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppPalette.deepTeal,
                        side: BorderSide(
                          color: AppPalette.deepTeal.withValues(alpha: 0.44),
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        selectedIndex: -1,
        reviewCount: _reviewViewModel.pendingCount,
        items: _navItems,
        showAssistantSpace: false,
        onItemSelected: (index) => Navigator.pop(context, index),
      ),
    );
  }
}

class _BulkTone {
  const _BulkTone({
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

  static _BulkTone of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _BulkTone(
      surface: isDark ? const Color(0xFF151C1A) : AppPalette.paper,
      softSurface:
          isDark
              ? AppPalette.white.withValues(alpha: 0.07)
              : AppPalette.sage.withValues(alpha: 0.65),
      border:
          isDark ? AppPalette.white.withValues(alpha: 0.08) : AppPalette.line,
      text: isDark ? AppPalette.white : AppPalette.ink,
      muted:
          isDark
              ? AppPalette.white.withValues(alpha: 0.62)
              : AppPalette.pine.withValues(alpha: 0.68),
    );
  }
}

enum _DraftTone {
  professional(
    'Professional',
    'polished, respectful, and business-appropriate',
  ),
  friendly('Friendly', 'warm, natural, and approachable'),
  direct('Direct', 'clear, simple, and straight to the point');

  const _DraftTone(this.label, this.instruction);

  final String label;
  final String instruction;
}

enum _DraftLength {
  short('Short', 'keep it brief, around 3 to 5 sentences'),
  detailed('Detailed', 'include helpful context while staying easy to scan');

  const _DraftLength(this.label, this.instruction);

  final String label;
  final String instruction;
}

class _DraftQualityControls extends StatelessWidget {
  const _DraftQualityControls({
    required this.tone,
    required this.length,
    required this.language,
    required this.onToneChanged,
    required this.onLengthChanged,
    required this.onLanguageChanged,
  });

  final _DraftTone tone;
  final _DraftLength length;
  final String language;
  final ValueChanged<_DraftTone> onToneChanged;
  final ValueChanged<_DraftLength> onLengthChanged;
  final ValueChanged<String> onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    final toneColors = _BulkTone.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: toneColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: toneColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune_rounded,
                size: 18,
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? AppPalette.lavender
                        : AppPalette.deepTeal,
              ),
              const SizedBox(width: 7),
              Text(
                'Draft style',
                style: TextStyle(
                  color: toneColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ControlLabel(text: 'Tone'),
          const SizedBox(height: 7),
          _ChoiceWrap<_DraftTone>(
            value: tone,
            values: _DraftTone.values,
            labelFor: (value) => value.label,
            onChanged: onToneChanged,
          ),
          const SizedBox(height: 12),
          _ControlLabel(text: 'Length'),
          const SizedBox(height: 7),
          _ChoiceWrap<_DraftLength>(
            value: length,
            values: _DraftLength.values,
            labelFor: (value) => value.label,
            onChanged: onLengthChanged,
          ),
          const SizedBox(height: 12),
          _ControlLabel(text: 'Language'),
          const SizedBox(height: 7),
          _ChoiceWrap<String>(
            value: language,
            values: const ['English', 'French'],
            labelFor: (value) => value,
            onChanged: onLanguageChanged,
          ),
        ],
      ),
    );
  }
}

class _ControlLabel extends StatelessWidget {
  const _ControlLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tone = _BulkTone.of(context);
    return Text(
      text,
      style: TextStyle(
        color: tone.muted,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _ChoiceWrap<T> extends StatelessWidget {
  const _ChoiceWrap({
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
  });

  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          values.map((item) {
            final selected = item == value;
            return _ChoiceChipButton(
              label: labelFor(item),
              selected: selected,
              onTap: () => onChanged(item),
            );
          }).toList(),
    );
  }
}

class _ChoiceChipButton extends StatelessWidget {
  const _ChoiceChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = _BulkTone.of(context);
    final activeColor =
        Theme.of(context).brightness == Brightness.dark
            ? AppPalette.lavender
            : AppPalette.deepTeal;

    return Material(
      color: selected ? activeColor.withValues(alpha: 0.14) : tone.softSurface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  selected ? activeColor.withValues(alpha: 0.36) : tone.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? activeColor : tone.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _AddRecipientDialog extends StatefulWidget {
  const _AddRecipientDialog();

  @override
  State<_AddRecipientDialog> createState() => _AddRecipientDialogState();
}

class _AddRecipientDialogState extends State<_AddRecipientDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final role = _roleController.text.trim();
    if (name.isEmpty || email.isEmpty) return;

    Navigator.pop(context, {
      'initials': _recipientInitials(name),
      'name': name,
      'email': email,
      'role': role.isEmpty ? 'Recipient' : role,
    });
  }

  @override
  Widget build(BuildContext context) {
    final tone = _BulkTone.of(context);

    return AlertDialog(
      backgroundColor: tone.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: tone.border),
      ),
      title: Text(
        'Add recipient',
        style: TextStyle(
          color: tone.text,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DialogField(controller: _nameController, hintText: 'Name'),
          const SizedBox(height: 10),
          _DialogField(
            controller: _emailController,
            hintText: 'Email',
            keyboardType: TextInputType.emailAddress,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 10),
          _DialogField(
            controller: _roleController,
            hintText: 'Role',
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: tone.muted)),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}

class _BulkHeader extends StatelessWidget {
  const _BulkHeader({required this.recipientsCount, required this.draftsCount});

  final int recipientsCount;
  final int draftsCount;

  @override
  Widget build(BuildContext context) {
    final tone = _BulkTone.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Group drafts',
                  style: TextStyle(
                    color: tone.text,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _HeaderMetric(
                value: '$recipientsCount',
                label: recipientsCount == 1 ? 'recipient' : 'recipients',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Prepare personalized messages for several people.',
            style: TextStyle(
              color: tone.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          if (draftsCount > 0) ...[
            const SizedBox(height: 10),
            _HeaderStatus(label: '$draftsCount drafts ready'),
          ],
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? AppPalette.lavender : AppPalette.deepTeal;

    return Container(
      constraints: const BoxConstraints(minWidth: 72),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderStatus extends StatelessWidget {
  const _HeaderStatus({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? AppPalette.lavender : AppPalette.deepTeal;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline_rounded, color: color, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tone = _BulkTone.of(context);
    return Text(
      text,
      style: TextStyle(
        color: tone.muted,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _CampaignField extends StatelessWidget {
  const _CampaignField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final tone = _BulkTone.of(context);

    return Container(
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.border),
      ),
      child: TextField(
        controller: controller,
        minLines: 2,
        maxLines: 4,
        style: TextStyle(
          color: tone.text,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'Example: invite partners to the summer event',
          hintStyle: TextStyle(
            color: tone.muted.withValues(alpha: 0.72),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppPalette.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? AppPalette.lavender
                  : AppPalette.deepTeal,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyRecipients extends StatelessWidget {
  const _EmptyRecipients();

  @override
  Widget build(BuildContext context) {
    final tone = _BulkTone.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.person_add_alt_outlined,
            color: tone.muted.withValues(alpha: 0.74),
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            'No recipients yet',
            style: TextStyle(
              color: tone.text,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add people first, then generate personalized drafts.',
            textAlign: TextAlign.center,
            style: TextStyle(color: tone.muted, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _AddRecipientButton extends StatelessWidget {
  const _AddRecipientButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = _BulkTone.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: tone.softSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tone.border),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppPalette.deepTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 21,
                  color: AppPalette.deepTeal,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Add recipient',
                style: TextStyle(
                  color: tone.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenerationProgress extends StatelessWidget {
  const _GenerationProgress({required this.recipientCount});

  final int recipientCount;

  @override
  Widget build(BuildContext context) {
    final tone = _BulkTone.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.teal.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppPalette.teal.withValues(alpha: isDark ? 0.30 : 0.18),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: isDark ? AppPalette.lavender : AppPalette.deepTeal,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preparing personalized drafts',
                  style: TextStyle(
                    color: tone.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This can take a little while for $recipientCount recipients. You can stay on this screen while we prepare them.',
                  style: TextStyle(
                    color: tone.muted,
                    fontSize: 12,
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

class _RecipientCard extends StatelessWidget {
  const _RecipientCard({
    required this.initials,
    required this.name,
    required this.email,
    required this.role,
    required this.index,
    required this.onRemove,
  });

  final String initials;
  final String name;
  final String email;
  final String role;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tone = _BulkTone.of(context);
    final avatarColor = index.isEven ? AppPalette.deepTeal : AppPalette.amber;

    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: tone.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: avatarColor,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                color: AppPalette.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tone.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tone.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tone.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove recipient',
            onPressed: onRemove,
            icon: Icon(Icons.close_rounded, size: 19, color: tone.muted),
          ),
        ],
      ),
    );
  }
}

String _recipientInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final tone = _BulkTone.of(context);
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction:
          onSubmitted == null ? TextInputAction.next : TextInputAction.done,
      onSubmitted: onSubmitted,
      style: TextStyle(color: tone.text, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: tone.muted),
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.teal, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }
}

class _PreviewLabel extends StatelessWidget {
  const _PreviewLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tone = _BulkTone.of(context);
    return Text(
      text,
      style: TextStyle(
        color: tone.muted,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _PreviewAndEditDialog extends StatefulWidget {
  const _PreviewAndEditDialog({
    required this.campaign,
    required this.drafts,
    required this.onSaveDrafts,
    required this.onSend,
  });

  final String campaign;
  final List<BulkEmail> drafts;
  final ValueChanged<List<BulkEmail>> onSaveDrafts;
  final Future<void> Function() onSend;

  @override
  State<_PreviewAndEditDialog> createState() => _PreviewAndEditDialogState();
}

class _PreviewAndEditDialogState extends State<_PreviewAndEditDialog> {
  late final List<TextEditingController> _subjectControllers;
  late final List<TextEditingController> _bodyControllers;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _subjectControllers =
        widget.drafts
            .map((draft) => TextEditingController(text: draft.subject))
            .toList();
    _bodyControllers =
        widget.drafts
            .map((draft) => TextEditingController(text: draft.body))
            .toList();
  }

  @override
  void dispose() {
    for (final controller in _subjectControllers) {
      controller.dispose();
    }
    for (final controller in _bodyControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _isSending = true;
    });
    widget.onSaveDrafts(_editedDrafts());
    await widget.onSend();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  List<BulkEmail> _editedDrafts() {
    return List.generate(widget.drafts.length, (index) {
      return widget.drafts[index].copyWith(
        subject: _subjectControllers[index].text.trim(),
        body: _bodyControllers[index].text.trim(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final tone = _BulkTone.of(context);

    return AlertDialog(
      backgroundColor: tone.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: tone.border),
      ),
      title: Text(
        'Preview and edit',
        style: TextStyle(
          color: tone.text,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PreviewLabel(text: 'Campaign topic'),
              const SizedBox(height: 6),
              Text(
                widget.campaign,
                style: TextStyle(
                  color: tone.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              _PreviewLabel(text: 'Drafts'),
              const SizedBox(height: 10),
              ...List.generate(widget.drafts.length, (index) {
                final draft = widget.drafts[index];
                return _EditableDraftCard(
                  draft: draft,
                  subjectController: _subjectControllers[index],
                  bodyController: _bodyControllers[index],
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.pop(context),
          child: Text('Close', style: TextStyle(color: tone.muted)),
        ),
        FilledButton.icon(
          onPressed: _isSending ? null : _send,
          icon:
              _isSending
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppPalette.white,
                    ),
                  )
                  : const Icon(Icons.send_rounded, size: 18),
          label: Text(_isSending ? 'Sending' : 'Send'),
        ),
      ],
    );
  }
}

class _EditableDraftCard extends StatelessWidget {
  const _EditableDraftCard({
    required this.draft,
    required this.subjectController,
    required this.bodyController,
  });

  final BulkEmail draft;
  final TextEditingController subjectController;
  final TextEditingController bodyController;

  @override
  Widget build(BuildContext context) {
    final tone = _BulkTone.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.softSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            draft.recipient,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tone.text,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          _EditableDraftField(
            controller: subjectController,
            label: 'Subject',
            maxLines: 1,
          ),
          const SizedBox(height: 8),
          _EditableDraftField(
            controller: bodyController,
            label: 'Message',
            maxLines: 7,
          ),
        ],
      ),
    );
  }
}

class _EditableDraftField extends StatelessWidget {
  const _EditableDraftField({
    required this.controller,
    required this.label,
    required this.maxLines,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final tone = _BulkTone.of(context);

    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(
        color: tone.text,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: tone.muted, fontWeight: FontWeight.w700),
        filled: true,
        fillColor: tone.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tone.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tone.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppPalette.teal, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }
}
