// lib/features/arena/screens/habit_detail_screen.dart

import '/widgets/bottom_safe.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/features/arena/models/habit_model.dart';
import '/services/supabase_service.dart';
import '/features/arena/models/habit_completion.dart';
import '/features/arena/utils/habit_streaks.dart';
import '/features/arena/widgets/habit_chart_widget.dart';
import '/providers/theme_provider.dart';
import '/core/app_palette.dart';
import '/l10n/app_strings.dart';

class HabitDetailScreen extends StatelessWidget {
  final Habit habit;
  final SupabaseService _supabase = SupabaseService();

  HabitDetailScreen({super.key, required this.habit});

  // استریک از تاریخچهٔ واقعی انجام‌ها محاسبه می‌شود (مقدار ذخیره‌شده روی عادت به‌روز نمی‌شد)
  late final Future<List<HabitCompletion>> _completionsFuture =
      _supabase.getHabitCompletionsWithLevel(
          habitId: habit.id, userId: habit.userId);

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'fitness_center':
        return Icons.fitness_center;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'book':
        return Icons.book;
      case 'science':
        return Icons.science;
      case 'restaurant':
        return Icons.restaurant;
      case 'bedtime':
        return Icons.bedtime;
      case 'water_drop':
        return Icons.water_drop;
      case 'directions_walk':
        return Icons.directions_walk;
      case 'run_circle':
        return Icons.run_circle;
      case 'emoji_events':
        return Icons.emoji_events;
      default:
        return Icons.fitness_center;
    }
  }

  String _getTimeOfDayText(BuildContext context, String timeOfDay) {
    switch (timeOfDay) {
      case 'morning':
        return context.tr('ad.time.morning');
      case 'noon':
        return context.tr('ad.time.noon');
      case 'afternoon':
        return context.tr('ad.time.afternoon');
      case 'night':
        return context.tr('ad.time.night');
      default:
        return context.tr('ad.time.morning');
    }
  }

  String _getFrequencyText(BuildContext context, Habit habit) {
    final String sep = context.isEnglish ? ', ' : '، ';
    switch (habit.frequencyType) {
      case 'daily':
        if (habit.dailyIntervalDays != null &&
            habit.dailyIntervalDays!.isNotEmpty) {
          return context.tr('ad.freq.everyNDays',
              {'n': habit.dailyIntervalDays!.first.toString()});
        }
        return context.tr('ad.freq.daily');
      case 'weekly':
        if (habit.weeklyDays != null && habit.weeklyDays!.isNotEmpty) {
          final days = habit.weeklyDays!
              .map((d) => context.tr('ad.wd.${d.clamp(0, 6)}'))
              .join(sep);
          return context.tr('ad.freq.everyWeek', {'days': days});
        }
        return context.tr('ad.freq.weekly');
      case 'monthly':
        if (habit.monthlyDays != null && habit.monthlyDays!.isNotEmpty) {
          return context.tr('ad.freq.monthDays',
              {'days': habit.monthlyDays!.join(sep)});
        }
        return context.tr('ad.freq.monthly');
      default:
        return context.tr('ad.freq.daily');
    }
  }

  bool _hasLevelSettings() {
    if (habit.questId != null) {
      final hasCustomFull = habit.fullDescription != null &&
          habit.fullDescription!.isNotEmpty &&
          habit.fullDescription != 'انجام کامل ماموریت';
      final hasCustomHalf = habit.halfDescription != null &&
          habit.halfDescription!.isNotEmpty &&
          habit.halfDescription != 'انجام نیمی از ماموریت';
      final hasCustomBasic = habit.basicDescription != null &&
          habit.basicDescription!.isNotEmpty &&
          habit.basicDescription != 'انجام حداقل ماموریت';
      final hasTargetValue =
          habit.targetValue != null && habit.targetValue!.isNotEmpty;
      return hasCustomFull || hasCustomHalf || hasCustomBasic || hasTargetValue;
    }

    final hasCustomFull = habit.fullDescription != null &&
        habit.fullDescription!.isNotEmpty &&
        habit.fullDescription != 'انجام کامل عادت';
    final hasCustomHalf = habit.halfDescription != null &&
        habit.halfDescription!.isNotEmpty &&
        habit.halfDescription != 'انجام نیمی از عادت';
    final hasCustomBasic = habit.basicDescription != null &&
        habit.basicDescription!.isNotEmpty &&
        habit.basicDescription != 'انجام حداقل عادت';
    final hasTargetValue =
        habit.targetValue != null && habit.targetValue!.isNotEmpty;
    return hasCustomFull || hasCustomHalf || hasCustomBasic || hasTargetValue;
  }

  String? _calculateLevelValue(String targetValue, CompletionLevel level) {
    if (targetValue.isEmpty) return null;
    final numberMatch = RegExp(r'(\d+)').firstMatch(targetValue);
    if (numberMatch == null) return targetValue;
    final int number = int.parse(numberMatch.group(1)!);
    final String unit = targetValue.replaceAll(RegExp(r'[\d\s]+'), '').trim();
    int result;
    String prefix;
    switch (level) {
      case CompletionLevel.full:
        result = number;
        prefix = '';
        break;
      case CompletionLevel.half:
        result = (number / 2).ceil();
        prefix = '~';
        break;
      case CompletionLevel.basic:
        result = (number / 4).ceil();
        prefix = '~';
        break;
    }
    if (unit.isNotEmpty) return '$prefix$result $unit';
    return '$prefix$result';
  }


  // ==================== رنگ‌ها و ابزارک‌های مشترک ====================

  static const Color _ink = Color(0xFF090909);

  /// متن روی کارت پاستلی: مشکی در روز، رنگ پررنگ همان تن در شب
  Color _onTone(ThemeProvider theme, ToneColors t) =>
      theme.isDarkMode ? t.fg : _ink;

  Widget _sec(ThemeProvider theme, Widget child,
      {Color? color,
      bool shadow = true,
      CrossAxisAlignment align = CrossAxisAlignment.stretch,
      EdgeInsets padding = const EdgeInsets.all(16)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: shadow ? theme.softShadow : null,
      ),
      child: Column(
        crossAxisAlignment: align,
        mainAxisSize: MainAxisSize.min,
        children: [child],
      ),
    );
  }

  Widget _sectionHeader(ThemeProvider theme, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.textColor),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: theme.textColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label,
      {IconData? icon,
      required Color bg,
      required Color fg,
      double height = 26}) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    final sections = <Widget>[
      _buildHeroCard(context, theme),
      if (habit.description.isEmpty) _buildNoDescriptionCard(context, theme),
      _buildInfoCard(context, theme),
      _buildStreakRow(context, theme),
      if (habit.subHabits.isNotEmpty) _buildSubHabitsCard(context, theme),
      if (_hasLevelSettings()) _buildLevelSettingsCard(context, theme),
      _buildChartSection(context, theme),
      _buildLevelHistorySection(context, theme),
      if (habit.reminders.isNotEmpty) _buildRemindersCard(context, theme),
    ];

    return BottomSafe(child: Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopBar(context, theme),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < sections.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      sections[i],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  Widget _circleButton(
      ThemeProvider theme, IconData icon, VoidCallback onTap, String tip) {
    return Semantics(
      button: true,
      label: tip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.cardColor,
            shape: BoxShape.circle,
            boxShadow: theme.softShadow,
          ),
          child: Icon(icon, size: 22, color: theme.textColor),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          _circleButton(theme, Icons.arrow_back_rounded,
              () => Navigator.pop(context), context.tr('ad.back')),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              habit.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: theme.textColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _circleButton(theme, Icons.refresh_rounded, () {
            (context as Element).reassemble();
          }, context.tr('ad.refresh')),
        ],
      ),
    );
  }

  // ==================== کارت اصلی ====================

  Widget _buildHeroCard(BuildContext context, ThemeProvider theme) {
    final bool isChallenge = habit.challengeId != null;
    final bool isQuest = habit.questId != null;

    Color bg;
    Color fg = _ink;
    if (isChallenge) {
      final t = theme.tone(Tone.butter);
      bg = t.bg;
      fg = _onTone(theme, t);
    } else if (isQuest) {
      final t = theme.tone(Tone.lilac);
      bg = t.bg;
      fg = _onTone(theme, t);
    } else if (habit.backgroundColor != 0) {
      bg = Color(habit.backgroundColor);
    } else {
      bg = theme.primaryColor;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: _ink,
                  shape: BoxShape.circle,
                ),
                child: Icon(_getIconData(habit.iconName), size: 30, color: bg),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: fg,
                      ),
                    ),
                    if (habit.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        habit.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: fg.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (isChallenge || isQuest) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (isChallenge)
                  _chip(context.tr('ad.chip.challenge'),
                      icon: Icons.emoji_events_rounded,
                      bg: Colors.white.withValues(alpha: 0.65),
                      fg: _ink),
                if (isQuest)
                  _chip(context.tr('ad.chip.quest'),
                      icon: Icons.flag_rounded,
                      bg: Colors.white.withValues(alpha: 0.65),
                      fg: _ink),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoDescriptionCard(BuildContext context, ThemeProvider theme) {
    return _sec(
      theme,
      Text(
        context.tr('ad.noDescription'),
        style: TextStyle(fontSize: 13, color: theme.textSecondaryColor),
      ),
    );
  }

  // ==================== اطلاعات ====================

  Widget _buildInfoCard(BuildContext context, ThemeProvider theme) {
    final rows = <Widget>[
      _buildDetailRow(theme, Icons.event_rounded, context.tr('ad.info.schedule'),
          _getFrequencyText(context, habit)),
      _buildDetailRow(theme, Icons.schedule_rounded, context.tr('ad.info.time'),
          _getTimeOfDayText(context, habit.timeOfDay)),
      _buildDetailRow(theme, Icons.star_rounded, context.tr('ad.info.xp'),
          context.tr('ad.info.xpValue', {'xp': habit.xpReward.toString()})),
      if (habit.targetValue != null && habit.targetValue!.isNotEmpty)
        _buildDetailRow(theme, Icons.adjust_rounded,
            context.tr('ad.info.target'), habit.targetValue!),
      if (habit.reminders.isNotEmpty)
        _buildDetailRow(
            theme,
            Icons.alarm_rounded,
            context.tr('ad.info.reminders'),
            context.tr('ad.info.remindersValue',
                {'n': habit.reminders.length.toString()})),
    ];
    return _sec(theme, Column(children: rows));
  }

  Widget _buildDetailRow(
      ThemeProvider theme, IconData icon, String label, String value) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: theme.textColor),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.textColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 14, color: theme.textSecondaryColor),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== استریک ====================

  Widget _buildStreakRow(BuildContext context, ThemeProvider theme) {
    Widget tile(Tone tone, IconData icon, Color iconColor, int value,
        String label) {
      final t = theme.tone(tone);
      final fg = _onTone(theme, t);
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.bg,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            children: [
              Icon(icon, size: 26, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value.toString(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: fg,
                      ),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final apricot = theme.tone(Tone.apricot);
    final butter = theme.tone(Tone.butter);
    return FutureBuilder<List<HabitCompletion>>(
      future: _completionsFuture,
      builder: (context, snap) {
        final st = snap.hasData
            ? HabitStreaks.compute(habit, snap.data!)
            : HabitStreaks(habit.currentStreak, habit.bestStreak);
        return Row(
      children: [
        tile(
          Tone.apricot,
          Icons.local_fire_department_rounded,
          theme.isDarkMode ? apricot.fg : const Color(0xFFE8890C),
          st.current,
          context.tr('ad.streak.current'),
        ),
        const SizedBox(width: 10),
        tile(
          Tone.butter,
          Icons.emoji_events_outlined,
          theme.isDarkMode ? butter.fg : _ink,
          st.best,
          context.tr('ad.streak.best'),
        ),
      ],
        );
      },
    );
  }

  // ==================== زیرعادت‌ها ====================

  Widget _buildSubHabitsCard(BuildContext context, ThemeProvider theme) {
    return _sec(
      theme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(theme, Icons.format_list_bulleted_rounded,
              context.tr('ad.subHabits')),
          const SizedBox(height: 12),
          ...habit.subHabits.map((sh) {
            final done = habit.completedSubHabits.contains(sh);
            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: done
                          ? theme.effectivePrimary
                          : theme.cardSecondaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: done
                        ? Icon(Icons.check_rounded,
                            size: 16, color: theme.onPrimaryColor)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      sh,
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            done ? theme.textSecondaryColor : theme.textColor,
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==================== سطوح انجام ====================

  Widget _buildLevelSettingsCard(BuildContext context, ThemeProvider theme) {
    final bool isQuest = habit.questId != null;
    final String defFull = isQuest ? 'انجام کامل ماموریت' : 'انجام کامل عادت';
    final String defHalf =
        isQuest ? 'انجام نیمی از ماموریت' : 'انجام نیمی از عادت';
    final String defBasic =
        isQuest ? 'انجام حداقل ماموریت' : 'انجام حداقل عادت';
    final String kind = isQuest ? 'quest' : 'habit';

    String descOf(String? value, String def, String key) {
      if (value == null || value.isEmpty || value == def) {
        return context.tr('ad.lvl.def.$key.$kind');
      }
      return value;
    }

    return _sec(
      theme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionHeader(theme, Icons.track_changes_rounded,
                    context.tr('ad.lvl.title')),
              ),
              if (habit.targetValue != null && habit.targetValue!.isNotEmpty)
                _chip(
                  context.tr('ad.lvl.goal', {'v': habit.targetValue!}),
                  bg: theme.primarySoft,
                  fg: theme.textColor,
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildLevelRow(
            context,
            theme,
            Tone.mint,
            CompletionLevel.full,
            descOf(habit.fullDescription, defFull, 'full'),
          ),
          const SizedBox(height: 12),
          _buildLevelRow(
            context,
            theme,
            Tone.apricot,
            CompletionLevel.half,
            descOf(habit.halfDescription, defHalf, 'half'),
          ),
          const SizedBox(height: 12),
          _buildLevelRow(
            context,
            theme,
            Tone.sky,
            CompletionLevel.basic,
            descOf(habit.basicDescription, defBasic, 'basic'),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelRow(BuildContext context, ThemeProvider theme, Tone tone,
      CompletionLevel level, String description) {
    final t = theme.tone(tone);
    final fg = _onTone(theme, t);
    final int multiplier = level.xpMultiplier;
    final int xpEarned = (habit.xpReward * multiplier / 100).round();
    String? levelValue;
    if (habit.targetValue != null && habit.targetValue!.isNotEmpty) {
      levelValue = _calculateLevelValue(habit.targetValue!, level);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(level.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                context.tr('ad.lvl.name.${level.name}'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
              const Spacer(),
              _chip(
                context.tr('ad.lvl.chip', {
                  'xp': xpEarned.toString(),
                  'pct': multiplier.toString(),
                }),
                bg: Colors.white.withValues(alpha: theme.isDarkMode ? 0.12 : 0.65),
                fg: fg,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(fontSize: 13, color: fg.withValues(alpha: 0.8)),
          ),
          if (levelValue != null) ...[
            const SizedBox(height: 6),
            Text(
              context.tr('ad.lvl.targetValue', {'v': levelValue}),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== نمودار ====================

  Widget _buildChartSection(BuildContext context, ThemeProvider theme) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _supabase.getHabitChartData(
        habitId: habit.id,
        userId: habit.userId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _sec(
            theme,
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 5,
                    color: theme.effectivePrimary,
                    backgroundColor: theme.cardSecondaryColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr('ad.chart.loading'),
                  style:
                      TextStyle(fontSize: 13, color: theme.textSecondaryColor),
                ),
              ],
            ),
            align: CrossAxisAlignment.center,
            padding: const EdgeInsets.all(20),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return _sec(
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
                  style:
                      TextStyle(fontSize: 12, color: theme.textSecondaryColor),
                ),
              ],
            ),
            align: CrossAxisAlignment.center,
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
          );
        }
        return HabitChartWidget(
          data: snapshot.data!,
          habitTitle: habit.title,
          targetValue: habit.targetValue,
        );
      },
    );
  }

  // ==================== تاریخچه ۳۰ روز ====================

  Widget _buildLevelHistorySection(BuildContext context, ThemeProvider theme) {
    return FutureBuilder<List<HabitCompletion>>(
      future: _supabase.getHabitCompletionsWithLevel(
        habitId: habit.id,
        userId: habit.userId,
        startDate: DateTime.now().subtract(const Duration(days: 30)),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final completions = snapshot.data!;

        String key(DateTime d) => '${d.year}-${d.month}-${d.day}';
        final byDay = <String, CompletionLevel>{
          for (final c in completions) key(c.date): c.level,
        };
        final today = DateTime.now();
        final days = List<DateTime>.generate(
          30,
          (i) => DateTime(today.year, today.month, today.day)
              .subtract(Duration(days: 29 - i)),
        );
        final Color emptyColor = theme.cardSecondaryColor;

        return _sec(
          theme,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionHeader(theme, Icons.bar_chart_rounded,
                  context.tr('ad.history.title')),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 10,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                children: days.map((d) {
                  final level = byDay[key(d)];
                  return Container(
                    decoration: BoxDecoration(
                      color: level?.color ?? emptyColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              _buildLegend(context, theme, emptyColor),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegend(BuildContext context, ThemeProvider theme, Color empty) {
    Widget item(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.textColor,
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        item(CompletionLevel.full.color,
            context.tr('ad.lvl.name.${CompletionLevel.full.name}')),
        item(CompletionLevel.half.color,
            context.tr('ad.lvl.name.${CompletionLevel.half.name}')),
        item(CompletionLevel.basic.color,
            context.tr('ad.lvl.name.${CompletionLevel.basic.name}')),
        item(empty, context.tr('ad.lvl.notDone')),
      ],
    );
  }

  // ==================== یادآورها ====================

  Widget _buildRemindersCard(BuildContext context, ThemeProvider theme) {
    return _sec(
      theme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(
              theme, Icons.alarm_rounded, context.tr('ad.reminders.title')),
          const SizedBox(height: 12),
          ...habit.reminders.map(
            (reminder) => ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: reminder.isEnabled
                            ? theme.primarySoft
                            : theme.cardSecondaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        reminder.isEnabled
                            ? Icons.notifications_none_rounded
                            : Icons.notifications_off_outlined,
                        size: 18,
                        color: theme.textColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      reminder.getTimeString(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: theme.textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
