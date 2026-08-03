import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';

enum AnalyticsFilterMode { daily, monthly, lastMonth, custom }

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  AnalyticsFilterMode _filterMode = AnalyticsFilterMode.monthly;
  DateTimeRange? _customDateRange;
  int _touchedIndex = -1;

  // Soft palette for categories
  static const List<Color> _palette = [
    Color(0xFF6C5CE7), Color(0xFFFF7675), Color(0xFF00B894),
    Color(0xFFFDCB6E), Color(0xFF74B9FF), Color(0xFFE17055),
    Color(0xFFA29BFE), Color(0xFF55EFC4), Color(0xFFFF9FF3),
    Color(0xFF636E72),
  ];

  Color _colorFor(int idx) => _palette[idx % _palette.length];

  List<TransactionModel> _filteredTransactions(List<TransactionModel> all) {
    final now = DateTime.now();

    switch (_filterMode) {
      case AnalyticsFilterMode.daily:
        final today = DateTime(now.year, now.month, now.day);
        return all.where((tx) {
          final d = DateTime.tryParse(tx.date);
          if (d == null) return false;
          return d.year == today.year && d.month == today.month && d.day == today.day;
        }).toList();

      case AnalyticsFilterMode.monthly:
        final start = DateTime(now.year, now.month, 1);
        final end = (now.month == 12) ? DateTime(now.year + 1, 1, 1) : DateTime(now.year, now.month + 1, 1);
        return all.where((tx) {
          final d = DateTime.tryParse(tx.date);
          return d != null && d.isAfter(start.subtract(const Duration(seconds: 1))) && d.isBefore(end);
        }).toList();

      case AnalyticsFilterMode.lastMonth:
        final lastMonthDate = DateTime(now.year, now.month - 1, 1);
        final start = DateTime(lastMonthDate.year, lastMonthDate.month, 1);
        final end = DateTime(now.year, now.month, 1);
        return all.where((tx) {
          final d = DateTime.tryParse(tx.date);
          return d != null && d.isAfter(start.subtract(const Duration(seconds: 1))) && d.isBefore(end);
        }).toList();

      case AnalyticsFilterMode.custom:
        if (_customDateRange == null) {
          return all;
        }
        final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day, 0, 0, 0);
        final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
        return all.where((tx) {
          final d = DateTime.tryParse(tx.date);
          return d != null && d.isAfter(start.subtract(const Duration(seconds: 1))) && d.isBefore(end.add(const Duration(seconds: 1)));
        }).toList();
    }
  }

  Map<String, double> _groupByCategory(List<TransactionModel> txs, String type) {
    final map = <String, double>{};
    for (final tx in txs.where((t) => t.type == type)) {
      map[tx.category] = (map[tx.category] ?? 0) + tx.amount;
    }
    // Sort descending
    final sorted = Map.fromEntries(
        map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
    return sorted;
  }

  Future<void> _pickCustomCalendarRange() async {
    final now = DateTime.now();
    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _customDateRange ?? DateTimeRange(
        start: now.subtract(const Duration(days: 7)),
        end: now,
      ),
      builder: (ctx, child) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFF6C5CE7),
                    surface: Color(0xFF1E1E2E),
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF6C5CE7),
                    surface: Colors.white,
                    onSurface: Colors.black87,
                  ),
                ),
          child: child!,
        );
      },
    );

    if (pickedRange != null) {
      setState(() {
        _customDateRange = pickedRange;
        _filterMode = AnalyticsFilterMode.custom;
      });
    }
  }

  String _getFilterSubheaderLabel() {
    final now = DateTime.now();
    switch (_filterMode) {
      case AnalyticsFilterMode.daily:
        return "Today (${DateFormat('dd MMM yyyy').format(now)})";
      case AnalyticsFilterMode.monthly:
        return "This Month (${DateFormat('MMMM yyyy').format(now)})";
      case AnalyticsFilterMode.lastMonth:
        final lastMonthDate = DateTime(now.year, now.month - 1, 1);
        return "Last Month (${DateFormat('MMMM yyyy').format(lastMonthDate)})";
      case AnalyticsFilterMode.custom:
        if (_customDateRange != null) {
          final fmt = DateFormat('dd MMM');
          return "${fmt.format(_customDateRange!.start)} - ${fmt.format(_customDateRange!.end)}";
        }
        return "Custom Range";
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<TransactionProvider>().transactions;
    final filteredTx = _filteredTransactions(all);
    final debitMap = _groupByCategory(filteredTx, 'debit');
    final creditMap = _groupByCategory(filteredTx, 'credit');
    final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Analytics",
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // ── Filter Buttons Bar (Fits all 4 buttons on screen without scrolling) ────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildCompactFilterBtn(
                    label: "Daily",
                    icon: Icons.today_rounded,
                    isSelected: _filterMode == AnalyticsFilterMode.daily,
                    onTap: () => setState(() => _filterMode = AnalyticsFilterMode.daily),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildCompactFilterBtn(
                    label: "Monthly",
                    icon: Icons.calendar_view_month_rounded,
                    isSelected: _filterMode == AnalyticsFilterMode.monthly,
                    onTap: () => setState(() => _filterMode = AnalyticsFilterMode.monthly),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildCompactFilterBtn(
                    label: "Last Month",
                    icon: Icons.history_rounded,
                    isSelected: _filterMode == AnalyticsFilterMode.lastMonth,
                    onTap: () => setState(() => _filterMode = AnalyticsFilterMode.lastMonth),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildCompactFilterBtn(
                    label: _filterMode == AnalyticsFilterMode.custom && _customDateRange != null
                        ? "Custom Range"
                        : "Calendar",
                    icon: Icons.edit_calendar_rounded,
                    isSelected: _filterMode == AnalyticsFilterMode.custom,
                    onTap: _pickCustomCalendarRange,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),

          // Subheader showing selected date range
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: isDark ? Colors.white54 : Colors.black54),
                const SizedBox(width: 6),
                Text(
                  _getFilterSubheaderLabel(),
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  "${filteredTx.length} Transactions",
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6C5CE7), fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          Expanded(
            child: filteredTx.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bar_chart_rounded,
                            color: isDark ? Colors.white24 : Colors.black26, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          "No data for ${_getFilterSubheaderLabel()}",
                          style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 15),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (debitMap.isNotEmpty) ...[
                          _sectionTitle("Expenses by Category", isDark),
                          const SizedBox(height: 16),
                          _pieChart(debitMap, fmt, isDark),
                          const SizedBox(height: 16),
                          _legend(debitMap, fmt, isDark),
                          const SizedBox(height: 24),
                          _sectionTitle("Top Expense Categories", isDark),
                          const SizedBox(height: 16),
                          _barChart(debitMap, fmt, const Color(0xFFFF7675), isDark),
                          const SizedBox(height: 24),
                        ],
                        if (creditMap.isNotEmpty) ...[
                          _sectionTitle("Income by Category", isDark),
                          const SizedBox(height: 16),
                          _pieChart(creditMap, fmt, isDark, isCredit: true),
                          const SizedBox(height: 16),
                          _legend(creditMap, fmt, isDark, isCredit: true),
                          const SizedBox(height: 24),
                        ],
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactFilterBtn({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final activeBg = const Color(0xFF6C5CE7);
    final inactiveBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final activeText = Colors.white;
    final inactiveText = isDark ? Colors.white70 : Colors.black87;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeBg : (isDark ? Colors.white10 : Colors.black.withOpacity(0.08)),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF6C5CE7).withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? activeText : inactiveText),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? activeText : inactiveText,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, bool isDark) => Text(
        title,
        style: TextStyle(
            color: isDark ? Colors.white : Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
      );

  Widget _pieChart(Map<String, double> data, NumberFormat fmt, bool isDark,
      {bool isCredit = false}) {
    final keys   = data.keys.toList();
    final total  = data.values.fold(0.0, (s, v) => s + v);

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      _touchedIndex = (response?.touchedSection?.touchedSectionIndex ?? -1);
                    });
                  },
                ),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: List.generate(keys.length, (i) {
                  final isTouched = i == _touchedIndex;
                  final pct = data[keys[i]]! / total * 100;
                  return PieChartSectionData(
                    color: _colorFor(isCredit ? i + 5 : i),
                    value: data[keys[i]],
                    title: '${pct.toStringAsFixed(0)}%',
                    radius: isTouched ? 60 : 50,
                    titleStyle: TextStyle(
                      fontSize: isTouched ? 13 : 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCredit ? "Total Income" : "Total Spent",
                style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 11),
              ),
              Text(
                fmt.format(total),
                style: TextStyle(
                  color: isCredit
                      ? const Color(0xFF00B894)
                      : const Color(0xFFFF7675),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Map<String, double> data, NumberFormat fmt, bool isDark,
      {bool isCredit = false}) {
    final keys  = data.keys.toList();
    final total = data.values.fold(0.0, (s, v) => s + v);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: keys.length,
        separatorBuilder: (_, __) =>
            Divider(color: isDark ? Colors.white10 : Colors.black12, height: 1),
        itemBuilder: (ctx, i) {
          final pct = data[keys[i]]! / total * 100;
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _colorFor(isCredit ? i + 5 : i),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(keys[i],
                      style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87, fontSize: 13)),
                ),
                Text(
                  '${pct.toStringAsFixed(1)}%',
                  style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black54, fontSize: 12),
                ),
                const SizedBox(width: 12),
                Text(
                  fmt.format(data[keys[i]]),
                  style: TextStyle(
                    color: isCredit
                        ? const Color(0xFF00B894)
                        : const Color(0xFFFF7675),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _barChart(Map<String, double> data, NumberFormat fmt, Color color, bool isDark) {
    final keys = data.keys.take(6).toList(); // top 6
    final maxVal = data.values.fold(0.0, (m, v) => v > m ? v : m);

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
      child: BarChart(
        BarChartData(
          maxY: maxVal * 1.2,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  final idx = val.toInt();
                  if (idx < 0 || idx >= keys.length) {
                    return const SizedBox.shrink();
                  }
                  final label = keys[idx].length > 7
                      ? keys[idx].substring(0, 7)
                      : keys[idx];
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(label,
                        style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54, fontSize: 9)),
                  );
                },
                reservedSize: 28,
              ),
            ),
          ),
          barGroups: List.generate(keys.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: data[keys[i]]!,
                  color: _colorFor(i),
                  width: 22,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
