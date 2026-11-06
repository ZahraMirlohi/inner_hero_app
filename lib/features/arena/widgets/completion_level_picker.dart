// lib/features/arena/widgets/completion_level_picker.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/habit_completion.dart';
import '/providers/theme_provider.dart';
import '/core/app_palette.dart';
import '/l10n/app_strings.dart';

class CompletionLevelPicker extends StatefulWidget {
  final String habitTitle;
  final int habitXpReward;
  final Function(CompletionLevel) onSelected;

  final String? fullDescription;
  final String? halfDescription;
  final String? basicDescription;
  final String? targetValue;
  final String? habitId;
  final bool? isQuest;
  final bool? isChallenge;

  const CompletionLevelPicker({
    super.key,
    required this.habitTitle,
    required this.habitXpReward,
    required this.onSelected,
    this.fullDescription,
    this.halfDescription,
    this.basicDescription,
    this.targetValue,
    this.habitId,
    this.isQuest,
    this.isChallenge,
  });

  @override
  State<CompletionLevelPicker> createState() => _CompletionLevelPickerState();
}

class _CompletionLevelPickerState extends State<CompletionLevelPicker> {
  static const Color _ink = Color(0xFF090909);
  CompletionLevel? _selectedLevel;

  Tone _toneOf(CompletionLevel level) {
    switch (level) {
      case CompletionLevel.full:
        return Tone.mint;
      case CompletionLevel.half:
        return Tone.apricot;
      case CompletionLevel.basic:
        return Tone.sky;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    final bool isQuest = widget.isQuest ?? false;
    final bool isChallenge = widget.isChallenge ?? false;
    final String kind = isQuest ? 'quest' : 'habit';

    final String defaultFull = isQuest ? 'انجام کامل ماموریت' : 'انجام کامل عادت';
    final String defaultHalf =
        isQuest ? 'انجام نیمی از ماموریت' : 'انجام نیمی از عادت';
    final String defaultBasic =
        isQuest ? 'انجام حداقل ماموریت' : 'انجام حداقل عادت';

    String descOf(String? value, String def, String key) {
      if (value == null || value == def) {
        return context.tr('ad.lvl.def.$key.$kind');
      }
      return value;
    }

    final fullDesc = descOf(widget.fullDescription, defaultFull, 'full');
    final halfDesc = descOf(widget.halfDescription, defaultHalf, 'half');
    final basicDesc = descOf(widget.basicDescription, defaultBasic, 'basic');

    final bool isCustomFull =
        widget.fullDescription != null && widget.fullDescription != defaultFull;
    final bool isCustomHalf =
        widget.halfDescription != null && widget.halfDescription != defaultHalf;
    final bool isCustomBasic = widget.basicDescription != null &&
        widget.basicDescription != defaultBasic;

    final bool hasTarget =
        widget.targetValue != null && widget.targetValue!.isNotEmpty;
    final Color onTone =
        theme.isDarkMode ? theme.textColor : _ink;

    final bool canConfirm = _selectedLevel != null;
    final Color btnBg = canConfirm
        ? (theme.isDarkMode ? theme.effectivePrimary : _ink)
        : theme.cardSecondaryColor;
    final Color btnFg = canConfirm
        ? (theme.isDarkMode ? theme.onPrimaryColor : Colors.white)
        : theme.textSecondaryColor;

    return Dialog(
      alignment: Alignment.bottomCenter,
      insetPadding: EdgeInsets.zero,
      backgroundColor: theme.cardColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // دستگیره
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: theme.cardSecondaryColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                context.tr('ad.pick.title'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 14),
              // عنوان عادت + نشان ماموریت/چالش
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      widget.habitTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.textSecondaryColor,
                      ),
                    ),
                  ),
                  if (isQuest || isChallenge) ...[
                    const SizedBox(width: 8),
                    Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: theme
                            .tone(isQuest ? Tone.lilac : Tone.butter)
                            .bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isQuest
                                ? Icons.track_changes_rounded
                                : Icons.emoji_events_rounded,
                            size: 14,
                            color: onTone,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.tr(
                                isQuest ? 'ad.chip.quest' : 'ad.chip.challenge'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: onTone,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              if (hasTarget) ...[
                const SizedBox(height: 14),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: theme.primarySoft,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.track_changes_rounded,
                            size: 16, color: theme.textColor),
                        const SizedBox(width: 6),
                        Text(
                          context.tr('ad.pick.goal', {'v': widget.targetValue!}),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: theme.textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _buildLevelOption(CompletionLevel.full, fullDesc,
                  isCustom: isCustomFull, theme: theme, onTone: onTone),
              const SizedBox(height: 10),
              _buildLevelOption(CompletionLevel.half, halfDesc,
                  isCustom: isCustomHalf, theme: theme, onTone: onTone),
              const SizedBox(height: 10),
              _buildLevelOption(CompletionLevel.basic, basicDesc,
                  isCustom: isCustomBasic, theme: theme, onTone: onTone),
              const SizedBox(height: 14),
              // دکمه تایید
              GestureDetector(
                onTap: canConfirm
                    ? () => widget.onSelected(_selectedLevel!)
                    : null,
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: btnBg,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Text(
                    canConfirm
                        ? context.tr(
                            'ad.pick.confirm', {'e': _selectedLevel!.emoji})
                        : context.tr('ad.pick.choose'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: btnFg,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // انصراف
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(context),
                child: SizedBox(
                  height: 36,
                  child: Center(
                    child: Text(
                      context.tr('ad.pick.cancel'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.textSecondaryColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelOption(
    CompletionLevel level,
    String description, {
    bool isCustom = false,
    required ThemeProvider theme,
    required Color onTone,
  }) {
    final isSelected = _selectedLevel == level;
    final t = theme.tone(_toneOf(level));
    final apricot = theme.tone(Tone.apricot);
    final lilac = theme.tone(Tone.lilac);
    final xpEarned = (widget.habitXpReward * level.xpMultiplier / 100).round();

    String? levelValue;
    if (widget.targetValue != null && widget.targetValue!.isNotEmpty) {
      levelValue = _calculateLevelValue(widget.targetValue!, level);
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedLevel = level),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? t.bg : theme.backgroundColor,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: isSelected ? level.color : theme.cardSecondaryColor,
                shape: BoxShape.circle,
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(level.emoji, style: const TextStyle(fontSize: 20)),
                      Text(
                        context.tr('ad.lvl.name.${level.name}'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: theme.textColor,
                        ),
                      ),
                      if (isCustom)
                        Container(
                          height: 22,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: lilac.bg,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Text(
                            context.tr('ad.pick.custom'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: theme.isDarkMode ? lilac.fg : _ink,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.7,
                      color: theme.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (levelValue != null)
                        Container(
                          height: 26,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: theme.cardColor.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.flag_rounded,
                                  size: 14, color: theme.textColor),
                              const SizedBox(width: 4),
                              Text(
                                context.tr(
                                    'ad.pick.need', {'v': levelValue}),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        height: 26,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: apricot.bg,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Text(
                          '+$xpEarned XP',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: theme.isDarkMode ? apricot.fg : _ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _calculateLevelValue(String targetValue, CompletionLevel level) {
    if (targetValue.isEmpty) return null;

    final numberMatch = RegExp(r'(\d+)').firstMatch(targetValue);
    if (numberMatch == null) {
      return targetValue;
    }

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

    if (unit.isNotEmpty) {
      return '$prefix$result $unit';
    }
    return '$prefix$result';
  }
}
