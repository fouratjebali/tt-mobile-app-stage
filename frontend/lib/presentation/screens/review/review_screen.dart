import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/di/di.dart';
import 'package:tt_mail_assistant/core/state/load_state.dart';
import 'package:tt_mail_assistant/core/theme/app_palette.dart';
import 'package:tt_mail_assistant/domain/entities/email.dart';
import 'package:tt_mail_assistant/presentation/viewmodels/review_view_model.dart';
import 'package:tt_mail_assistant/presentation/widgets/app_snackbar.dart';
import 'package:tt_mail_assistant/presentation/widgets/error_state.dart';
import 'package:tt_mail_assistant/presentation/widgets/skeleton_loader.dart';

enum _ReviewFilter { all, ready, urgent, needsEdit }

class ReviewScreen extends StatefulWidget {
const ReviewScreen({super.key});

@override
State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
late final ReviewViewModel _viewModel;

_ReviewFilter _filter = _ReviewFilter.all;
bool _isShowingSuccess = false;

@override
void initState() {
super.initState();

_viewModel = getIt<ReviewViewModel>();
_viewModel.addListener(_onChanged);

WidgetsBinding.instance.addPostFrameCallback((_) {
if (mounted) {
_viewModel.loadReviewEmails();
}
});
}

@override
void dispose() {
_viewModel.removeListener(_onChanged);
super.dispose();
}

void _onChanged() {
if (!mounted) return;

setState(() {});

final successMessage = _viewModel.actionSuccessMessage;

if (successMessage == null || _isShowingSuccess) return;

_isShowingSuccess = true;

WidgetsBinding.instance.addPostFrameCallback((_) {
if (!mounted) return;

AppSnackbar.showSuccess(
context,
successMessage,
);

_viewModel.clearActionMessages();
_isShowingSuccess = false;
});
}

@override
Widget build(BuildContext context) {
final isLoading =
_viewModel.state == LoadState.loading ||
_viewModel.state == LoadState.idle;

final allEmails = _viewModel.sortedEmails;
final emails = _filteredEmails(allEmails);

return Scaffold(
backgroundColor: Theme.of(context).scaffoldBackgroundColor,
body: SafeArea(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
_ReviewHeader(
readyCount: allEmails.where(_isReadyToSend).length,
urgentCount: allEmails.where(_isUrgent).length,
),

_ReviewFilterRail(
selected: _filter,
allCount: allEmails.length,
readyCount: allEmails.where(_isReadyToSend).length,
urgentCount: allEmails.where(_isUrgent).length,
editCount: allEmails.where(_needsEdit).length,
onChanged: (value) {
setState(() {
_filter = value;
});
},
),

if (_viewModel.actionErrorMessage != null)
_ActionErrorBanner(
message: _viewModel.actionErrorMessage!,
onRetry: _viewModel.retryLastAction,
),

Expanded(
child: isLoading
? const _ReviewSkeleton()
    : _viewModel.state == LoadState.error
? ErrorState(
message:
_viewModel.errorMessage ??
'Unable to load emails.',
onRetry: _viewModel.loadReviewEmails,
)
    : emails.isEmpty
? _EmptyState(filter: _filter)
    : RefreshIndicator(
onRefresh: _viewModel.refresh,
child: ListView.builder(
padding: const EdgeInsets.fromLTRB(
16,
8,
16,
28,
),
itemCount: emails.length,
itemBuilder: (context, index) {
final email = emails[index];

return _ReviewEmailCard(
email: email,
isSubmitting:
_viewModel.isSubmittingAction,
onSendReply:
() => _viewModel.validateAndSend(
email.id,
),
onEditFirst:
() => _showEditAndSendDialog(
context,
email,
),
onReject:
() => _confirmReject(email),
);
},
),
),
),
],
),
),
);
}

Future<void> _showEditAndSendDialog(
BuildContext context,
Email email,
) async {
final controller = TextEditingController(
text: email.analysis?.suggestedReply ?? '',
);

final confirmed = await showDialog<bool>(
context: context,
builder: (ctx) {
return _EditReplyDialog(
subject: email.subject,
controller: controller,
);
},
);

final editedReply = controller.text.trim();
controller.dispose();

if (confirmed == true && editedReply.isNotEmpty) {
await _viewModel.editAndSend(
email.id,
editedReply,
);
}
}

