// lib/features/profile/screens/personality_screen.dart

import '/widgets/bottom_safe.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/core/app_palette.dart';
import '/l10n/app_strings.dart';
import '/services/buddy_matcher_service.dart';
import '/providers/sync_provider.dart';
import '/providers/theme_provider.dart';
import '../models/user_personality.dart';

class PersonalityScreen extends StatefulWidget {
  const PersonalityScreen({super.key});

  @override
  State<PersonalityScreen> createState() => _PersonalityScreenState();
}

class _PersonalityScreenState extends State<PersonalityScreen> {
  final BuddyMatcherService _matcherService = BuddyMatcherService();

  // ==================== کنترل‌کننده‌ها ====================
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _interestsController = TextEditingController();
  final TextEditingController _goalsController = TextEditingController();

  // ==================== وضعیت‌ها ====================
  bool _isLoading = true;
  bool _isSaving = false;
  String? _userId;
  UserPersonality? _personality;

  // ==================== انتخاب‌ها ====================
  Gender _selectedGender = Gender.other;
  List<PersonalityType> _selectedPersonalities = [];
  MBTIType? _selectedMBTI;
  List<String> _interests = [];
  List<String> _goals = [];
  int _experienceLevel = 1;
  List<String> _preferredTimes = [];
  bool _lookingForBuddy = true;

  // ==================== گزینه‌های پیش‌فرض ====================
  final List<Map<PersonalityType, String>> _personalityOptions = [
    {PersonalityType.disciplined: 'منظم و برنامه‌ریز'},
    {PersonalityType.creative: 'خلاق و ایده‌پرداز'},
    {PersonalityType.social: 'اجتماعی و فعال'},
    {PersonalityType.calm: 'آرام و صبور'},
    {PersonalityType.ambitious: 'جاه‌طلب و هدف‌گرا'},
    {PersonalityType.spiritual: 'معنوی و درون‌گرا'},
    {PersonalityType.athletic: 'ورزشکار و پرانرژی'},
    {PersonalityType.intellectual: 'روشنفکر و مطالعه‌گر'},
    {PersonalityType.adventurous: 'ماجراجو و هیجان‌خواه'},
    {PersonalityType.nurturing: 'مراقب و حامی'},
  ];

