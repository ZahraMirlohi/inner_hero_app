// lib/features/arena/widgets/timer_picker_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/l10n/app_strings.dart';
import '/providers/theme_provider.dart';

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
  late FixedExtentScrollController _minutesController;
  late FixedExtentScrollController _secondsController;

  @override
  void initState() {
    super.initState();
    _minutes = widget.initialMinutes.clamp(0, 60).toInt();
    _seconds = widget.initialSeconds.clamp(0, 59).toInt();
    _minutesController = FixedExtentScrollController(initialItem: _minutes);
    _secondsController = FixedExtentScrollController(initialItem: _seconds);
  }

  @override
  void dispose() {
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  Widget _wheel({
    required ThemeProvider theme,
    required String title,
    required FixedExtentScrollController controller,
    required int count,
    required int selected,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 88,
          height: 160,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: theme.cardSecondaryColor,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              IgnorePointer(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.primarySoft,
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),
              ListWheelScrollView.useDelegate(
                controller: controller,
                itemExtent: 40,
                diameterRatio: 100,
                perspective: 0.0001,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (index) {
                  setState(() {
                    if (identical(controller, _minutesController)) {
                      _minutes = index;
                    } else {
                      _seconds = index;
                    }
                  });
                  onChanged(index);
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: count,
                  builder: (context, index) {
                    final dist = (index - selected).abs();
                    return Center(
                      child: Opacity(
                        opacity: dist == 0 ? 1 : (dist == 1 ? 0.5 : 0.22),
                        child: Text(
                          index.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: dist == 0 ? 20 : 16,
                            fontWeight:
                                dist == 0 ? FontWeight.w800 : FontWeight.w600,
                            color: theme.textColor,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _wheel(
          theme: theme,
          title: context.tr('af.timer.minutes'),
          controller: _minutesController,
          count: 61,
          selected: _minutes,
          onChanged: widget.onMinutesChanged,
        ),
        const SizedBox(width: 14),
        Padding(
          padding: const EdgeInsets.only(top: 22),
          child: Text(
            ':',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: theme.textColor,
            ),
          ),
        ),
        const SizedBox(width: 14),
        _wheel(
          theme: theme,
          title: context.tr('af.timer.seconds'),
          controller: _secondsController,
          count: 60,
          selected: _seconds,
          onChanged: widget.onSecondsChanged,
        ),
      ],
    );
  }
}
