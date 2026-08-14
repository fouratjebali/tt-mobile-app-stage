import 'package:flutter/material.dart';

class PromptScreen extends StatefulWidget {
  const PromptScreen({super.key});

  @override
  State<PromptScreen> createState() => _PromptScreenState();
}

class _PromptScreenState extends State<PromptScreen> {
  final TextEditingController _promptController = TextEditingController();

  // ============================================================
  // CONVERSATION
  // ============================================================

  final List<Map<String, dynamic>> _messages = [];

  bool _showConfirmation = false;
  bool _isThinking = false;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  // ============================================================
  // SEND PROMPT
  // ============================================================

  void _sendPrompt() {
    final message = _promptController.text.trim();

    if (message.isEmpty) return;

    setState(() {
      // Add user message
      _messages.add({
        'type': 'user',
        'text': message,
      });

      _promptController.clear();

      _isThinking = true;
    });

    // Simulation of AI response
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;

      setState(() {
        _isThinking = false;

        _messages.add({
          'type': 'assistant',
          'text': _generateDemoResponse(message),
        });
      });
    });
  }

  // ============================================================
  // DEMO AI RESPONSE
  // ============================================================

  String _generateDemoResponse(String message) {
    final text = message.toLowerCase();

    if (text.contains('urgent')) {
      return 'I can check your urgent emails and show you the most important ones.';
    }

    if (text.contains('classif')) {
      return 'I can classify your inbox into categories such as urgent, support and information.';
    }

    if (text.contains('email') || text.contains('mail')) {
      return 'I can help you read, classify, summarize or reply to your emails.';
    }

    return 'I understood your instruction. I can help you manage your emails based on this request.';
  }

  // ============================================================
  // QUICK ACTION: URGENT EMAILS
  // ============================================================

  void _urgentEmails() {
    _promptController.text = 'Show me my urgent emails';
    _sendPrompt();
  }

  // ============================================================
  // QUICK ACTION: CLASSIFY INBOX
  // ============================================================

  void _classifyInbox() {
    _promptController.text = 'Classify my inbox';
    _sendPrompt();
  }

  // ============================================================
  // CONFIRM ACTION
  // ============================================================

  void _confirmAction() {
    setState(() {
      _showConfirmation = false;

      _messages.add({
        'type': 'assistant',
        'text': 'Action confirmed successfully.',
      });
    });
  }

  // ============================================================
  // CANCEL ACTION
  // ============================================================

  void _cancelAction() {
    setState(() {
      _showConfirmation = false;

      _messages.add({
        'type': 'assistant',
        'text': 'Action cancelled.',
      });
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF7F2E8);
    const primaryColor = Color(0xFF17473E);
    const textColor = Color(0xFF252B28);

    return Scaffold(
      backgroundColor: backgroundColor,

      // ==========================================================
      // BODY
      // ==========================================================

      body: SafeArea(
        child: Column(
          children: [

            // ======================================================
            // HEADER
            // ======================================================

            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                18,
                18,
                10,
              ),
              child: Row(
                children: [

                  const Expanded(
                    child: Text(
                      'Ask the assistant',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ),

                  IconButton(
                    onPressed: () {
                      setState(() {
                        _messages.clear();
                        _showConfirmation = false;
                        _isThinking = false;
                      });
                    },
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: 21,
                      color: Color(0xFF858B85),
                    ),
                  ),
                ],
              ),
            ),

            // ======================================================
            // QUICK ACTIONS
            // ======================================================

            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                ),
                children: [

                  GestureDetector(
                    onTap: _urgentEmails,
                    child: _quickAction(
                      icon: '✨',
                      text: 'Urgent emails',
                    ),
                  ),

                  const SizedBox(width: 8),

                  GestureDetector(
                    onTap: _classifyInbox,
                    child: _quickAction(
                      text: 'Classify inbox',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ======================================================
            // CONVERSATION
            // ======================================================

            Expanded(
              child: _messages.isEmpty && !_isThinking
                  ? _emptyConversation()
                  : ListView(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  8,
                  18,
                  10,
                ),
                children: [

                  // Dynamic messages
                  ..._messages.map((message) {
                    if (message['type'] == 'user') {
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: 9,
                        ),
                        child: _userMessage(
                          message['text'],
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: 9,
                      ),
                      child: _assistantMessage(
                        message['text'],
                      ),
                    );
                  }),

                  // Thinking
                  if (_isThinking)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: 9,
                      ),
                      child: _thinkingBox(),
                    ),

                  // Confirmation
                  if (_showConfirmation)
                    _confirmationBox(
                      onConfirm: _confirmAction,
                      onCancel: _cancelAction,
                    ),
                ],
              ),
            ),

            // ======================================================
            // INPUT
            // ======================================================

            Padding(
              padding: const EdgeInsets.fromLTRB(
                18,
                5,
                18,
                10,
              ),
              child: Row(
                children: [

                  // Text field
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFE1DCD1),
                        ),
                      ),
                      child: TextField(
                        controller: _promptController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendPrompt(),
                        decoration: const InputDecoration(
                          hintText: 'Type an instruction...',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9A9D98),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Send button
                  GestureDetector(
                    onTap: _sendPrompt,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // ============================================================
      // BOTTOM NAVIGATION
      // ============================================================

      bottomNavigationBar: _bottomNavigationBar(),
    );
  }

  // ==============================================================
  // EMPTY CONVERSATION
  // ==============================================================

  Widget _emptyConversation() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: 40,
          left: 40,
          right: 40,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            Icon(
              Icons.auto_awesome,
              size: 38,
              color: Color(0xFFB6B0A3),
            ),

            SizedBox(height: 12),

            Text(
              'How can I help you?',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF555B56),
              ),
            ),

            SizedBox(height: 5),

            Text(
              'Ask me anything about your emails.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF898D87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // QUICK ACTION
  // ==============================================================

  Widget _quickAction({
    String? icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE0DBD0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [

          if (icon != null) ...[
            Text(
              icon,
              style: const TextStyle(
                fontSize: 12,
              ),
            ),

            const SizedBox(width: 4),
          ],

          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF555B56),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // ASSISTANT MESSAGE
  // ==============================================================

  Widget _assistantMessage(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 250,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(
            color: const Color(0xFFE1DCD1),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            height: 1.35,
            color: Color(0xFF4B514D),
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // USER MESSAGE
  // ==============================================================

  Widget _userMessage(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 260,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF17473E),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            height: 1.35,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // THINKING
  // ==============================================================

  Widget _thinkingBox() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF17473E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [

          SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),

          SizedBox(width: 10),

          Text(
            'Thinking...',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // CONFIRMATION
  // ==============================================================

  Widget _confirmationBox({
    required VoidCallback onConfirm,
    required VoidCallback onCancel,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        12,
        10,
        12,
        11,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E3BD),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text(
            'Confirm action',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFFAA7621),
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children: [

              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF17473E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 7),

              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF37423D),
                      side: const BorderSide(
                        color: Color(0xFF37423D),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // BOTTOM NAVIGATION
  // ==============================================================

  Widget _bottomNavigationBar() {
    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: Color(0xFFFCF9F2),
        border: Border(
          top: BorderSide(
            color: Color(0xFFE2DDD2),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [

          _navItem(
            icon: Icons.home_outlined,
            label: 'Home',
          ),

          _navItem(
            icon: Icons.mail_outline_rounded,
            label: 'Today',
          ),

          _navItem(
            icon: Icons.lightbulb_outline_rounded,
            label: 'Review',
            notification: '3',
          ),

          _navItem(
            icon: Icons.person_outline_rounded,
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // NAV ITEM
  // ==============================================================

  Widget _navItem({
    required IconData icon,
    required String label,
    String? notification,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [

        Stack(
          clipBehavior: Clip.none,
          children: [

            Icon(
              icon,
              size: 22,
              color: const Color(0xFF858A85),
            ),

            if (notification != null)
              Positioned(
                right: -9,
                top: -7,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Color(0xFFB74A35),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    notification,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 3),

        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: Color(0xFF858A85),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}