  final List<String> _timeOptions = [
    'صبح زود (۵-۸)',
    'صبح (۸-۱۲)',
    'ظهر (۱۲-۱۵)',
    'عصر (۱۵-۱۹)',
    'شب (۱۹-۲۳)',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await _matcherService.getCurrentUser();
    if (user != null) {
      setState(() {
        _userId = user.id;
      });

      final personality = await _matcherService.getUserPersonality(user.id);
      if (personality != null) {
        setState(() {
          _personality = personality;
          _selectedGender = personality.gender;
          _selectedPersonalities = personality.personalityTypes;
          _selectedMBTI = personality.mbtiType;
          _interests = personality.interests;
          _goals = personality.goals;
          _experienceLevel = personality.experienceLevel;
          _preferredTimes = personality.preferredTimes;
          _lookingForBuddy = personality.isLookingForBuddy;
          _bioController.text = personality.bio ?? '';
        });
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  void _addInterest() {
    final text = _interestsController.text.trim();
    if (text.isNotEmpty && !_interests.contains(text)) {
      setState(() {
        _interests.add(text);
        _interestsController.clear();
      });
    }
  }

  void _removeInterest(String interest) {
    setState(() {
      _interests.remove(interest);
    });
  }

  void _addGoal() {
    final text = _goalsController.text.trim();
    if (text.isNotEmpty && !_goals.contains(text)) {
      setState(() {
        _goals.add(text);
        _goalsController.clear();
      });
    }
  }

  void _removeGoal(String goal) {
    setState(() {
      _goals.remove(goal);
    });
  }

  void _togglePersonality(PersonalityType type) {
    setState(() {
      if (_selectedPersonalities.contains(type)) {
        _selectedPersonalities.remove(type);
      } else {
        _selectedPersonalities.add(type);
      }
    });
  }

  void _toggleTime(String time) {
    setState(() {
      if (_preferredTimes.contains(time)) {
        _preferredTimes.remove(time);
      } else {
        _preferredTimes.add(time);
      }
    });
  }

  Future<void> _savePersonality() async {
    if (_userId == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final personality = UserPersonality(
        userId: _userId!,
        gender: _selectedGender,
        personalityTypes: _selectedPersonalities,
        mbtiType: _selectedMBTI,
        interests: _interests,
        habits: [],
        goals: _goals,
        bio: _bioController.text.isNotEmpty ? _bioController.text : null,
        preferredTimes: _preferredTimes,
        experienceLevel: _experienceLevel,
        isLookingForBuddy: _lookingForBuddy,
        updatedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await _matcherService.saveUserPersonality(personality);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('pm.pe.saved')),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('pm.pe.error', {'n': e.toString()})),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ==================== ابزارهای ظاهری ====================

  Color _ink(ThemeProvider t) =>
      t.isDarkMode ? t.cardSecondaryColor : const Color(0xFF090909);

  Color _onAccent(Color accent) =>
      accent.computeLuminance() > 0.5 ? const Color(0xFF090909) : Colors.white;

  Widget _heading(ThemeProvider t, String title, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: t.textColor,
            ),
          ),
          if (hint != null)
            Text(
              hint,
              style: TextStyle(fontSize: 12, color: t.textSecondaryColor),
            ),
        ],
      ),
    );
  }

  Widget _chip(
    ThemeProvider t,
    String label,
    bool selected,
    VoidCallback onTap, {
    Color? bg,
    Color? fg,
    bool removable = false,
  }) {
    final Color background = bg ?? (selected ? _ink(t) : t.cardColor);
    final Color foreground =
        fg ?? (selected ? Colors.white : t.textColor);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: foreground,
                fontWeight: (selected || bg != null)
                    ? (bg != null ? FontWeight.w600 : FontWeight.w700)
                    : FontWeight.w500,
              ),
            ),
            if (removable) ...[
              const SizedBox(width: 6),
              Icon(Icons.close_rounded, size: 16, color: foreground),
            ],
          ],
        ),
      ),
    );
  }

  Widget _wrap(List<Widget> children, {double top = 0}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, top, 20, 0),
      child: Wrap(spacing: 8, runSpacing: 8, children: children),
    );
  }

  Widget _backButton(ThemeProvider t) {
    return GestureDetector(
      onTap: () => Navigator.maybePop(context),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: t.cardColor,
          shape: BoxShape.circle,
          boxShadow: t.softShadow,
        ),
        child: Icon(Icons.arrow_forward_rounded, size: 22, color: t.textColor),
      ),
    );
  }

  // ==================== ساخت صفحه ====================

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final accent = theme.effectivePrimary;

    return BottomSafe(child: Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: accent))
            : SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTopBar(theme, accent),
                    _buildGenderSelector(theme, accent),
                    _buildMBTISection(theme, accent),
                    _buildPersonalitySelector(theme, accent),
                    _buildInterestsSection(theme, accent),
                    _buildGoalsSection(theme, accent),
                    _buildBioSection(theme, accent),
                    _buildTimePreference(theme, accent),
                    _buildExperienceLevel(theme, accent),
                    _buildLookingForBuddy(theme, accent),
                    _buildSaveButton(theme, accent),
                  ],
                ),
              ),
      ),
    ));
  }

  Widget _buildTopBar(ThemeProvider theme, Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          _backButton(theme),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.tr('pm.pe.title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: theme.textColor,
              ),
            ),
          ),
          GestureDetector(
            onTap: _isSaving ? null : _savePersonality,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _ink(theme),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                context.tr('pm.pe.save'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== جنسیت ====================

  Widget _buildGenderSelector(ThemeProvider theme, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(theme, context.tr('pm.pe.gender')),
        _wrap([
          _buildGenderChip(Gender.male, context.tr('pm.pe.male'), theme),
          _buildGenderChip(Gender.female, context.tr('pm.pe.female'), theme),
          _buildGenderChip(Gender.other, context.tr('pm.pe.other'), theme),
        ]),
      ],
    );
  }

  Widget _buildGenderChip(Gender gender, String label, ThemeProvider theme) {
    return _chip(theme, label, _selectedGender == gender, () {
      setState(() {
        _selectedGender = gender;
      });
    });
  }

  // ==================== انتخاب MBTI ====================

  Widget _buildMBTISection(ThemeProvider theme, Color accent) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: _ink(theme),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('pm.pe.mbti'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFBFC5B3),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedMBTI?.name ?? '----',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        color: accent,
                      ),
                    ),
                    if (_selectedMBTI != null)
                      Text(
                        _selectedMBTI!.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFBFC5B3),
                        ),
                      ),
                  ],
                ),
              ),
              if (_selectedMBTI != null)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMBTI = null;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              Icon(Icons.auto_awesome_rounded, size: 40, color: accent),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showMBTITestDialog(theme, accent),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      context.tr('pm.pe.take_test'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _onAccent(accent),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showMBTIPickerDialog(theme, accent),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      context.tr('pm.pe.pick_type'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMBTITestDialog(ThemeProvider theme, Color accent) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('pm.pe.test_title'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('pm.pe.test_body'),
                style: TextStyle(fontSize: 14, color: theme.textColor),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.cardSecondaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'www.16personalities.com/fa',
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('pm.pe.test_after'),
                style: TextStyle(fontSize: 12, color: theme.textSecondaryColor),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.cardSecondaryColor,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          context.tr('pm.pe.close'),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: theme.textColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _showMBTIPickerDialog(theme, accent);
                      },
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _ink(theme),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          context.tr('pm.pe.enter_type'),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMBTIPickerDialog(ThemeProvider theme, Color accent) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      builder: (sheetContext) => SafeArea(top: false, child: Builder(builder: (_) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            height: MediaQuery.of(sheetContext).size.height * 0.65,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 18),
                Text(
                  context.tr('pm.pe.pick_title'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('pm.pe.pick_sub'),
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.2,
                    ),
                    itemCount: MBTIType.values.length,
                    itemBuilder: (_, index) {
                      final type = MBTIType.values[index];
                      final isSelected = _selectedMBTI == type;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedMBTI = type;
                          });
                          Navigator.pop(sheetContext);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _ink(theme)
                                : theme.cardSecondaryColor,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                type.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                  color:
                                      isSelected ? accent : theme.textColor,
                                ),
                              ),
                              Text(
                                type.displayName.split(' (').first,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected
                                      ? Colors.white
                                      : theme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      })),
    );
  }

  // ==================== نوع شخصیت ====================

  Widget _buildPersonalitySelector(ThemeProvider theme, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(
          theme,
          context.tr('pm.pe.ptype'),
          hint: context.tr('pm.pe.ptype_max'),
        ),
        _wrap(_personalityOptions.map((item) {
          final type = item.keys.first;
          final label = context.tr('pm.pe.t.${type.name}');
          final isSelected = _selectedPersonalities.contains(type);
          return _chip(theme, label, isSelected, () {
            if (_selectedPersonalities.contains(type)) {
              _togglePersonality(type);
            } else if (_selectedPersonalities.length < 3) {
              _togglePersonality(type);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.tr('pm.pe.max3')),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          });
        }).toList()),
      ],
    );
  }

  // ==================== ورودی چیپ‌ها ====================

  Widget _buildTagInput(
    ThemeProvider theme,
    Color accent,
    TextEditingController controller,
    String hint,
    VoidCallback onAdd,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsetsDirectional.fromSTEB(18, 6, 8, 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: theme.softShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(fontSize: 14, color: theme.textColor),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: theme.textSecondaryColor,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onSubmitted: (_) => onAdd(),
            ),
          ),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              child: Icon(Icons.add_rounded, size: 20, color: _onAccent(accent)),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _tagChips(
    ThemeProvider theme,
    List<String> items,
    List<Tone> tones,
    void Function(String) onRemove,
  ) {
    return [
      for (int i = 0; i < items.length; i++)
        _chip(
          theme,
          items[i],
          false,
          () => onRemove(items[i]),
          bg: theme.tone(tones[i % tones.length]).bg,
          fg: theme.textColor,
          removable: true,
        ),
    ];
  }

  // ==================== علاقه‌مندی‌ها ====================

  Widget _buildInterestsSection(ThemeProvider theme, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(theme, context.tr('pm.pe.interests')),
        _buildTagInput(theme, accent, _interestsController,
            context.tr('pm.pe.interests_hint'), _addInterest),
        if (_interests.isNotEmpty)
          _wrap(
            _tagChips(theme, _interests,
                const [Tone.sky, Tone.lilac, Tone.peach], _removeInterest),
            top: 10,
          ),
      ],
    );
  }

  // ==================== اهداف ====================

  Widget _buildGoalsSection(ThemeProvider theme, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(theme, context.tr('pm.pe.goals')),
        _buildTagInput(theme, accent, _goalsController,
            context.tr('pm.pe.goals_hint'), _addGoal),
        if (_goals.isNotEmpty)
          _wrap(
            _tagChips(
                theme, _goals, const [Tone.butter, Tone.mint], _removeGoal),
            top: 10,
          ),
      ],
    );
  }

  // ==================== بیوگرافی ====================

  Widget _buildBioSection(ThemeProvider theme, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(theme, context.tr('pm.pe.about')),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          constraints: const BoxConstraints(minHeight: 84),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: theme.softShadow,
          ),
          child: TextField(
            controller: _bioController,
            style: TextStyle(fontSize: 14, color: theme.textColor),
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: context.tr('pm.pe.about_hint'),
              hintStyle: TextStyle(
                fontSize: 14,
                color: theme.textSecondaryColor,
              ),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  // ==================== زمان‌های ترجیحی ====================

  Widget _buildTimePreference(ThemeProvider theme, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(theme, context.tr('pm.pe.times')),
        _wrap([
          for (int i = 0; i < _timeOptions.length; i++)
            _chip(
              theme,
              context.tr('pm.pe.time.$i'),
              _preferredTimes.contains(_timeOptions[i]),
              () => _toggleTime(_timeOptions[i]),
            ),
        ]),
      ],
    );
  }

  // ==================== سطح تجربه ====================

  Widget _buildExperienceLevel(ThemeProvider theme, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(
          theme,
          context.tr('pm.pe.level'),
          hint: _getExperienceLabel(_experienceLevel),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(26),
            boxShadow: theme.softShadow,
          ),
          child: Row(
            children: [
              for (int lv = 1; lv <= 5; lv++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        _experienceLevel = lv;
                      });
                    },
                    child: Column(
                      children: [
                        SizedBox(
                          height: 28,
                          child: Center(
                            child: Container(
                              width: lv == _experienceLevel ? 28 : 20,
                              height: lv == _experienceLevel ? 28 : 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: lv == _experienceLevel
                                    ? accent
                                    : (lv < _experienceLevel
                                        ? _ink(theme)
                                        : theme.cardSecondaryColor),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _getExperienceLabel(lv),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: lv == _experienceLevel
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: lv == _experienceLevel
                                ? theme.textColor
                                : theme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _getExperienceLabel(int level) {
    final l = (level >= 1 && level <= 5) ? level : 1;
    return context.tr('pm.pe.lv.$l');
  }

  // ==================== به دنبال هم‌مسیر ====================

  Widget _buildLookingForBuddy(ThemeProvider theme, Color accent) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _lookingForBuddy = !_lookingForBuddy;
        });
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 22, 20, 0),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: theme.primarySoft,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('pm.pe.buddy'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: theme.textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.tr('pm.pe.buddy_sub'),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 50,
              height: 30,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: _lookingForBuddy
                    ? _ink(theme)
                    : theme.cardSecondaryColor,
                borderRadius: BorderRadius.circular(15),
              ),
              alignment: _lookingForBuddy
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _lookingForBuddy ? accent : theme.textSecondaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== دکمه ذخیره ====================

  Widget _buildSaveButton(ThemeProvider theme, Color accent) {
    return GestureDetector(
      onTap: _isSaving ? null : _savePersonality,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _ink(theme),
          borderRadius: BorderRadius.circular(28),
        ),
        child: _isSaving
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: accent),
              )
            : Text(
                context.tr('pm.pe.save_all'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
      ),
    );
  }
}