Future<void> _confirmReject(Email email) async {
final confirmed = await showDialog<bool>(
context: context,
builder: (ctx) {
return _SkipReplyDialog(
subject: email.subject,
);
},
);

if (confirmed == true) {
await _viewModel.reject(email.id);
}
}

List<Email> _filteredEmails(List<Email> emails) {
switch (_filter) {
case _ReviewFilter.all:
return emails;

case _ReviewFilter.ready:
return emails.where(_isReadyToSend).toList();

case _ReviewFilter.urgent:
return emails.where(_isUrgent).toList();

case _ReviewFilter.needsEdit:
return emails.where(_needsEdit).toList();
}
}

bool _isUrgent(Email email) {
return (email.analysis?.priority ?? Priority.NORMAL) ==
Priority.URGENT;
}

bool _isReadyToSend(Email email) {
final hasReply =
email.analysis?.suggestedReply.trim().isNotEmpty == true;

return hasReply &&
email.jury?.verdict == JuryVerdict.APPROVED;
}

bool _needsEdit(Email email) {
final confidence = email.analysis?.confidence ?? 0;
final verdict = email.jury?.verdict;

return confidence < 0.8 ||
verdict == JuryVerdict.REJECTED ||
verdict == JuryVerdict.UNCERTAIN ||
email.analysis?.suggestedReply.trim().isNotEmpty != true;
}
}

class _ReviewTone {
const _ReviewTone({
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

static _ReviewTone of(BuildContext context) {
final isDark =
Theme.of(context).brightness == Brightness.dark;

return _ReviewTone(
surface:
isDark
? const Color(0xFF151C1A)
    : AppPalette.paper,
softSurface:
isDark
? AppPalette.white.withValues(alpha: 0.07)
    : AppPalette.sage.withValues(alpha: 0.62),
border:
isDark
? AppPalette.white.withValues(alpha: 0.08)
    : AppPalette.line,
text:
isDark
? AppPalette.white
    : AppPalette.ink,
muted:
isDark
? AppPalette.white.withValues(alpha: 0.62)
    : AppPalette.pine.withValues(alpha: 0.68),
);
}
}

class _ReviewHeader extends StatelessWidget {
const _ReviewHeader({
required this.readyCount,
required this.urgentCount,
});

final int readyCount;
final int urgentCount;

@override
Widget build(BuildContext context) {
final tone = _ReviewTone.of(context);

return Padding(
padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'Review replies',
style: TextStyle(
color: tone.text,
fontSize: 28,
fontWeight: FontWeight.w900,
height: 1.05,
),
),
const SizedBox(height: 8),
Text(
'Check suggested replies before they are sent.',
style: TextStyle(
color: tone.muted,
fontSize: 13,
fontWeight: FontWeight.w600,
height: 1.35,
),
),
if (urgentCount > 0) ...[
const SizedBox(height: 10),
Wrap(
spacing: 8,
runSpacing: 8,
children: [
_HeaderNotice(
icon: Icons.priority_high_rounded,
label: '$urgentCount urgent',
color: AppPalette.clay,
),
if (readyCount > 0)
_HeaderNotice(
icon: Icons.verified_outlined,
label: '$readyCount ready',
color: AppPalette.teal,
),
],
),
] else if (readyCount > 0) ...[
const SizedBox(height: 10),
_HeaderNotice(
icon: Icons.verified_outlined,
label: '$readyCount ready to send',
color: AppPalette.teal,
),
],
],
),
);
}
}

class _ReviewFilterRail extends StatelessWidget {
const _ReviewFilterRail({
required this.selected,
required this.allCount,
required this.readyCount,
required this.urgentCount,
required this.editCount,
required this.onChanged,
});

final _ReviewFilter selected;
final int allCount;
final int readyCount;
final int urgentCount;
final int editCount;
final ValueChanged<_ReviewFilter> onChanged;

@override
Widget build(BuildContext context) {
final options = [
_FilterOption(
_ReviewFilter.all,
'All',
allCount,
),
_FilterOption(
_ReviewFilter.ready,
'Ready',
readyCount,
),
_FilterOption(
_ReviewFilter.urgent,
'Urgent',
urgentCount,
),
_FilterOption(
_ReviewFilter.needsEdit,
'Needs edit',
editCount,
),
];

return SizedBox(
height: 44,
child: ListView.separated(
padding: const EdgeInsets.fromLTRB(
16,
0,
16,
8,
),
scrollDirection: Axis.horizontal,
itemCount: options.length,
separatorBuilder: (_, _) =>
const SizedBox(width: 8),
itemBuilder: (context, index) {
final option = options[index];

return _FilterChipButton(
label: '${option.label} ${option.count}',
selected: option.filter == selected,
onTap: () => onChanged(option.filter),
);
},
),
);
}
}

