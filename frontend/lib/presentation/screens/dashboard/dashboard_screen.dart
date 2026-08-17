import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:tt_mail_assistant/core/di/di.dart';
import 'package:tt_mail_assistant/core/theme/app_palette.dart';
import 'package:tt_mail_assistant/presentation/viewmodels/dashboard_view_model.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardViewModel _viewModel;
  final ScrollController _thirtyDaysScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _viewModel = getIt<DashboardViewModel>();
    _viewModel.addListener(_onChanged);
    _viewModel.loadDashboardData();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _thirtyDaysScrollController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_viewModel.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: () async {
              final messenger = ScaffoldMessenger.maybeOf(context);
              await _viewModel.exportPdf();
              if (!mounted) return;
              messenger?.showSnackBar(
                const SnackBar(content: Text('PDF exported to temp directory')),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _viewModel.loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PeriodSelector(
                selected: _viewModel.selectedPeriod,
                onChanged: (period) => _viewModel.changePeriod(period),
              ),
              if (_viewModel.errorMessage != null) ...[
                const SizedBox(height: 16),
                _InfoCard(
                  title: 'Data issue',
                  content: _viewModel.errorMessage!,
                  color: Colors.orange,
                ),
              ],
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.45,
                children: [
                  _MetricCard(
                    title: 'Total',
                    value: '${_viewModel.totalEmails}',
                    color: AppPalette.lavender,
                    icon: Icons.mail_outline,
                  ),
                  _MetricCard(
                    title: 'Auto-handled %',
                    value: '${_viewModel.autoHandledRate.toStringAsFixed(0)}%',
                    color: AppPalette.teal,
                    icon: Icons.auto_awesome,
                  ),
                  _MetricCard(
                    title: 'Jury approval %',
                    value: '${_viewModel.juryApprovalRate.toStringAsFixed(0)}%',
                    color: AppPalette.pine,
                    icon: Icons.fact_check_outlined,
                  ),
                  _MetricCard(
                    title: 'Avg. time',
                    value:
                        '${_viewModel.averageResponseMinutes.toStringAsFixed(0)}m',
                    color: const Color(0xFFf59e0b),
                    icon: Icons.timer_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _ChartCard(
                title: 'Emails per day',
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final points = _viewModel.dailyPoints;
                    final isThirtyDays =
                        _viewModel.selectedPeriod == DashboardPeriod.thirtyDays;
                    final minWidth = constraints.maxWidth;
                    final contentWidth =
                        isThirtyDays
                            ? (points.length * 42.0)
                            : constraints.maxWidth;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isThirtyDays) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.swap_horiz,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Swipe horizontally to see all 30 days',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        Scrollbar(
                          controller: _thirtyDaysScrollController,
                          thumbVisibility: isThirtyDays,
                          child: SingleChildScrollView(
                            controller: _thirtyDaysScrollController,
                            scrollDirection: Axis.horizontal,
                            physics:
                                isThirtyDays
                                    ? const BouncingScrollPhysics()
                                    : const NeverScrollableScrollPhysics(),
                            child: SizedBox(
                              width:
                                  contentWidth < minWidth
                                      ? minWidth
                                      : contentWidth,
                              height: 220,
                              child: BarChart(
                                BarChartData(
                                  gridData: const FlGridData(show: false),
                                  borderData: FlBorderData(show: false),
                                  titlesData: FlTitlesData(
                                    leftTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    topTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        interval: 1,
                                        getTitlesWidget: (value, meta) {
                                          if (value % 1 != 0) {
                                            return const SizedBox();
                                          }
                                          final index = value.toInt();
                                          if (index < 0 ||
                                              index >= points.length) {
                                            return const SizedBox();
                                          }
                                          final point = points[index];
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            child: Text(
                                              point.label,
                                              style: const TextStyle(
                                                fontSize: 10,
                                              ),
                                            ),
                                          );
                                        },
                                        reservedSize: 24,
                                      ),
                                    ),
                                  ),
                                  barGroups:
                                      points.asMap().entries.map((entry) {
                                        final index = entry.key;
                                        final point = entry.value;
                                        return BarChartGroupData(
                                          x: index,
                                          barRods: [
                                            BarChartRodData(
                                              toY: point.value,
                                              color: AppPalette.lavender,
                                              width: 14,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _ChartCard(
                      title: 'Category split',
                      child: SizedBox(
                        height: 220,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 4,
                            centerSpaceRadius: 38,
                            sections:
                                _viewModel.categoryPoints.map((point) {
                                  return PieChartSectionData(
                                    color: point.color,
                                    value: point.value,
                                    title: '${point.value.toStringAsFixed(0)}%',
                                    radius: 52,
                                    titleStyle: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ChartCard(
                      title: 'Sentiment',
                      child: SizedBox(
                        height: 220,
                        child: Center(
                          child: SizedBox(
                            width: 120,
                            height: 120,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: (_viewModel.averageSentimentScore /
                                          100)
                                      .clamp(0.0, 1.0),
                                  strokeWidth: 12,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppPalette.teal,
                                  ),
                                ),
                                Text(
                                  '${_viewModel.averageSentimentScore.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onChanged});

  final DashboardPeriod selected;
  final ValueChanged<DashboardPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children:
            DashboardPeriod.values.map((period) {
              final isSelected = period == selected;
              final label = switch (period) {
                DashboardPeriod.sevenDays => '7d',
                DashboardPeriod.thirtyDays => '30d',
              };

              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(period),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? AppPalette.lavender : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppPalette.pine,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(icon, color: color),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.content,
    required this.color,
  });

  final String title;
  final String content;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(content),
        ],
      ),
    );
  }
}
