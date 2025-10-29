import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../data/app_repository.dart';
import '../../models/revenue_point.dart';

class AdminRevenueTab extends StatefulWidget {
  const AdminRevenueTab({super.key});

  @override
  State<AdminRevenueTab> createState() => _AdminRevenueTabState();
}

class _AdminRevenueTabState extends State<AdminRevenueTab> {
  DateTimeRange? range;
  RevenueGroupBy groupBy = RevenueGroupBy.day;
  List<RevenuePoint> points = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _quick(QuickRange.last7);
    // Tự load sau frame đầu để có context cho InheritedApp
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final repo = InheritedApp.of(context);
      _load(repo);
    });
  }

  Future<void> _load(AppRepository repo) async {
    if (range == null) return;
    setState(() => loading = true);
    final data = await repo.fetchRevenue(
      from: range!.start,
      to: range!.end,
      groupBy: groupBy,
    );
    setState(() {
      points = data;
      loading = false;
    });
  }

  void _quick(QuickRange qr) {
    final now = DateTime.now();
    switch (qr) {
      case QuickRange.today:
        range = DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
        groupBy = RevenueGroupBy.day;
        break;
      case QuickRange.last7:
        final start = now.subtract(const Duration(days: 6));
        range = DateTimeRange(
          start: DateTime(start.year, start.month, start.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
        groupBy = RevenueGroupBy.day;
        break;
      case QuickRange.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 1).subtract(const Duration(seconds: 1));
        range = DateTimeRange(start: start, end: end);
        groupBy = RevenueGroupBy.day;
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = InheritedApp.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Hôm nay'),
                  selected: _isSelected(QuickRange.today),
                  onSelected: (_) {
                    setState(() => _quick(QuickRange.today));
                    _load(repo);
                  },
                ),
                FilterChip(
                  label: const Text('7 ngày'),
                  selected: _isSelected(QuickRange.last7),
                  onSelected: (_) {
                    setState(() => _quick(QuickRange.last7));
                    _load(repo);
                  },
                ),
                FilterChip(
                  label: const Text('Tháng này'),
                  selected: _isSelected(QuickRange.thisMonth),
                  onSelected: (_) {
                    setState(() => _quick(QuickRange.thisMonth));
                    _load(repo);
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: Text(_labelRange()),
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(now.year - 2),
                      lastDate: DateTime(now.year + 1),
                      initialDateRange: range ??
                          DateTimeRange(
                            start: DateTime(now.year, now.month, 1),
                            end: DateTime(now.year, now.month, now.day),
                          ),
                    );
                    if (picked != null) {
                      setState(() {
                        range = picked;
                        groupBy = RevenueGroupBy.day;
                      });
                      _load(repo);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : points.isEmpty
                      ? const Center(child: Text('Chưa có dữ liệu doanh thu trong khoảng đã chọn'))
                      : _RevenueChart(points: points),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSelected(QuickRange qr) {
    if (range == null) return false;
    final now = DateTime.now();
    switch (qr) {
      case QuickRange.today:
        final s = DateTime(now.year, now.month, now.day);
        final e = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return range!.start == s && range!.end == e;
      case QuickRange.last7:
        final start = now.subtract(const Duration(days: 6));
        final s2 = DateTime(start.year, start.month, start.day);
        final e2 = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return range!.start == s2 && range!.end == e2;
      case QuickRange.thisMonth:
        final s3 = DateTime(now.year, now.month, 1);
        final e3 = DateTime(now.year, now.month + 1, 1).subtract(const Duration(seconds: 1));
        return range!.start == s3 && range!.end == e3;
    }
  }

  String _labelRange() {
    if (range == null) return 'Khoảng ngày';
    String fmt(DateTime d) => '${d.day}/${d.month}';
    return '${fmt(range!.start)} - ${fmt(range!.end)}';
  }
}

enum QuickRange { today, last7, thisMonth }

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.points});
  final List<RevenuePoint> points;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].total));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              spots: spots,
              dotData: const FlDotData(show: true),
            )
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (v, meta) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= points.length) return const SizedBox();
                  final d = points[idx].bucket;
                  return Text('${d.day}/${d.month}', style: const TextStyle(fontSize: 11));
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: _interval(points),
                getTitlesWidget: (v, meta) => Text(v.toStringAsFixed(0)),
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(show: true),
        ),
      ),
    );
  }

  double _interval(List<RevenuePoint> pts) {
    final maxY = pts.fold<double>(0, (m, e) => e.total > m ? e.total : m);
    if (maxY <= 0) return 1;
    final v = maxY / 4;
    return v < 1 ? 1 : v;
  }
}