class _FilterOption {
const _FilterOption(
this.filter,
this.label,
this.count,
);

final _ReviewFilter filter;
final String label;
final int count;
}

class _FilterChipButton extends StatelessWidget {
const _FilterChipButton({
required this.label,
required this.selected,
required this.onTap,
});

final String label;
final bool selected;
final VoidCallback onTap;

@override
Widget build(BuildContext context) {
final tone = _ReviewTone.of(context);

final active =
Theme.of(context).brightness == Brightness.dark
? AppPalette.lavender
    : AppPalette.deepTeal;

return Material(
color: Colors.transparent,
child: InkWell(
borderRadius: BorderRadius.circular(999),
onTap: onTap,
child: Container(
padding: const EdgeInsets.symmetric(
horizontal: 13,
vertical: 9,
),
decoration: BoxDecoration(
color:
selected
? active.withValues(alpha: 0.13)
    : tone.softSurface,
borderRadius: BorderRadius.circular(999),
border: Border.all(
color:
selected
? active.withValues(alpha: 0.34)
    : tone.border,
),
),
child: Text(
label,
style: TextStyle(
color: selected ? active : tone.text,
fontSize: 12,
fontWeight: FontWeight.w800,
),
),
),
),
);
}
}

class _HeaderNotice extends StatelessWidget {
const _HeaderNotice({
required this.icon,
required this.label,
required this.color,
});

final IconData icon;
final String label;
final Color color;

@override
Widget build(BuildContext context) {
return Container(
padding: const EdgeInsets.symmetric(
horizontal: 10,
vertical: 6,
),
decoration: BoxDecoration(
color: color.withValues(alpha: 0.10),
borderRadius: BorderRadius.circular(999),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(
icon,
color: color,
size: 15,
),
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

class _ReviewEmailCard extends StatelessWidget {
const _ReviewEmailCard({
required this.email,
required this.onSendReply,
required this.onEditFirst,
required this.onReject,
required this.isSubmitting,
});

final Email email;
final VoidCallback onSendReply;
final VoidCallback onEditFirst;
final VoidCallback onReject;
final bool isSubmitting;

Priority get _priority =>
email.analysis?.priority ?? Priority.NORMAL;

EmailCategory get _category =>
email.analysis?.category ??
EmailCategory.INFORMATION;

String get _emailPreview {
final body = email.body.plain.trim();

if (body.isNotEmpty) {
return body;
}

final summary =
email.analysis?.summary.trim() ?? '';

if (summary.isNotEmpty) {
return summary;
}

return 'No email preview available.';
}

String get _suggestedReply {
final suggested =
email.analysis?.suggestedReply.trim() ?? '';

if (suggested.isNotEmpty) {
return suggested;
}

return 'No suggested reply was generated yet.';
}

String get _senderName {
final name = email.from.name.trim();

if (name.isNotEmpty) {
return name;
}

return email.from.email.trim().isEmpty
? 'Unknown sender'
    : email.from.email;
}

String _buildReason() {
final juryReason =
email.jury?.reasoning?.trim();

if (juryReason != null &&
juryReason.isNotEmpty) {
return juryReason;
}

final confidence =
email.analysis?.confidence;

if (confidence != null &&
confidence < 0.8) {
return 'The draft needs a human check before sending.';
}

if (_priority == Priority.URGENT) {
return 'This email looks urgent, so it needs your approval.';
}

return 'Review this draft before it is sent.';
}

bool get _isReadyToSend {
final hasReply =
email.analysis?.suggestedReply.trim().isNotEmpty ==
true;

return hasReply &&
email.jury?.verdict ==
JuryVerdict.APPROVED;
}

bool get _needsEdit {
final confidence =
email.analysis?.confidence ?? 0;

final verdict = email.jury?.verdict;

return confidence < 0.8 ||
verdict == JuryVerdict.REJECTED ||
verdict == JuryVerdict.UNCERTAIN ||
email.analysis?.suggestedReply.trim().isNotEmpty !=
true;
}

String get _reviewStateLabel {
if (_isReadyToSend) {
return 'Ready to send';
}

if (_priority == Priority.URGENT) {
return 'Check urgently';
}

if (_needsEdit) {
return 'Needs edit';
}

return 'Review first';
}

IconData get _reviewStateIcon {
if (_isReadyToSend) {
return Icons.verified_outlined;
}

if (_priority == Priority.URGENT) {
return Icons.priority_high_rounded;
}

if (_needsEdit) {
return Icons.edit_note_rounded;
}

return Icons.rate_review_outlined;
}

Color get _reviewStateColor {
if (_isReadyToSend) {
return AppPalette.teal;
}

if (_priority == Priority.URGENT) {
return AppPalette.clay;
}

if (_needsEdit) {
return AppPalette.amber;
}

return AppPalette.blue;
}

@override
Widget build(BuildContext context) {
final tone = _ReviewTone.of(context);

final priorityColor =
_priorityColor(_priority);

final categoryColor =
_categoryColor(_category);

final stateColor =
_reviewStateColor;

return Container(
margin: const EdgeInsets.only(
bottom: 14,
),
decoration: BoxDecoration(
color: tone.surface,
borderRadius: BorderRadius.circular(18),
border: Border.all(
color: tone.border,
),
boxShadow: [
if (Theme.of(context).brightness !=
Brightness.dark)
BoxShadow(
color: Colors.black.withValues(
alpha: 0.04,
),
blurRadius: 14,
offset: const Offset(0, 5),
),
],
),
child: ClipRRect(
borderRadius: BorderRadius.circular(18),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Container(
height: 4,
color: stateColor,
),
Padding(
padding: const EdgeInsets.fromLTRB(
16,
14,
16,
16,
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Row(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
_ReviewStatePill(
label:
_reviewStateLabel,
icon:
_reviewStateIcon,
color:
stateColor,
),
const SizedBox(height: 9),
Text(
email.subject.trim().isEmpty
? '(No subject)'
    : email.subject,
maxLines: 2,
overflow:
TextOverflow.ellipsis,
style: TextStyle(
color: tone.text,
fontSize: 16,
fontWeight:
FontWeight.w900,
height: 1.25,
),
),
const SizedBox(height: 6),
Text(
_senderLine(),
maxLines: 1,
overflow:
TextOverflow.ellipsis,
style: TextStyle(
color: tone.muted,
fontSize: 12,
fontWeight:
FontWeight.w700,
),
),
],
),
),
const SizedBox(width: 10),
Text(
_formatRelativeTime(
email.date,
),
style: TextStyle(
color: tone.muted,
fontSize: 11,
fontWeight:
FontWeight.w800,
),
),
],
),
const SizedBox(height: 12),
Wrap(
spacing: 8,
runSpacing: 8,
children: [
_InfoPill(
label:
_priorityLabel(
_priority,
),
color:
priorityColor,
),
_InfoPill(
label:
_categoryLabel(
_category,
),
color:
categoryColor,
),
],
),
const SizedBox(height: 12),
_ReviewReason(
text: _buildReason(),
),
const SizedBox(height: 12),
_ReviewTextBlock(
title: 'Original email',
text: _emailPreview,
icon:
Icons.mail_outline_rounded,
maxLines: 5,
),
const SizedBox(height: 10),
_ReviewTextBlock(
title: 'Suggested reply',
text: _suggestedReply,
icon:
Icons.edit_note_rounded,
maxLines: 7,
highlighted: true,
),
const SizedBox(height: 14),
Row(
children: [
Expanded(
child:
FilledButton.icon(
onPressed:
isSubmitting
? null
    : onSendReply,
icon: const Icon(
Icons.send_rounded,
size: 18,
),
label:
const Text('Send'),
),
),
const SizedBox(width: 10),
Expanded(
child:
OutlinedButton.icon(
onPressed:
isSubmitting
? null
    : onEditFirst,
icon: const Icon(
Icons.edit_rounded,
size: 18,
),
label:
const Text('Edit'),
style:
OutlinedButton.styleFrom(
foregroundColor:
Theme.of(context)
    .brightness ==
Brightness.dark
? AppPalette
    .lavender
    : AppPalette
    .deepTeal,
side: BorderSide(
color: AppPalette
    .deepTeal
    .withValues(
alpha: 0.34,
),
),
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(
10,
),
),
),
),
),
const SizedBox(width: 10),
_SkipButton(
enabled:
!isSubmitting,
onPressed:
onReject,
),
],
),
],
),
),
],
),
),
);
}

