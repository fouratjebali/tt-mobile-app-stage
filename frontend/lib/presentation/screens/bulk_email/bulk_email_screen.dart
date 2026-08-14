import 'package:flutter/material.dart';

import '../../../data/services/bulk_email_api_service.dart';
import 'bulk_email_controller.dart';

class BulkEmailScreen extends StatefulWidget {
  const BulkEmailScreen({super.key});

  @override
  State<BulkEmailScreen> createState() => _BulkEmailScreenState();
}

class _BulkEmailScreenState extends State<BulkEmailScreen> {
  late final BulkEmailController _controller;

  final TextEditingController _campaignController =
  TextEditingController();

  final List<Map<String, String>> _recipients = [];

  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();

    _controller = BulkEmailController(
      apiService: BulkEmailApiService(
        baseUrl: 'http://10.0.2.2:8000',
      ),
    );
  }

  @override
  void dispose() {
    _campaignController.dispose();
    super.dispose();
  }

  // ============================================================
  // ADD RECIPIENT
  // ============================================================

  void _showAddRecipientDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final roleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF7F2E8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Add recipient',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF26332F),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(
                controller: nameController,
                hintText: 'Name',
              ),
              const SizedBox(height: 10),
              _dialogField(
                controller: emailController,
                hintText: 'Email',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              _dialogField(
                controller: roleController,
                hintText: 'Role',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF6E756F),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final email = emailController.text.trim();
                final role = roleController.text.trim();

                if (name.isEmpty || email.isEmpty) {
                  return;
                }

                setState(() {
                  _recipients.add({
                    'initials': _getInitials(name),
                    'name': name,
                    'email': email,
                    'role': role.isEmpty ? 'Recipient' : role,
                  });
                });

                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF17473E),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // GET INITIALS
  // ============================================================

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));

    if (parts.isEmpty || parts.first.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  // ============================================================
  // REMOVE RECIPIENT
  // ============================================================

  void _removeRecipient(int index) {
    setState(() {
      _recipients.removeAt(index);
    });
  }

  // ============================================================
  // GENERATE EMAILS
  // ============================================================

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
      final recipients = _recipients
          .map((recipient) => recipient['email']!)
          .toList();

      await _controller.generateEmails(
        recipients: recipients,
        topic: campaign,
      );

      if (!mounted) return;

      if (_controller.error != null) {
        _showMessage(_controller.error!);
        return;
      }

      _showMessage(
        '${_controller.generatedEmails.length} emails generated successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage('Generation failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  // ============================================================
  // PREVIEW & SEND
  // ============================================================

  void _previewAndSend() {
    final campaign = _campaignController.text.trim();

    if (campaign.isEmpty) {
      _showMessage(
        'Please enter a campaign topic.',
      );
      return;
    }

    if (_recipients.isEmpty) {
      _showMessage(
        'Please add at least one recipient.',
      );
      return;
    }

    _showPreviewDialog();
  }

  // ============================================================
  // PREVIEW DIALOG
  // ============================================================

  void _showPreviewDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF7F2E8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Preview & send',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF26332F),
            ),
          ),
          content: SizedBox(
            width: 350,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Campaign topic',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6E756F),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _campaignController.text.trim(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF26332F),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Recipients',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6E756F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._recipients.map(
                        (recipient) => Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Text(
                        '${recipient['name']} — ${recipient['email']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4F5752),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Close',
                style: TextStyle(
                  color: Color(0xFF6E756F),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);

                _showMessage(
                  'Emails ready to send.',
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF17473E),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // DIALOG FIELD
  // ============================================================

  Widget _dialogField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF7F2E8);
    const primaryColor = Color(0xFF17473E);
    const textColor = Color(0xFF26332F);
    const secondaryTextColor = Color(0xFF6E756F);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ======================================================
              // HEADER
              // ======================================================

              const Text(
                'Bulk email',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),

              const SizedBox(height: 4),

              const Text(
                'AI drafts for multiple recipients',
                style: TextStyle(
                  fontSize: 13,
                  color: secondaryTextColor,
                ),
              ),

              const SizedBox(height: 28),

              // ======================================================
              // CAMPAIGN TOPIC
              // ======================================================

              const Text(
                'CAMPAIGN TOPIC',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: secondaryTextColor,
                ),
              ),

              const SizedBox(height: 9),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFE4DED2),
                  ),
                ),
                child: TextField(
                  controller: _campaignController,
                  style: const TextStyle(
                    fontSize: 14,
                    color: textColor,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Enter campaign topic...',
                    hintStyle: TextStyle(
                      fontSize: 14,
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

              const SizedBox(height: 25),

              // ======================================================
              // RECIPIENTS TITLE
              // ======================================================

              const Text(
                'RECIPIENTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: secondaryTextColor,
                ),
              ),

              const SizedBox(height: 10),

              // ======================================================
              // RECIPIENTS
              // ======================================================

              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ...List.generate(
                      _recipients.length,
                          (index) {
                        final recipient = _recipients[index];

                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: 9,
                          ),
                          child: _recipientCard(
                            initials: recipient['initials']!,
                            name: recipient['name']!,
                            email: recipient['email']!,
                            role: recipient['role']!,
                            index: index,
                          ),
                        );
                      },
                    ),

                    // ==================================================
                    // ADD RECIPIENT
                    // ==================================================

                    GestureDetector(
                      onTap: _showAddRecipientDialog,
                      child: Container(
                        height: 58,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9F5EC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFFE4DED2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            Container(
                              width: 34,
                              height: 34,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEFE9DB),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add,
                                size: 20,
                                color: Color(0xFF8B918A),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Add recipient',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF9A9C96),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ==================================================
                    // GENERATE EMAILS
                    // ==================================================

                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                        _isGenerating ? null : _generateEmails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                          const Color(0xFF78938D),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: _isGenerating
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Row(
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 17,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Generate emails',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ==================================================
                    // PREVIEW & SEND
                    // ==================================================

                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _previewAndSend,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: const BorderSide(
                            color: primaryColor,
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text(
                          'Preview & send',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // RECIPIENT CARD
  // ================================================================

  Widget _recipientCard({
    required String initials,
    required String name,
    required String email,
    required String role,
    required int index,
  }) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 70,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE4DED2),
        ),
      ),
      child: Row(
        children: [
          // ==========================================================
          // AVATAR
          // ==========================================================

          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: index.isEven
                  ? const Color(0xFF234E46)
                  : const Color(0xFFC08A35),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // ==========================================================
          // NAME + ROLE + EMAIL
          // ==========================================================

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF26332F),
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF858A84),
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF9A9D98),
                  ),
                ),
              ],
            ),
          ),

          // ==========================================================
          // DELETE
          // ==========================================================

          IconButton(
            onPressed: () => _removeRecipient(index),
            icon: const Icon(
              Icons.close,
              size: 17,
              color: Color(0xFF8B918A),
            ),
          ),
        ],
      ),
    );
  }
}