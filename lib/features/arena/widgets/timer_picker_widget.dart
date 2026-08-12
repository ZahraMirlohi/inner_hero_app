// lib/features/arena/widgets/timer_picker_widget.dart

import 'package:flutter/material.dart';

class TimerPickerWidget extends StatefulWidget {
  final int initialMinutes;
  final int initialSeconds;
  final ValueChanged<int> onMinutesChanged;
  final ValueChanged<int> onSecondsChanged;

  const TimerPickerWidget({
    super.key,
    required this.initialMinutes,
    required this.initialSeconds,
    required this.onMinutesChanged,
    required this.onSecondsChanged,
  });

  @override
  State<TimerPickerWidget> createState() => _TimerPickerWidgetState();
}

class _TimerPickerWidgetState extends State<TimerPickerWidget> {
  late int _minutes;
  late int _seconds;

  @override
  void initState() {
    super.initState();
    _minutes = widget.initialMinutes;
    _seconds = widget.initialSeconds;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ✅ انتخاب دقیقه
        Column(
          children: [
            const Text(
              'دقیقه',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Container(
              width: 80,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ListWheelScrollView(
                itemExtent: 40,
                diameterRatio: 1.5,
                onSelectedItemChanged: (index) {
                  setState(() {
                    _minutes = index;
                  });
                  widget.onMinutesChanged(index);
                },
                children: List.generate(61, (index) {
                  final isSelected = index == _minutes;
                  return Center(
                    child: Text(
                      index.toString().padLeft(2, '0'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? const Color(0xFF4A90E2)
                            : Colors.grey.shade600,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        const Text(
          ':',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 16),
        // ✅ انتخاب ثانیه
        Column(
          children: [
            const Text(
              'ثانیه',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Container(
              width: 80,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ListWheelScrollView(
                itemExtent: 40,
                diameterRatio: 1.5,
                onSelectedItemChanged: (index) {
                  setState(() {
                    _seconds = index;
                  });
                  widget.onSecondsChanged(index);
                },
                children: List.generate(60, (index) {
                  final isSelected = index == _seconds;
                  return Center(
                    child: Text(
                      index.toString().padLeft(2, '0'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? const Color(0xFF4A90E2)
                            : Colors.grey.shade600,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