String _senderLine() {
final emailAddress =
email.from.email.trim();

if (emailAddress.isEmpty ||
emailAddress == _senderName) {
return _senderName;
}

return '$_senderName <$emailAddress>';
}
}

class _ReviewReason extends StatelessWidget {
const _ReviewReason({
required this.text,
});

final String text;

@override
Widget build(BuildContext context) {
final tone = _ReviewTone.of(context);

return Container(
width: double.infinity,
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: AppPalette.amber.withValues(
alpha: 0.10,
),
borderRadius:
BorderRadius.circular(14),
border: Border.all(
color: AppPalette.amber.withValues(
alpha: 0.22,
),
),
),
child: Row(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
const Icon(
Icons.info_outline_rounded,
color: AppPalette.amber,
size: 18,
),
const SizedBox(width: 8),
Expanded(
child: Text(
text,
style: TextStyle(
color: tone.text,
fontSize: 12,
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

class _ReviewTextBlock extends StatelessWidget {
const _ReviewTextBlock({
required this.title,
required this.text,
required this.icon,
required this.maxLines,
this.highlighted = false,
});

final String title;
final String text;
final IconData icon;
final int maxLines;
final bool highlighted;

@override
Widget build(BuildContext context) {
final tone = _ReviewTone.of(context);

final accent =
highlighted
? AppPalette.deepTeal
    : AppPalette.blue;

return Container(
width: double.infinity,
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color:
highlighted
? AppPalette.teal.withValues(
alpha: 0.10,
)
    : tone.softSurface,
borderRadius:
BorderRadius.circular(14),
border: Border.all(
color:
highlighted
? AppPalette.teal.withValues(
alpha: 0.20,
)
    : tone.border,
),
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Row(
children: [
Icon(
icon,
color: accent,
size: 16,
),
const SizedBox(width: 6),
Text(
title,
style: TextStyle(
color:
highlighted
? accent
    : tone.muted,
fontSize: 11,
fontWeight:
FontWeight.w900,
letterSpacing: 0.4,
),
),
],
),
const SizedBox(height: 8),
SelectableText(
text,
maxLines: maxLines,
style: TextStyle(
color: tone.text,
fontSize: 12,
height: 1.4,
fontWeight: FontWeight.w500,
),
),
],
),
);
}
}

class _SkipButton extends StatelessWidget {
const _SkipButton({
required this.enabled,
required this.onPressed,
});

final bool enabled;
final VoidCallback onPressed;

@override
Widget build(BuildContext context) {
final tone = _ReviewTone.of(context);

return Tooltip(
message: 'Skip this email',
child: IconButton(
onPressed:
enabled ? onPressed : null,
style: IconButton.styleFrom(
backgroundColor:
AppPalette.clay.withValues(
alpha: 0.10,
),
foregroundColor:
AppPalette.clay,
disabledForegroundColor:
tone.muted.withValues(
alpha: 0.4,
),
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(12),
),
),
icon: const Icon(
Icons.close_rounded,
size: 22,
),
),
);
}
}

class _ReviewStatePill extends StatelessWidget {
const _ReviewStatePill({
required this.label,
required this.icon,
required this.color,
});

final String label;
final IconData icon;
final Color color;

@override
Widget build(BuildContext context) {
return Container(
padding:
const EdgeInsets.symmetric(
horizontal: 9,
vertical: 5,
),
decoration: BoxDecoration(
color: color.withValues(
alpha: 0.12,
),
borderRadius:
BorderRadius.circular(999),
),
child: Row(
mainAxisSize:
MainAxisSize.min,
children: [
Icon(
icon,
size: 14,
color: color,
),
const SizedBox(width: 5),
Text(
label,
style: TextStyle(
color: color,
fontSize: 11,
fontWeight:
FontWeight.w900,
height: 1,
),
),
],
),
);
}
}

class _InfoPill extends StatelessWidget {
const _InfoPill({
required this.label,
required this.color,
});

final String label;
final Color color;

@override
Widget build(BuildContext context) {
return Container(
padding:
const EdgeInsets.symmetric(
horizontal: 9,
vertical: 5,
),
decoration: BoxDecoration(
color: color.withValues(
alpha: 0.12,
),
borderRadius:
BorderRadius.circular(999),
),
child: Text(
label,
maxLines: 1,
overflow:
TextOverflow.ellipsis,
style: TextStyle(
color: color,
fontSize: 11,
fontWeight:
FontWeight.w900,
height: 1,
),
),
);
}
}

class _EditReplyDialog extends StatelessWidget {
const _EditReplyDialog({
required this.subject,
required this.controller,
});

final String subject;
final TextEditingController controller;

@override
Widget build(BuildContext context) {
final tone = _ReviewTone.of(context);

return AlertDialog(
backgroundColor: tone.surface,
surfaceTintColor:
Colors.transparent,
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(18),
side:
BorderSide(
color: tone.border,
),
),
title: Text(
'Edit reply',
style: TextStyle(
color: tone.text,
fontWeight:
FontWeight.w900,
),
),
content: SizedBox(
width: 420,
child: Column(
mainAxisSize:
MainAxisSize.min,
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
subject.trim().isEmpty
? '(No subject)'
    : subject,
maxLines: 2,
overflow:
TextOverflow.ellipsis,
style: TextStyle(
color: tone.muted,
fontSize: 12,
fontWeight:
FontWeight.w700,
),
),
const SizedBox(height: 12),
TextField(
controller: controller,
minLines: 5,
maxLines: 9,
style: TextStyle(
color: tone.text,
height: 1.35,
),
decoration:
InputDecoration(
hintText:
'Write your reply...',
hintStyle:
TextStyle(
color: tone.muted,
),
filled: true,
fillColor:
tone.softSurface,
border:
OutlineInputBorder(
borderRadius:
BorderRadius.circular(
14,
),
borderSide:
BorderSide(
color: tone.border,
),
),
enabledBorder:
OutlineInputBorder(
borderRadius:
BorderRadius.circular(
14,
),
borderSide:
BorderSide(
color: tone.border,
),
),
focusedBorder:
OutlineInputBorder(
borderRadius:
BorderRadius.circular(
14,
),
borderSide:
const BorderSide(
color: AppPalette.teal,
),
),
),
),
],
),
),
actions: [
TextButton(
onPressed:
() => Navigator.pop(
context,
false,
),
child: Text(
'Cancel',
style: TextStyle(
color: tone.muted,
),
),
),
FilledButton(
onPressed:
() => Navigator.pop(
context,
true,
),
child:
const Text('Send'),
),
],
);
}
}

