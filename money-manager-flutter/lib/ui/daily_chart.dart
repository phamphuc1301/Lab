import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../utils/money.dart';

/// Bar per day of the month, with an optional dashed "daily budget" line.
/// Tap or hover a bar to see that day's total.
class DailyChart extends StatefulWidget {
  const DailyChart({super.key, required this.dailyMinor, this.dailyBudgetMinor, required this.currency});

  final List<int> dailyMinor;
  final int? dailyBudgetMinor;
  final String currency;

  @override
  State<DailyChart> createState() => _DailyChartState();
}

class _DailyChartState extends State<DailyChart> {
  int? _selected;

  void _select(Offset position, double width) {
    final day = (position.dx / width * widget.dailyMinor.length).floor().clamp(0, widget.dailyMinor.length - 1);
    if (day != _selected) setState(() => _selected = day);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final selected = _selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          selected == null
              ? (widget.dailyBudgetMinor == null
                  ? l.chartTapHint
                  : l.chartDailyBudget(formatMoney(widget.dailyBudgetMinor!, widget.currency)))
              : l.chartDay('${selected + 1}', formatMoney(widget.dailyMinor[selected], widget.currency)),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) => MouseRegion(
            onHover: (e) => _select(e.localPosition, constraints.maxWidth),
            onExit: (_) => setState(() => _selected = null),
            child: GestureDetector(
              onTapDown: (d) => _select(d.localPosition, constraints.maxWidth),
              onHorizontalDragUpdate: (d) => _select(d.localPosition, constraints.maxWidth),
              child: CustomPaint(
                size: Size(constraints.maxWidth, 140),
                painter: _DailyChartPainter(
                  values: widget.dailyMinor,
                  budget: widget.dailyBudgetMinor,
                  selected: selected,
                  barColor: theme.colorScheme.primary,
                  overColor: Colors.red.shade400,
                  lineColor: theme.colorScheme.outline,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('1', style: theme.textTheme.labelSmall),
            Text('${widget.dailyMinor.length ~/ 2}', style: theme.textTheme.labelSmall),
            Text('${widget.dailyMinor.length}', style: theme.textTheme.labelSmall),
          ],
        ),
      ],
    );
  }
}

class _DailyChartPainter extends CustomPainter {
  _DailyChartPainter({
    required this.values,
    required this.budget,
    required this.selected,
    required this.barColor,
    required this.overColor,
    required this.lineColor,
  });

  final List<int> values;
  final int? budget;
  final int? selected;
  final Color barColor;
  final Color overColor;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = max(values.fold(0, max), budget ?? 0);
    if (maxValue == 0) return;

    final slot = size.width / values.length;
    final barWidth = max(2.0, slot - 2);
    for (var i = 0; i < values.length; i++) {
      if (values[i] == 0) continue;
      final h = values[i] / maxValue * size.height;
      final over = budget != null && values[i] > budget!;
      final color = over ? overColor : barColor;
      final paint = Paint()..color = selected == null || selected == i ? color : color.withValues(alpha: 0.45);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(i * slot + (slot - barWidth) / 2, size.height - h, barWidth, h),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        paint,
      );
    }

    if (budget != null && budget! > 0) {
      final y = size.height - budget! / maxValue * size.height;
      final paint = Paint()
        ..color = lineColor
        ..strokeWidth = 1;
      for (var x = 0.0; x < size.width; x += 7) {
        canvas.drawLine(Offset(x, y), Offset(min(x + 4, size.width), y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DailyChartPainter old) =>
      old.values != values || old.budget != budget || old.selected != selected || old.barColor != barColor;
}
