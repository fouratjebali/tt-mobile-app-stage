import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/di/di.dart';
import 'package:tt_mail_assistant/core/theme/app_palette.dart';
import 'package:tt_mail_assistant/domain/entities/email.dart';
import 'package:tt_mail_assistant/presentation/screens/email_detail/email_detail_screen.dart';
import 'package:tt_mail_assistant/presentation/viewmodels/activity_view_model.dart';
import 'package:tt_mail_assistant/core/state/load_state.dart';

class TodayActivityScreen extends StatefulWidget {
  const TodayActivityScreen({super.key});

  @override
  State<TodayActivityScreen> createState() => _TodayActivityScreenState();
}

class _TodayActivityScreenState extends State<TodayActivityScreen>
    with TickerProviderStateMixin {
  late final ActivityViewModel _viewModel;
  late final TabController _tabController;

  static const _tabFilters = [
    ActivityFilter.all,
    ActivityFilter.autoSent,
    ActivityFilter.review,
    ActivityFilter.low,
  ];

  @override
  void initState() {
    super.initState();
    _viewModel = getIt<ActivityViewModel>();
    _viewModel.addListener(_onChanged);
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _viewModel.loadTodayEmails();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      _viewModel.applyFilter(_tabFilters[_tabController.index]);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _viewModel.selectedDate,
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

    if (picked != null && picked != _viewModel.selectedDate) {
      await _viewModel.selectDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredEmails = _viewModel.filteredEmails;
    final isLoading =
        _viewModel.state == LoadState.loading ||
        _viewModel.state == LoadState.idle;

    return Scaffold(
      appBar: AppBar(title: const Text("Today's Activity"), elevation: 0),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
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
                        borderRadius: BorderRadius.circular(8),
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
                                _formatDate(_viewModel.selectedDate),
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
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Previous day',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _viewModel.loadPreviousDay,
                ),
              ],
            ),
          ),
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
              Tab(text: 'All (${_viewModel.allEmails.length})'),
              Tab(text: 'Auto (${_countStatus(Status.DONE)})'),
              Tab(text: 'Review (${_countStatus(Status.PENDING_USER_REVIEW)})'),
              Tab(text: 'Low (${_countLowPriority()})'),
            ],
          ),
          Expanded(
            child:
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredEmails.isEmpty
                    ? _EmptyState(tabIndex: _tabController.index)
                    : RefreshIndicator(
                      onRefresh: _viewModel.loadTodayEmails,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount:
                            filteredEmails.length +
                            (_viewModel.state == LoadState.error ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_viewModel.state == LoadState.error &&
                              index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _Notice(
                                message: _viewModel.errorMessage ?? '',
                              ),
                            );
                          }
                          final emailIndex =
                              _viewModel.state == LoadState.error
                                  ? index - 1
                                  : index;
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => EmailDetailScreen(
                                        email: filteredEmails[emailIndex],
                                      ),
                                ),
                              );
                            },
                            child: _EmailActivityCard(
                              email: filteredEmails[emailIndex],
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

  int _countStatus(Status status) {
    return _viewModel.allEmails.where((email) => email.status == status).length;
  }

  int _countLowPriority() {
    return _viewModel.allEmails
        .where((email) => email.analysis?.priority == Priority.LOW)
        .length;
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
      'Dec',
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(email.date),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(
                      email.analysis?.category,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getCategoryLabel(email.analysis?.category),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _getCategoryColor(email.analysis?.category),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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
                    ? '${email.attachments.length} attachment${email.attachments.length > 1 ? 's' : ''}'
                    : email.analysis != null
                    ? 'AI confidence: ${(email.analysis!.confidence * 100).toStringAsFixed(0)}%'
                    : '',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.orange,
              ),
            ),
          ),
        ],
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
          Icon(Icons.inbox, size: 64, color: Colors.grey[300]),
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
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