class _SkipReplyDialog extends StatelessWidget {
const _SkipReplyDialog({
required this.subject,
});

final String subject;

@override
Widget build(BuildContext context) {
final tone = _ReviewTone.of(context);

return AlertDialog(
backgroundColor: tone.surface,
surfaceTintColor:
Colors.transparent,
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(18),
side:
BorderSide(
color: tone.border,
),
),
title: Text(
'Skip reply?',
style: TextStyle(
color: tone.text,
fontWeight:
FontWeight.w900,
),
),
content: Text(
'Mark "${subject.trim().isEmpty ? 'this email' : subject}" as handled without sending a reply.',
style: TextStyle(
color: tone.muted,
height: 1.35,
),
),
actions: [
TextButton(
onPressed:
() => Navigator.pop(
context,
false,
),
child: Text(
'Cancel',
style: TextStyle(
color: tone.muted,
),
),
),
FilledButton(
onPressed:
() => Navigator.pop(
context,
true,
),
style:
FilledButton.styleFrom(
backgroundColor:
AppPalette.clay,
),
child:
const Text('Skip'),
),
],
);
}
}

class _EmptyState extends StatelessWidget {
const _EmptyState({
required this.filter,
});

final _ReviewFilter filter;

@override
Widget build(BuildContext context) {
final tone = _ReviewTone.of(context);

return Center(
child: Padding(
padding:
const EdgeInsets.all(32),
child: Column(
mainAxisAlignment:
MainAxisAlignment.center,
children: [
Container(
width: 72,
height: 72,
decoration:
BoxDecoration(
color:
AppPalette.teal
    .withValues(
alpha: 0.12,
),
borderRadius:
BorderRadius.circular(
24,
),
),
child:
const Icon(
Icons
    .check_circle_outline_rounded,
size: 36,
color:
AppPalette.teal,
),
),
const SizedBox(height: 18),
Text(
_emptyTitle(filter),
style: TextStyle(
color: tone.text,
fontSize: 20,
fontWeight:
FontWeight.w900,
),
),
const SizedBox(height: 8),
Text(
_emptySubtitle(filter),
textAlign:
TextAlign.center,
style: TextStyle(
color: tone.muted,
fontSize: 13,
fontWeight:
FontWeight.w600,
height: 1.35,
),
),
],
),
),
);
}
}

