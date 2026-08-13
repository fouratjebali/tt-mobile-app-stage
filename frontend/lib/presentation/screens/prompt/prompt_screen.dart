import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:tt_mail_assistant/domain/usecases/agent_usecase.dart';

class PromptScreen extends StatefulWidget {
  const PromptScreen({super.key});

  @override
  State<PromptScreen> createState() => _PromptScreenState();
}

class _PromptScreenState extends State<PromptScreen> {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _messageController =
  TextEditingController();

  final ScrollController _scrollController =
  ScrollController();

  // ============================================================
  // AGENT
  // ============================================================

  final AgentUseCase _agentUseCase =
  GetIt.I<AgentUseCase>();

  // ============================================================
  // STATE
  // ============================================================

  final List<ChatMessage> _messages = [];

  bool _isLoading = false;

  // ============================================================
  // QUICK SUGGESTIONS
  // ============================================================

  final List<String> _suggestions = [
    'Résumer mes emails',
    'Analyser cet email',
    'Préparer une réponse',
  ];

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();

    if (message.isEmpty || _isLoading) {
      return;
    }

    // Ajouter le message utilisateur
    setState(() {
      _messages.add(
        ChatMessage(
          text: message,
          isUser: true,
        ),
      );

      _messageController.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      // Appel Agent IA
      final response = await _agentUseCase.chat(message);

      if (!mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(
            text: response,
            isUser: false,
          ),
        );

        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          const ChatMessage(
            text:
            'Une erreur est survenue. Veuillez réessayer.',
            isUser: false,
          ),
        );

        _isLoading = false;
      });

      _scrollToBottom();
    }
  }

  // ============================================================
  // QUICK SUGGESTION
  // ============================================================

  void _useSuggestion(String suggestion) {
    if (_isLoading) return;

    _messageController.text = suggestion;

    _sendMessage();
  }

  // ============================================================
  // RESET CONVERSATION
  // ============================================================

  void _resetConversation() {
    setState(() {
      _messages.clear();
      _messageController.clear();
    });

    _scrollToTop();
  }

  // ============================================================
  // SCROLL TO BOTTOM
  // ============================================================

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  // ============================================================
  // SCROLL TO TOP
  // ============================================================

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Prompt / Chat',
        ),

        actions: [
          IconButton(
            tooltip: 'Réinitialiser',
            icon: const Icon(
              Icons.refresh,
            ),
            onPressed: _resetConversation,
          ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: SafeArea(
        child: Column(
          children: [

            // ==================================================
            // CHAT AREA
            // ==================================================

            Expanded(
              child: ListView(
                controller: _scrollController,

                // مهم للـ scroll
                physics:
                const AlwaysScrollableScrollPhysics(),

                padding: const EdgeInsets.all(16),

                children: [

                  // ============================================
                  // EMPTY CHAT
                  // ============================================

                  if (_messages.isEmpty)
                    const SizedBox(
                      height: 400,

                      child: Center(
                        child: Column(
                          mainAxisAlignment:
                          MainAxisAlignment.center,

                          children: [
                            Icon(
                              Icons.smart_toy_outlined,
                              size: 65,
                            ),

                            SizedBox(
                              height: 15,
                            ),

                            Text(
                              'Bonjour 👋',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),

                            SizedBox(
                              height: 8,
                            ),

                            Text(
                              'Comment puis-je vous aider ?',
                              textAlign:
                              TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ============================================
                  // MESSAGES
                  // ============================================

                  ..._messages.map(
                        (message) {
                      return MessageBubble(
                        message: message,
                      );
                    },
                  ),

                  // ============================================
                  // LOADING / REASONING
                  // ============================================

                  if (_isLoading)
                    const AgentThinking(),

                  // espace en bas
                  const SizedBox(
                    height: 10,
                  ),
                ],
              ),
            ),

            // ==================================================
            // QUICK SUGGESTIONS
            // ==================================================

            SizedBox(
              height: 55,

              child: ListView.separated(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 16,
                ),

                scrollDirection: Axis.horizontal,

                itemCount: _suggestions.length,

                separatorBuilder: (
                    context,
                    index,
                    ) {
                  return const SizedBox(
                    width: 8,
                  );
                },

                itemBuilder: (
                    context,
                    index,
                    ) {
                  final suggestion =
                  _suggestions[index];

                  return ActionChip(
                    label: Text(
                      suggestion,
                    ),

                    onPressed: _isLoading
                        ? null
                        : () {
                      _useSuggestion(
                        suggestion,
                      );
                    },
                  );
                },
              ),
            ),

            // ==================================================
            // INPUT
            // ==================================================

            Padding(
              padding: const EdgeInsets.all(12),

              child: Row(
                crossAxisAlignment:
                CrossAxisAlignment.end,

                children: [

                  // ==========================================
                  // TEXT FIELD
                  // ==========================================

                  Expanded(
                    child: TextField(
                      controller:
                      _messageController,

                      minLines: 1,

                      maxLines: 4,

                      textInputAction:
                      TextInputAction.send,

                      onSubmitted: (_) {
                        _sendMessage();
                      },

                      decoration:
                      InputDecoration(
                        hintText:
                        'Écrivez votre message...',

                        border:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(
                            20,
                          ),
                        ),

                        contentPadding:
                        const EdgeInsets
                            .symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  // ==========================================
                  // SEND BUTTON
                  // ==========================================

                  CircleAvatar(
                    child: IconButton(
                      icon: const Icon(
                        Icons.send,
                      ),

                      onPressed: _isLoading
                          ? null
                          : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// CHAT MESSAGE MODEL
// ================================================================

class ChatMessage {
  final String text;

  final bool isUser;

  const ChatMessage({
    required this.text,
    required this.isUser,
  });
}

// ================================================================
// MESSAGE BUBBLE
// ================================================================

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser
          ? Alignment.centerRight
          : Alignment.centerLeft,

      child: Container(
        constraints:
        const BoxConstraints(
          maxWidth: 330,
        ),

        margin:
        const EdgeInsets.only(
          bottom: 12,
        ),

        padding:
        const EdgeInsets.all(14),

        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context)
              .colorScheme
              .primary
              : Theme.of(context)
              .colorScheme
              .surfaceContainerHighest,

          borderRadius:
          BorderRadius.circular(16),
        ),

        child: Text(
          message.text,

          style: TextStyle(
            color: isUser
                ? Theme.of(context)
                .colorScheme
                .onPrimary
                : null,

            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

// ================================================================
// AGENT THINKING
// ================================================================

class AgentThinking extends StatelessWidget {
  const AgentThinking({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,

      margin:
      const EdgeInsets.only(
        bottom: 10,
      ),

      padding:
      const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,

        borderRadius:
        BorderRadius.circular(16),
      ),

      child: const Row(
        mainAxisSize:
        MainAxisSize.min,

        children: [

          SizedBox(
            width: 18,
            height: 18,

            child:
            CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),

          SizedBox(
            width: 10,
          ),

          Text(
            'Agent IA en train de réfléchir...',
          ),
        ],
      ),
    );
  }
}