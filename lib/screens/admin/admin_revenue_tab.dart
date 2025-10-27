import 'package:demodidong/data/app_repository.dart';
import 'package:demodidong/models/revenue_point.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// ================= TAB 3: DOANH THU =================

class AdminRevenueTab extends StatefulWidget {
  const AdminRevenueTab({super.key});

  @override
  State<AdminRevenueTab> createState() => _RevenueTabState();
}

class _RevenueTabState extends State<AdminRevenueTab> {
  int _days = 14;
  RevenueGroupBy _groupBy = RevenueGroupBy.day;

  Future<List<RevenuePoint>> _load(BuildContext context) async {
    final repo = InheritedApp.of(context);
    final now = DateTime.now();
    if (_groupBy == RevenueGroupBy.day) {
      final from = now.subtract(Duration(days: _days));
      final to = now.add(const Duration(days: 1));
      return repo.fetchRevenue(from: from, to: to, groupBy: _groupBy);
    } else {
      final startMonth = DateTime(now.year, now.month - 11, 1);
      final endMonth = DateTime(now.year, now.month + 1, 1);
      return repo.fetchRevenue(from: startMonth, to: endMonth, groupBy: _groupBy);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Không cần AnimatedBuilder ở đây vì dữ liệu lấy qua Future khi đổi filter
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              DropdownButton<int>(
                value: _days,
                items: const [
                  DropdownMenuItem(value: 7, child: Text('7 ngày')),
                  DropdownMenuItem(value: 14, child: Text('14 ngày')),
                  DropdownMenuItem(value: 30, child: Text('30 ngày')),
                ],
                onChanged: _groupBy == RevenueGroupBy.day
                    ? (v) => setState(() => _days = v!)
                    : null,
              ),
              const SizedBox(width: 12),
              SegmentedButton<RevenueGroupBy>(
                segments: const [
                  ButtonSegment(value: RevenueGroupBy.day, label: Text('Theo ngày')),
                  ButtonSegment(value: RevenueGroupBy.month, label: Text('Theo tháng')),
                ],
                selected: {_groupBy},
                onSelectionChanged: (s) => setState(() => _groupBy = s.first),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<RevenuePoint>>(
            future: _load(context),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snap.data ?? const <RevenuePoint>[];
              if (data.isEmpty) {
                return const Center(child: Text('Chưa có dữ liệu doanh thu'));
              }
              return Padding(
                padding: const EdgeInsets.all(12),
                child: _RevenueBarChart(points: data, groupBy: _groupBy),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RevenueBarChart extends StatelessWidget {
  final List<RevenuePoint> points;
  final RevenueGroupBy groupBy;
  const _RevenueBarChart({required this.points, required this.groupBy});

  @override
  Widget build(BuildContext context) {
    final fmtDay = DateFormat('dd/MM');
    final fmtMonth = DateFormat('MM/yy');

    final bars = <BarChartGroupData>[];
    double maxY = 0;
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      if (p.total > maxY) maxY = p.total;
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: p.total,
              width: 14,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }
    if (maxY == 0) maxY = 1;

    int step = 1;
    if (points.length > 24) step = 3;
    if (points.length > 40) step = 5;

    return BarChart(
      BarChartData(
        barGroups: bars,
        minY: 0,
        maxY: maxY * 1.15,
        gridData: FlGridData(show: true, horizontalInterval: maxY / 4),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
              getTitlesWidget: (v, _) => Text(_abbr(v)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                if (i % step != 0) return const SizedBox.shrink();
                final dt = points[i].bucket;
                final label = groupBy == RevenueGroupBy.day
                    ? fmtDay.format(dt)
                    : fmtMonth.format(dt);
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Transform.rotate(
                    angle: -0.6,
                    child: Text(label, style: const TextStyle(fontSize: 10)),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (g, gi, rod, ri) {
              final p = points[g.x.toInt()];
              final dateStr = groupBy == RevenueGroupBy.day
                  ? DateFormat('EEE, dd/MM/yyyy').format(p.bucket)
                  : DateFormat('MM/yyyy').format(p.bucket);
              return BarTooltipItem(
                '$dateStr\n',
                const TextStyle(fontWeight: FontWeight.bold),
                children: [
                  TextSpan(text: 'Doanh thu: ${_vnd(p.total)}\n'),
                  TextSpan(text: 'Số đơn: ${p.orders}'),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static String _abbr(double v) {
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}B';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }

  static String _vnd(double v) {
    final s = v.toStringAsFixed(0);
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idx = s.length - i;
      b.write(s[i]);
      if ((idx - 1) % 3 == 0 && i != s.length - 1) b.write('.');
    }
    return '${b.toString()} đ';
  }
}