String _emptyTitle(
_ReviewFilter filter,
) {
switch (filter) {
case _ReviewFilter.all:
return 'All caught up';

case _ReviewFilter.ready:
return 'No ready replies';

case _ReviewFilter.urgent:
return 'No urgent replies';

case _ReviewFilter.needsEdit:
return 'No drafts need editing';
}
}

String _emptySubtitle(
_ReviewFilter filter,
) {
switch (filter) {
case _ReviewFilter.all:
return 'No suggested replies need your attention right now.';

case _ReviewFilter.ready:
return 'Validated drafts will appear here when they are ready to send.';

case _ReviewFilter.urgent:
return 'Urgent emails that need your approval will appear here.';

case _ReviewFilter.needsEdit:
return 'Drafts that need a closer look will appear here.';
}
}

class _ActionErrorBanner extends StatelessWidget {
const _ActionErrorBanner({
required this.message,
required this.onRetry,
});

final String message;
final Future<void> Function() onRetry;

@override
Widget build(BuildContext context) {
return Container(
margin:
const EdgeInsets.fromLTRB(
16,
0,
16,
8,
),
padding:
const EdgeInsets.fromLTRB(
12,
9,
8,
9,
),
decoration: BoxDecoration(
color:
AppPalette.clay.withValues(
alpha: 0.10,
),
borderRadius:
BorderRadius.circular(14),
border: Border.all(
color:
AppPalette.clay.withValues(
alpha: 0.24,
),
),
),
child: Row(
children: [
const Icon(
Icons.error_outline_rounded,
color: AppPalette.clay,
size: 19,
),
const SizedBox(width: 10),
Expanded(
child: Text(
message,
style: const TextStyle(
color: AppPalette.clay,
fontSize: 12,
fontWeight:
FontWeight.w700,
),
),
),
TextButton(
onPressed: onRetry,
child:
const Text('Retry'),
),
],
),
);
}
}

