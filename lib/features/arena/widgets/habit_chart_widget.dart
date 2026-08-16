// lib/features/arena/widgets/habit_chart_widget.dart

import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../models/habit_completion.dart';
import '/services/date_service.dart';

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
  String _calendarType = 'jalali';
  final ScrollController _scrollController = ScrollController();
  bool _isInitialScrollDone = false;

  @override
  void initState() {
    super.initState();
    _loadCalendarType();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToToday();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCalendarType() async {
    final calendarType = await DateService.getCalendarType();
    if (mounted) {
      setState(() {
        _calendarType = calendarType;
      });
    }
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

    if (todayIndex == -1) {
      todayIndex = widget.data.length - 1;
    }

    final totalDays = widget.data.length;
    final minWidth = MediaQuery.of(context).size.width - 32;
    final chartWidth = (totalDays * 32.0).clamp(minWidth, totalDays * 32.0);
    final xStep = totalDays > 1 ? chartWidth / (totalDays - 1) : 0;

    final targetPosition =
        (todayIndex * xStep) - (MediaQuery.of(context).size.width / 2) + 50;
    final maxScroll = chartWidth - (MediaQuery.of(context).size.width - 32);

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
    if (widget.data.isEmpty) {
      return _buildEmptyState();
    }

    final validData =
        widget.data.where((d) => d['isCompleted'] == true).toList();

    if (validData.isEmpty) {
      return _buildNoDataState();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: _buildChart(),
            ),
          ),
          const SizedBox(height: 8),
          _buildLegend(),
          const SizedBox(height: 6),
          _buildSummaryStats(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'هنوز داده‌ای برای نمایش وجود ندارد',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            Text(
              'با انجام عادت، نمودار ساخته می‌شود',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataState() {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'هیچ روزی در این ماه تکمیل نشده',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            Text(
              'روزهای آینده را از دست نده! 💪',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Text(
          '📊 روند پیشرفت ماه جاری',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        if (widget.targetValue != null && widget.targetValue!.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF4A90E2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '🎯 ${widget.targetValue}',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF4A90E2),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChart() {
    final totalDays = widget.data.length;
    final minWidth = MediaQuery.of(context).size.width - 32;
    final chartWidth = (totalDays * 32.0).clamp(minWidth, totalDays * 32.0);

    return SizedBox(
      width: chartWidth,
      height: 200,
      child: CustomPaint(
        painter: _HabitChartPainter(
          allData: widget.data,
          calendarType: _calendarType,
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(CompletionLevel.full),
        const SizedBox(width: 10),
        _buildLegendItem(CompletionLevel.half),
        const SizedBox(width: 10),
        _buildLegendItem(CompletionLevel.basic),
        const SizedBox(width: 10),
        _buildLegendItem(null),
      ],
    );
  }

  Widget _buildLegendItem(CompletionLevel? level) {
    Color color;
    String label;
    IconData icon;

    if (level == null) {
      color = Colors.grey.shade300;
      label = 'انجام نشده';
      icon = Icons.circle_outlined;
    } else {
      color = level.color;
      label = level.displayName;
      icon = Icons.circle;
    }

    return Row(
      children: [
        Icon(icon, color: color, size: 10),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildSummaryStats() {
    final fullCount = widget.data
        .where(
          (d) => d['isCompleted'] == true && d['level'] == 'full',
        )
        .length;
    final halfCount = widget.data
        .where(
          (d) => d['isCompleted'] == true && d['level'] == 'half',
        )
        .length;
    final basicCount = widget.data
        .where(
          (d) => d['isCompleted'] == true && d['level'] == 'basic',
        )
        .length;
    final totalCompleted = fullCount + halfCount + basicCount;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('🌟 کامل', fullCount, const Color(0xFF2ECC71)),
          _buildStatItem('⭐ نیمه', halfCount, const Color(0xFFFFA500)),
          _buildStatItem('✨ پایه', basicCount, const Color(0xFF3498DB)),
          _buildStatItem('📊 مجموع', totalCompleted, const Color(0xFF4A90E2)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

// ==================== Custom Painter ====================

class _HabitChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> allData;
  final String calendarType;

  _HabitChartPainter({
    required this.allData,
    required this.calendarType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (allData.isEmpty) return;

    // ✅ padding با فضای کافی برای اعداد
    final padding = const EdgeInsets.fromLTRB(45, 8, 8, 35);
    final chartWidth = size.width - padding.left - padding.right;
    final chartHeight = size.height - padding.top - padding.bottom;

    double getLevelValue(String level) {
      switch (level) {
        case 'full':
          return 3.0;
        case 'half':
          return 2.0;
        case 'basic':
          return 1.0;
        default:
          return 0.0;
      }
    }

    _drawYAxisGuidelines(canvas, padding, chartHeight, chartWidth);

    final xStep = allData.length > 1 ? chartWidth / (allData.length - 1) : 0.0;
    final points = <Offset>[];

    for (int i = 0; i < allData.length; i++) {
      final x = padding.left + (i * xStep);
      final isCompleted = allData[i]['isCompleted'] == true;

      if (isCompleted) {
        final value = getLevelValue(allData[i]['level']);
        final y = padding.top + chartHeight - (value / 3 * chartHeight);
        points.add(Offset(x, y));
      }
    }

    // روزهای بدون داده (خاکستری)
    for (int i = 0; i < allData.length; i++) {
      final x = padding.left + (i * xStep);
      final isCompleted = allData[i]['isCompleted'] == true;

      if (!isCompleted) {
        final y = padding.top + chartHeight - (0.5 / 3 * chartHeight);
        final dotPaint = Paint()
          ..color = Colors.grey.shade300
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, y), 4, dotPaint);
      }
    }

    // خط بین نقاط
    if (points.length > 1) {
      final linePaint = Paint()
        ..color = const Color(0xFF4A90E2)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < points.length - 1; i++) {
        canvas.drawLine(points[i], points[i + 1], linePaint);
      }
    }

    // نقاط انجام شده
    for (int i = 0; i < points.length; i++) {
      final level = allData[i % allData.length]['level'] ?? 'full';
      Color color;
      switch (level) {
        case 'full':
          color = const Color(0xFF2ECC71);
          break;
        case 'half':
          color = const Color(0xFFFFA500);
          break;
        case 'basic':
          color = const Color(0xFF3498DB);
          break;
        default:
          color = Colors.grey;
      }

      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawCircle(points[i], 6, dotPaint);

      final borderPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(points[i], 6, borderPaint);

      final emoji = _getLevelEmoji(level);
      final textSpan = TextSpan(
        text: emoji,
        style: const TextStyle(fontSize: 8),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(points[i].dx - textPainter.width / 2,
            points[i].dy - textPainter.height / 2),
      );
    }

    _drawDayLabels(canvas, size, padding, xStep);
  }

  void _drawYAxisGuidelines(
    Canvas canvas,
    EdgeInsets padding,
    double chartHeight,
    double chartWidth,
  ) {
    final levels = [
      {'label': '🌟 کامل', 'value': 3.0, 'color': const Color(0xFF2ECC71)},
      {'label': '⭐ نیمه', 'value': 2.0, 'color': const Color(0xFFFFA500)},
      {'label': '✨ پایه', 'value': 1.0, 'color': const Color(0xFF3498DB)},
    ];

    final textStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );

    for (var level in levels) {
      final y = padding.top +
          chartHeight -
          ((level['value'] as double) / 3 * chartHeight);

      final dashPaint = Paint()
        ..color = (level['color'] as Color).withOpacity(0.25)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;

      final dashWidth = 3.0;
      final dashSpace = 3.0;
      double startX = padding.left;
      final endX = padding.left + chartWidth;

      while (startX < endX) {
        canvas.drawLine(
          Offset(startX, y),
          Offset(startX + dashWidth, y),
          dashPaint,
        );
        startX += dashWidth + dashSpace;
      }

      final textSpan = TextSpan(
        text: level['label'] as String,
        style: textStyle.copyWith(
          color: level['color'] as Color,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.rtl,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(2, y - textPainter.height / 2),
      );
    }
  }

  void _drawDayLabels(
    Canvas canvas,
    Size size,
    EdgeInsets padding,
    double xStep,
  ) {
    final textStyle = TextStyle(
      fontSize: 9,
      color: Colors.grey.shade800,
      fontWeight: FontWeight.w600,
    );

    for (int i = 0; i < allData.length; i++) {
      final x = padding.left + (i * xStep);
      final dateStr = allData[i]['date'];
      final date = DateTime.parse(dateStr);

      String label;
      if (calendarType == 'jalali') {
        final jalali = Jalali.fromDateTime(date);
        label = jalali.day.toString();
      } else {
        label = date.day.toString();
      }

      final y = size.height - 6;

      final textSpan = TextSpan(
        text: label,
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // ✅ پس‌زمینه سفید برای خوانایی بهتر
      final bgPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromLTWH(
          x - textPainter.width / 2 - 2,
          y - textPainter.height + 1,
          textPainter.width + 4,
          textPainter.height + 2,
        ),
        bgPaint,
      );

      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height + 1),
      );
    }
  }

  String _getLevelEmoji(String level) {
    switch (level) {
      case 'full':
        return '🌟';
      case 'half':
        return '⭐';
      case 'basic':
        return '✨';
      default:
        return '○';
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
