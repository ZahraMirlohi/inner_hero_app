// lib/features/arena/widgets/habit_chart_widget.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../models/habit_completion.dart';
import '/providers/theme_provider.dart';
import '/providers/calendar_provider.dart';
import '/l10n/app_strings.dart';

class HabitChartWidget extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final String habitTitle;
  final String? targetValue;

  const HabitChartWidget({
    super.key,
    required this.data,
    required this.habitTitle,
    this.targetValue,
  });

  @override
  State<HabitChartWidget> createState() => _HabitChartWidgetState();
}

class _HabitChartWidgetState extends State<HabitChartWidget> {
  final ScrollController _scrollController = ScrollController();
  bool _isInitialScrollDone = false;
  CalendarType? _lastCalendarType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToToday();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final calendar = Provider.of<CalendarProvider>(context);
    if (_lastCalendarType != calendar.calendarType) {
      _lastCalendarType = calendar.calendarType;
      _isInitialScrollDone = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToToday();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToToday() {
    if (_isInitialScrollDone || widget.data.isEmpty) return;
    final now = DateTime.now();
    final todayStr = now.toIso8601String().split('T').first;
    int todayIndex = -1;
    for (int i = 0; i < widget.data.length; i++) {
      if (widget.data[i]['date'] == todayStr) {
        todayIndex = i;
        break;
      }
    }
    if (todayIndex == -1) todayIndex = widget.data.length - 1;

    final totalDays = widget.data.length;
    final minWidth = MediaQuery.of(context).size.width - 32;
    final chartWidth = math.max(minWidth, totalDays * 32.0);
    final xStep = totalDays > 1 ? chartWidth / (totalDays - 1) : 0;
    final targetPosition =
        (todayIndex * xStep) - (MediaQuery.of(context).size.width / 2) + 50;
    final maxScroll =
        math.max(0.0, chartWidth - (MediaQuery.of(context).size.width - 32));
    final clampedPosition = targetPosition.clamp(0.0, maxScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && !_isInitialScrollDone) {
        _scrollController.animateTo(
          clampedPosition,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
        _isInitialScrollDone = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final calendar = Provider.of<CalendarProvider>(context);

    if (widget.data.isEmpty) return _buildEmptyState(theme);
    final validData =
        widget.data.where((d) => d['isCompleted'] == true).toList();
    if (validData.isEmpty) return _buildNoDataState(theme);

    return _card(
      theme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(theme),
          const SizedBox(height: 12),
          Container(
            height: 132,
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            decoration: BoxDecoration(
              color: theme.backgroundColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: _buildChart(calendar, theme),
            ),
          ),
          const SizedBox(height: 12),
          _buildLegend(theme),
          const SizedBox(height: 12),
          Text(
            context.tr('ad.chart.footer'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: theme.textSecondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _card(ThemeProvider theme, Widget child,
      {EdgeInsets padding = const EdgeInsets.all(16)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: theme.softShadow,
      ),
      child: child,
    );
  }

  Widget _buildEmptyState(ThemeProvider theme) {
    return _card(
      theme,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.cardSecondaryColor,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.bar_chart_rounded,
                size: 28, color: theme.textSecondaryColor),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('ad.chart.empty'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('ad.chart.emptyHint'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: theme.textSecondaryColor),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
    );
  }

  Widget _buildNoDataState(ThemeProvider theme) {
    return _card(
      theme,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('ad.chart.noMonth'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('ad.chart.noMonthHint'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: theme.textSecondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeProvider theme) {
    return Row(
      children: [
        Icon(Icons.bar_chart_rounded, size: 20, color: theme.textColor),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            context.tr('ad.chart.title'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: theme.textColor,
            ),
          ),
        ),
        const Spacer(),
        if (widget.targetValue != null && widget.targetValue!.isNotEmpty)
          Container(
            height: 26,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: theme.primarySoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              widget.targetValue!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.textColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChart(CalendarProvider calendar, ThemeProvider theme) {
    final totalDays = widget.data.length;
    final minWidth = MediaQuery.of(context).size.width - 32;
    final chartWidth = math.max(minWidth, totalDays * 32.0);
    return SizedBox(
      width: chartWidth,
      height: 120,
      child: CustomPaint(
        painter: _HabitChartPainter(
          allData: widget.data,
          calendar: calendar,
          emptyColor: theme.cardSecondaryColor,
          textSecondaryColor: theme.textSecondaryColor,
        ),
      ),
    );
  }

  Widget _buildLegend(ThemeProvider theme) {
    Widget item(String text, {Color? color}) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color ?? theme.textColor,
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: [
        for (final level in CompletionLevel.values)
          item('${level.emoji} ${context.tr('ad.lvl.name.${level.name}')}'),
        item(context.tr('ad.lvl.notDone'), color: theme.textSecondaryColor),
      ],
    );
  }
}

// ==================== Custom Painter ====================

class _HabitChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> allData;
  final CalendarProvider calendar;
  final Color emptyColor;
  final Color textSecondaryColor;

  _HabitChartPainter({
    required this.allData,
    required this.calendar,
    required this.emptyColor,
    required this.textSecondaryColor,
  });

  static const double _labelHeight = 14;

  @override
  void paint(Canvas canvas, Size size) {
    if (allData.isEmpty) return;
    final slot = size.width / allData.length;
    final barArea = size.height - _labelHeight;
    // ارتفاع کامل = ۹۰٪ ناحیه میله‌ها (مثل طراحی: ۹۹ از ۱۱۰)
    final fullHeight = barArea * 0.9;
    final barWidth = math.min(18.0, slot * 0.6);

    for (int i = 0; i < allData.length; i++) {
      final cx = slot * i + slot / 2;
      final done = allData[i]['isCompleted'] == true;
      final String level = (allData[i]['level'] ?? '').toString();

      if (done) {
        double fraction;
        Color color;
        switch (level) {
          case 'half':
            fraction = 2 / 3;
            color = CompletionLevel.half.color;
            break;
          case 'basic':
            fraction = 1 / 3;
            color = CompletionLevel.basic.color;
            break;
          default:
            fraction = 1.0;
            color = CompletionLevel.full.color;
        }
        final h = fullHeight * fraction;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - barWidth / 2, barArea - h, barWidth, h),
            Radius.circular(barWidth / 2),
          ),
          Paint()..color = color,
        );
      } else {
        // روز انجام‌نشده: یک میلهٔ کوتاه کم‌رنگ
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - barWidth / 2, barArea - barWidth, barWidth,
                barWidth),
            Radius.circular(barWidth / 2),
          ),
          Paint()..color = emptyColor,
        );
      }

      String label;
      final date = DateTime.parse(allData[i]['date'].toString());
      if (calendar.isJalali) {
        label = Jalali.fromDateTime(date).day.toString();
      } else {
        label = date.day.toString();
      }
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: textSecondaryColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, size.height - tp.height - 1));
    }
  }

  @override
  bool shouldRepaint(covariant _HabitChartPainter oldDelegate) {
    return oldDelegate.allData != allData ||
        oldDelegate.calendar.calendarType != calendar.calendarType ||
        oldDelegate.emptyColor != emptyColor ||
        oldDelegate.textSecondaryColor != textSecondaryColor;
  }
}
