import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:tt_mail_assistant/domain/entities/email.dart';
import 'package:tt_mail_assistant/domain/usecases/email_usecase.dart';

enum DashboardPeriod { sevenDays, thirtyDays }

class DashboardBarPoint {
  DashboardBarPoint({
    required this.date,
    required this.label,
    required this.value,
  });

  final DateTime date;
  final String label;
  final double value;
}

class DashboardCategoryPoint {
  DashboardCategoryPoint({
    required this.category,
    required this.value,
    required this.color,
  });

  final String category;
  final double value;
  final Color color;
}

class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel({required EmailUseCase emailUseCase})
    : _emailUseCase = emailUseCase;

  final EmailUseCase _emailUseCase;

  List<Email> _emails = const [];
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic> _backendStats = const {};

  DashboardPeriod selectedPeriod = DashboardPeriod.sevenDays;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get periodLabel => switch (selectedPeriod) {
    DashboardPeriod.sevenDays => '7D',
    DashboardPeriod.thirtyDays => '30D',
  };

  String get apiPeriod =>
      selectedPeriod == DashboardPeriod.sevenDays ? '7d' : '30d';

  List<Email> get filteredEmails {
    if (_emails.isEmpty) return const [];

    final now = DateTime.now();
    final days = selectedPeriod == DashboardPeriod.sevenDays ? 7 : 30;

    final start = now.subtract(Duration(days: days));
    return _emails
        .where(
          (email) => !email.date.isBefore(start) && !email.date.isAfter(now),
        )
        .toList();
  }

  int get totalEmails =>
      _backendStats['processed_count'] is int
          ? _asInt(_backendStats['processed_count'])
          : filteredEmails.length;

  double get autoHandledRate {
    final fallback = _fallbackAutoHandledRate();
    final processed = _asInt(_backendStats['processed_count']);
    final sent = _asInt(_backendStats['sent_count']);
    if (processed > 0 && sent >= 0) {
      return (sent / processed) * 100;
    }
    return fallback;
  }

  double get juryApprovalRate {
    final fallback = _fallbackJuryApprovalRate();
    final review = _asInt(_backendStats['review_count']);
    final sent = _asInt(_backendStats['sent_count']);
    if (review > 0 && sent > 0) {
      return ((sent / review) * 100).clamp(0, 100);
    }
    return fallback;
  }

  double get averageResponseMinutes {
    if (filteredEmails.isEmpty) return 0;
    final totalMinutes = filteredEmails.fold<int>(0, (sum, email) {
      final ageMinutes = DateTime.now().difference(email.date).inMinutes;
      return sum + ageMinutes;
    });
    return totalMinutes / filteredEmails.length;
  }

  double get averageSentimentScore {
    if (filteredEmails.isEmpty) return 0;

    final scores =
        filteredEmails
            .map((email) => email.analysis?.confidence ?? 0)
            .where((value) => value > 0)
            .toList();

    if (scores.isEmpty) return 0;
    final avg = scores.reduce((a, b) => a + b) / scores.length;
    return avg * 100;
  }

  List<DashboardBarPoint> get dailyPoints {
    final now = DateTime.now();
    final days = selectedPeriod == DashboardPeriod.sevenDays ? 7 : 30;
    final countsByDay = <String, int>{};

    for (final email in filteredEmails) {
      final date = DateTime(email.date.year, email.date.month, email.date.day);
      final key = '${date.year}-${date.month}-${date.day}';
      countsByDay[key] = (countsByDay[key] ?? 0) + 1;
    }

    return List.generate(days, (index) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: days - 1 - index));
      final key = '${date.year}-${date.month}-${date.day}';
      final label =
          selectedPeriod == DashboardPeriod.sevenDays
              ? _weekdayLabel(date.weekday)
              : '${date.day}/${date.month}';
      return DashboardBarPoint(
        date: date,
        label: label,
        value: (countsByDay[key] ?? 0).toDouble(),
      );
    });
  }

  List<DashboardCategoryPoint> get categoryPoints {
    final counts = <EmailCategory, int>{};
    for (final email in filteredEmails) {
      final category = email.analysis?.category ?? EmailCategory.INFORMATION;
      counts[category] = (counts[category] ?? 0) + 1;
    }

    final colors = <EmailCategory, Color>{
      EmailCategory.RECLAMATION: const Color(0xFFef4444),
      EmailCategory.INFORMATION: const Color(0xFF3b82f6),
      EmailCategory.SUPPORT: const Color(0xFF10b981),
      EmailCategory.COMMERCIAL: const Color(0xFF8b5cf6),
    };

    if (counts.isEmpty) {
      return const [];
    }

    final total = counts.values.fold<int>(0, (sum, value) => sum + value);
    return counts.entries
        .map(
          (entry) => DashboardCategoryPoint(
            category: _categoryLabel(entry.key),
            value: total == 0 ? 0 : (entry.value / total) * 100,
            color: colors[entry.key] ?? const Color(0xFF6b7280),
          ),
        )
        .toList();
  }

  void setPeriod(DashboardPeriod period) {
    if (selectedPeriod == period) return;
    selectedPeriod = period;
    notifyListeners();
    unawaited(loadDashboardData());
  }

  Future<void> loadStats(DashboardPeriod period) async {
    selectedPeriod = period;
    await loadDashboardData();
  }

  Future<void> changePeriod(DashboardPeriod period) => loadStats(period);

  Future<void> loadDashboardData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _backendStats = await _emailUseCase.getDashboardStats(period: apiPeriod);
    } catch (_) {
      _backendStats = const {};
    }

    try {
      _emails = await _emailUseCase.getEmails();
    } catch (_) {
      _errorMessage = 'Unable to load dashboard data.';
      _emails = const [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> exportReport() async {
    try {
      await _emailUseCase.exportDashboardReport(period: apiPeriod);
    } catch (_) {
      // The backend export route is optional; we still generate a local PDF report.
    }

    final file = await _generatePdfReport();
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        fileNameOverrides: const ['dashboard_report.pdf'],
        text: 'TT Mail Assistant dashboard report',
      ),
    );
  }

  Future<void> exportPdf() => exportReport();

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _fallbackAutoHandledRate() {
    if (filteredEmails.isEmpty) return 0;
    final count =
        filteredEmails.where((email) => email.status == Status.DONE).length;
    return (count / filteredEmails.length) * 100;
  }

  double _fallbackJuryApprovalRate() {
    final juryEmails =
        filteredEmails.where((email) => email.jury != null).toList();
    if (juryEmails.isEmpty) return 0;
    final approved =
        juryEmails
            .where((email) => email.jury?.verdict == JuryVerdict.APPROVED)
            .length;
    return (approved / juryEmails.length) * 100;
  }

  Future<File> _generatePdfReport() async {
    final pdf = pw.Document();
    final tableRows = [
      ['Metric', 'Value'],
      ['Total', '$totalEmails'],
      ['Auto-handled', '${autoHandledRate.toStringAsFixed(0)}%'],
      ['Jury approval', '${juryApprovalRate.toStringAsFixed(0)}%'],
      ['Avg. response', '${averageResponseMinutes.toStringAsFixed(0)} min'],
      ['Sentiment', '${averageSentimentScore.toStringAsFixed(0)}%'],
    ];
    final dailySummary = StringBuffer();
    for (final point in dailyPoints) {
      if (dailySummary.isNotEmpty) {
        dailySummary.write(' | ');
      }
      dailySummary.write('${point.label}: ${point.value.toInt()}');
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pw.PdfPageFormat.a4,
        build:
            (pw.Context context) => [
              pw.Text(
                'TT Mail Assistant - Dashboard',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'Period: $periodLabel',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(data: tableRows),
              pw.SizedBox(height: 20),
              pw.Text(
                'Emails by day',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Text('• $dailySummary'),
            ],
      ),
    );

    final file = File(
      '${Directory.systemTemp.path}/tt_dashboard_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  String _categoryLabel(EmailCategory category) {
    switch (category) {
      case EmailCategory.RECLAMATION:
        return 'Reclamation';
      case EmailCategory.INFORMATION:
        return 'Information';
      case EmailCategory.SUPPORT:
        return 'Support';
      case EmailCategory.COMMERCIAL:
        return 'Commercial';
    }
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return '';
    }
  }
}
