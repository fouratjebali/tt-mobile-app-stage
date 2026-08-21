import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/di/di.dart';
import 'package:tt_mail_assistant/core/localization/app_localizations.dart';
import 'package:tt_mail_assistant/core/theme/app_palette.dart';
import 'package:tt_mail_assistant/domain/usecases/agent_usecase.dart';
import 'package:tt_mail_assistant/presentation/viewmodels/review_view_model.dart';
import 'package:tt_mail_assistant/presentation/widgets/app_bottom_navigation_bar.dart';

class PromptScreen extends StatefulWidget {
  const PromptScreen({super.key});

  @override
  State<PromptScreen> createState() => _PromptScreenState();
}

class _PromptScreenState extends State<PromptScreen> {
  late final AgentUseCase _agentUseCase;
  late final ReviewViewModel _reviewViewModel;
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];

  bool _showConfirmation = false;
  bool _isThinking = false;

  @override
  void initState() {
    super.initState();
    _agentUseCase = getIt<AgentUseCase>();
    _reviewViewModel = getIt<ReviewViewModel>();
    _reviewViewModel.addListener(_onReviewChanged);
  }

  @override
  void dispose() {
    _reviewViewModel.removeListener(_onReviewChanged);
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onReviewChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _sendPrompt([String? quickPrompt]) async {
    final message = (quickPrompt ?? _promptController.text).trim();
    if (message.isEmpty || _isThinking) return;

    setState(() {
      _messages.add(_ChatMessage.user(message));
      _promptController.clear();
      _isThinking = true;
    });
    _scrollToBottom();

    try {
      final response = await _agentUseCase.chat(message);
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _messages.add(_ChatMessage.assistant(response));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _messages.add(
          _ChatMessage.assistant(context.l10n.t('assistant.unreachable')),
        );
      });
    }
    _scrollToBottom();
  }

  void _confirmAction() {
    setState(() {
      _showConfirmation = false;
      _messages.add(
        _ChatMessage.assistant(context.l10n.t('assistant.confirmed')),
      );
    });
    _scrollToBottom();
  }

  void _cancelAction() {
    setState(() {
      _showConfirmation = false;
      _messages.add(
        _ChatMessage.assistant(context.l10n.t('assistant.cancelled')),
      );
    });
    _scrollToBottom();
  }

  void _resetConversation() {
    setState(() {
      _messages.clear();
      _showConfirmation = false;
      _isThinking = false;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final navItems = [
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101614) : AppPalette.mist,
      body: SafeArea(
        child: Column(
          children: [
            _AssistantHeader(
              isThinking: _isThinking,
              onReset: _resetConversation,
            ),
            _QuickPromptRail(onPromptSelected: _sendPrompt),
            Expanded(
              child:
                  _messages.isEmpty && !_isThinking
                      ? _EmptyConversation(onPromptSelected: _sendPrompt)
                      : _ConversationList(
                        controller: _scrollController,
                        messages: _messages,
                        isThinking: _isThinking,
                        showConfirmation: _showConfirmation,
                        onConfirm: _confirmAction,
                        onCancel: _cancelAction,
                      ),
            ),
            _PromptComposer(
              controller: _promptController,
              isThinking: _isThinking,
              onSend: () => _sendPrompt(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        selectedIndex: -1,
        reviewCount: _reviewViewModel.pendingCount,
        items: navItems,
        showAssistantSpace: false,
        onItemSelected: (index) => Navigator.pop(context, index),
      ),
    );
  }
}

class _AssistantHeader extends StatelessWidget {
  const _AssistantHeader({required this.isThinking, required this.onReset});

  final bool isThinking;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppPalette.white : AppPalette.ink;
    final l10n = context.l10n;
    final subColor =
        isDark
            ? Colors.white.withValues(alpha: 0.62)
            : AppPalette.pine.withValues(alpha: 0.66);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 10),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppPalette.deepTeal,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppPalette.deepTeal.withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppPalette.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('assistant.title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isThinking ? AppPalette.amber : AppPalette.teal,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isThinking
                            ? l10n.t('assistant.working')
                            : l10n.t('assistant.ready'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: subColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: onReset,
            style: IconButton.styleFrom(
              backgroundColor:
                  isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : AppPalette.paper,
              foregroundColor:
                  isDark
                      ? Colors.white.withValues(alpha: 0.76)
                      : AppPalette.pine,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _QuickPromptRail extends StatelessWidget {
  const _QuickPromptRail({required this.onPromptSelected});

  final ValueChanged<String> onPromptSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final prompts = [
      (l10n.t('assistant.unreadSummary'), l10n.t('assistant.promptUnread')),
      (l10n.t('assistant.urgentEmails'), l10n.t('assistant.promptUrgent')),
      (l10n.t('assistant.classifyInbox'), l10n.t('assistant.promptClassify')),
      (l10n.t('assistant.reviewQueue'), l10n.t('assistant.promptReview')),
    ];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: prompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prompt = prompts[index];
          return _QuickPromptChip(
            label: prompt.$1,
            onTap: () => onPromptSelected(prompt.$2),
          );
        },
      ),
    );
  }
}

class _QuickPromptChip extends StatelessWidget {
  const _QuickPromptChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? Colors.white.withValues(alpha: 0.07) : AppPalette.paper,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : AppPalette.line,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color:
                  isDark
                      ? Colors.white.withValues(alpha: 0.78)
                      : AppPalette.pine,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.controller,
    required this.messages,
    required this.isThinking,
    required this.showConfirmation,
    required this.onConfirm,
    required this.onCancel,
  });

  final ScrollController controller;
  final List<_ChatMessage> messages;
  final bool isThinking;
  final bool showConfirmation;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      children: [
        for (final message in messages)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MessageBubble(message: message),
          ),
        if (isThinking)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: _ThinkingBubble(),
          ),
        if (showConfirmation)
          _ConfirmationCard(onConfirm: onConfirm, onCancel: onCancel),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == _MessageRole.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor =
        isUser
            ? AppPalette.deepTeal
            : isDark
            ? Colors.white.withValues(alpha: 0.08)
            : AppPalette.paper;
    final borderColor =
        isUser
            ? Colors.transparent
            : isDark
            ? Colors.white.withValues(alpha: 0.08)
            : AppPalette.line;
    final textColor =
        isUser
            ? AppPalette.white
            : isDark
            ? AppPalette.white
            : AppPalette.pine;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[const _AssistantAvatar(), const SizedBox(width: 8)],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 310),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 6),
                  bottomRight: Radius.circular(isUser ? 6 : 20),
                ),
                border: Border.all(color: borderColor),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: SelectableText(
                message.text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  height: 1.42,
                  fontWeight: isUser ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppPalette.sage,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        size: 16,
        color: AppPalette.deepTeal,
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _AssistantAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color:
                  isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : AppPalette.paper,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color:
                    isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppPalette.line,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isDark ? AppPalette.lavender : AppPalette.deepTeal,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  context.l10n.t('assistant.thinking'),
                  style: TextStyle(
                    color:
                        isDark
                            ? Colors.white.withValues(alpha: 0.82)
                            : AppPalette.pine,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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

class _PromptComposer extends StatelessWidget {
  const _PromptComposer({
    required this.controller,
    required this.isThinking,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isThinking;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151C1A) : AppPalette.paper,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color:
                isDark ? Colors.white.withValues(alpha: 0.08) : AppPalette.line,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: TextStyle(
                  color: isDark ? AppPalette.white : AppPalette.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: context.l10n.t('assistant.inputHint'),
                  hintStyle: TextStyle(
                    color:
                        isDark
                            ? Colors.white.withValues(alpha: 0.38)
                            : AppPalette.pine.withValues(alpha: 0.44),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _SendButton(enabled: !isThinking, onTap: onSend),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          enabled
              ? AppPalette.deepTeal
              : AppPalette.pine.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(
            Icons.arrow_upward_rounded,
            color:
                enabled
                    ? AppPalette.white
                    : AppPalette.pine.withValues(alpha: 0.45),
            size: 23,
          ),
        ),
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation({required this.onPromptSelected});

  final ValueChanged<String> onPromptSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? AppPalette.white : AppPalette.ink;
    final l10n = context.l10n;
    final subColor =
        isDark
            ? Colors.white.withValues(alpha: 0.58)
            : AppPalette.pine.withValues(alpha: 0.64);

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 12, 30, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppPalette.deepTeal,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppPalette.deepTeal.withValues(alpha: 0.24),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.mark_email_read_outlined,
                color: AppPalette.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.t('assistant.emptyTitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: titleColor,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.t('assistant.emptySubtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: subColor,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _SuggestionButton(
                  label: l10n.t('assistant.summarizeLatest'),
                  prompt: l10n.t('assistant.promptUnread'),
                  onPromptSelected: onPromptSelected,
                ),
                _SuggestionButton(
                  label: l10n.t('assistant.findUrgent'),
                  prompt: l10n.t('assistant.promptUrgent'),
                  onPromptSelected: onPromptSelected,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionButton extends StatelessWidget {
  const _SuggestionButton({
    required this.label,
    required this.prompt,
    required this.onPromptSelected,
  });

  final String label;
  final String prompt;
  final ValueChanged<String> onPromptSelected;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () => onPromptSelected(prompt),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppPalette.deepTeal,
        side: BorderSide(color: AppPalette.deepTeal.withValues(alpha: 0.32)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    );
  }
}

class _ConfirmationCard extends StatelessWidget {
  const _ConfirmationCard({required this.onConfirm, required this.onCancel});

  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.amber.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.amber.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.t('assistant.confirmAction'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppPalette.amber,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.deepTeal,
                    foregroundColor: AppPalette.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(context.l10n.t('assistant.confirm')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppPalette.pine,
                    side: const BorderSide(color: AppPalette.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(context.l10n.t('settings.cancel')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _MessageRole { user, assistant }

class _ChatMessage {
  const _ChatMessage({required this.role, required this.text});

  factory _ChatMessage.user(String text) {
    return _ChatMessage(role: _MessageRole.user, text: text);
  }

  factory _ChatMessage.assistant(String text) {
    return _ChatMessage(role: _MessageRole.assistant, text: text);
  }

  final _MessageRole role;
  final String text;
}