class _ReviewSkeleton extends StatelessWidget {
const _ReviewSkeleton();

@override
Widget build(BuildContext context) {
return ListView.builder(
padding:
const EdgeInsets.fromLTRB(
16,
8,
16,
28,
),
itemCount: 3,
itemBuilder: (context, index) {
return const Padding(
padding:
EdgeInsets.only(
bottom: 14,
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
SkeletonLoader(
height: 180,
),
],
),
);
},
);
}
}

String _formatRelativeTime(
DateTime date,
) {
final diff =
DateTime.now().difference(date);

if (diff.inMinutes < 1) {
return 'now';
}

if (diff.inMinutes < 60) {
return '${diff.inMinutes}m';
}

if (diff.inHours < 24) {
return '${diff.inHours}h';
}

return '${diff.inDays}d';
}

String _priorityLabel(
Priority priority,
) {
switch (priority) {
case Priority.URGENT:
return 'URGENT';

case Priority.NORMAL:
return 'NORMAL';

case Priority.LOW:
return 'LOW';
}
}

Color _priorityColor(
Priority priority,
) {
switch (priority) {
case Priority.URGENT:
return AppPalette.clay;

case Priority.NORMAL:
return AppPalette.amber;

case Priority.LOW:
return AppPalette.deepTeal;
}
}

String _categoryLabel(
EmailCategory category,
) {
switch (category) {
case EmailCategory.RECLAMATION:
return 'RECLAMATION';

case EmailCategory.INFORMATION:
return 'INFO';

case EmailCategory.SUPPORT:
return 'SUPPORT';

case EmailCategory.COMMERCIAL:
return 'COMMERCIAL';
}
}

Color _categoryColor(
EmailCategory category,
) {
switch (category) {
case EmailCategory.RECLAMATION:
return AppPalette.clay;

case EmailCategory.INFORMATION:
return AppPalette.blue;

case EmailCategory.SUPPORT:
return AppPalette.amber;

case EmailCategory.COMMERCIAL:
return AppPalette.deepTeal;
}
}
