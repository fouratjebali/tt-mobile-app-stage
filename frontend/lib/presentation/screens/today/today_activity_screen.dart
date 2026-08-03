import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/di/di.dart';
import 'package:tt_mail_assistant/core/theme/app_palette.dart';
import 'package:tt_mail_assistant/domain/entities/email.dart';
import 'package:tt_mail_assistant/domain/usecases/email_usecase.dart';
import 'package:tt_mail_assistant/presentation/screens/email_detail/email_detail_screen.dart';

class TodayActivityScreen extends StatefulWidget {
  const TodayActivityScreen({super.key});

  @override
  State<TodayActivityScreen> createState() => _TodayActivityScreenState();
}

class _TodayActivityScreenState extends State<TodayActivityScreen>
    with TickerProviderStateMixin {
  late EmailUseCase _emailUseCase;
  late TabController _tabController;

  List<Email> allEmails = [];
  DateTime selectedDate = DateTime.now();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _emailUseCase = getIt<EmailUseCase>();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadEmails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    setState(() {});
  }

  Future<void> _loadEmails() async {
    try {
      final emails = await _emailUseCase.getTodayActivity();
      if (mounted) {
        setState(() {
          allEmails = emails;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  List<Email> _getFilteredEmails() {
    final tabIndex = _tabController.index;

    switch (tabIndex) {
      case 0: // All
        return allEmails;
      case 1: // Auto-sent
        return allEmails
            .where((e) => e.status == Status.DONE)
            .toList();
      case 2: // Review
        return allEmails
            .where((e) => e.status == Status.PENDING_USER_REVIEW)
            .toList();
      case 3: // Ignored
        return allEmails
            .where((e) => e.analysis?.priority == Priority.LOW)
            .toList();
      default:
        return allEmails;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppPalette.lavender,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      // TODO: Load emails for selected date
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredEmails = _getFilteredEmails();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Activity"),
        elevation: 0,
      ),
      body: Column(
        children: [
          // DATE SELECTOR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: GestureDetector(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppPalette.lavender.withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(selectedDate),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.calendar_today,
                      color: AppPalette.lavender,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // FILTER TABS
          TabBar(
            controller: _tabController,
            indicatorColor: AppPalette.lavender,
            labelColor: AppPalette.lavender,
            unselectedLabelColor: Colors.grey[500],
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            tabs: [
              Tab(
                text: 'All (${allEmails.length})',
              ),
              Tab(
                text: 'Auto-sent',
              ),
              Tab(
                text: 'Review',
              ),
              Tab(
                text: 'Ignored',
              ),
            ],
          ),

          // EMAIL LIST
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredEmails.isEmpty
                    ? _EmptyState(
                        tabIndex: _tabController.index,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadEmails,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: filteredEmails.length,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EmailDetailScreen(
                                      email: filteredEmails[index],
                                    ),
                                  ),
                                );
                              },
                              child: _EmailActivityCard(
                                email: filteredEmails[index],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    return '${date.day} ${_monthName(date.month)} ${date.year}';
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }
}

class _EmailActivityCard extends StatelessWidget {
  const _EmailActivityCard({required this.email});
  final Email email;

  String _getCategoryLabel(EmailCategory? category) {
    if (category == null) return 'INFO';
    switch (category) {
      case EmailCategory.RECLAMATION:
        return 'RECLAMATION';
      case EmailCategory.COMMERCIAL:
        return 'COMMERCIAL';
      case EmailCategory.SUPPORT:
        return 'SUPPORT';
      case EmailCategory.INFORMATION:
        return 'INFO';
    }
  }

  Color _getCategoryColor(EmailCategory? category) {
    if (category == null) return Colors.blue;
    switch (category) {
      case EmailCategory.RECLAMATION:
        return Colors.red;
      case EmailCategory.COMMERCIAL:
        return Colors.green;
      case EmailCategory.SUPPORT:
        return Colors.orange;
      case EmailCategory.INFORMATION:
        return Colors.blue;
    }
  }

  String _getPriorityLabel(Priority priority) {
    switch (priority) {
      case Priority.URGENT:
        return 'URGENT';
      case Priority.NORMAL:
        return 'NORMAL';
      case Priority.LOW:
        return 'LOW';
    }
  }

  Color _getPriorityColor(Priority priority) {
    switch (priority) {
      case Priority.URGENT:
        return Colors.red;
      case Priority.NORMAL:
        return Colors.orange;
      case Priority.LOW:
        return Colors.green;
    }
  }

  String _getStatusLabel(Status status) {
    switch (status) {
      case Status.DONE:
        return 'Auto-sent';
      case Status.PENDING_USER_REVIEW:
        return 'Hands review';
      case Status.PENDING_JURY:
        return 'Jury';
      case Status.PENDING_ANALYSIS:
        return 'Analysis';
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final priority = email.analysis?.priority ?? Priority.NORMAL;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Subject + Category Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        email.subject,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        email.from.email,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(email.date),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(email.analysis?.category)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getCategoryLabel(email.analysis?.category),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color:
                          _getCategoryColor(email.analysis?.category),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Priority + Status Badges
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(priority).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getPriorityLabel(priority),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _getPriorityColor(priority),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppPalette.lavender.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getStatusLabel(email.status),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.lavender,
                    ),
                  ),
                ),
              ],
            ),

            // Attachments + Stats
            if (email.attachments.isNotEmpty || email.analysis != null) ...[
              const SizedBox(height: 12),
              Text(
                email.attachments.isNotEmpty
                    ? '${email.attachments.length} email${email.attachments.length > 1 ? 's' : ''} with attachments'
                    : email.analysis != null
                        ? 'AI confidence: ${(email.analysis!.confidence * 100).toStringAsFixed(0)}%'
                        : '',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tabIndex});
  final int tabIndex;

  String _getEmptyMessage() {
    switch (tabIndex) {
      case 0:
        return 'No emails processed today';
      case 1:
        return 'No auto-sent emails today';
      case 2:
        return 'No emails waiting for review';
      case 3:
        return 'No ignored emails today';
      default:
        return 'No emails';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            _getEmptyMessage(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}
