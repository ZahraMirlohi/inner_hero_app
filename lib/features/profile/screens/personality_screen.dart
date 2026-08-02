// lib/features/profile/screens/personality_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/services/buddy_matcher_service.dart';
import '/providers/sync_provider.dart';
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
  MBTIType? _selectedMBTI; // ✅ اضافه کردن این خط
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
          _selectedMBTI = personality.mbtiType; // ✅ اضافه شده
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

  // ==================== افزودن/حذف ====================

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

  // ==================== ذخیره ====================

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
        mbtiType: _selectedMBTI, // ✅ اضافه شده
        interests: _interests,
        habits: [], // از عادت‌های کاربر پر می‌شود
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
          const SnackBar(
            content: Text('اطلاعات با موفقیت ذخیره شد ✅'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: ${e.toString()}'),
            backgroundColor: Colors.red,
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

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('شخصیت من'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A2E),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _savePersonality,
            child: const Text(
              'ذخیره',
              style: TextStyle(color: Color(0xFF4A90E2)),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4A90E2)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGenderSelector(),
                  const SizedBox(height: 20),
                  _buildMBTISection(), // ✅ اضافه کردن بخش MBTI
                  const SizedBox(height: 20),
                  _buildPersonalitySelector(),
                  const SizedBox(height: 20),
                  _buildInterestsSection(),
                  const SizedBox(height: 20),
                  _buildGoalsSection(),
                  const SizedBox(height: 20),
                  _buildBioSection(),
                  const SizedBox(height: 20),
                  _buildTimePreference(),
                  const SizedBox(height: 20),
                  _buildExperienceLevel(),
                  const SizedBox(height: 20),
                  _buildLookingForBuddy(),
                  const SizedBox(height: 32),
                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  // ==================== ویجت‌ها ====================

  Widget _buildGenderSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'جنسیت',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildGenderChip(Gender.male, 'مرد'),
              const SizedBox(width: 12),
              _buildGenderChip(Gender.female, 'زن'),
              const SizedBox(width: 12),
              _buildGenderChip(Gender.other, 'سایر'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenderChip(Gender gender, String label) {
    final isSelected = _selectedGender == gender;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedGender = gender;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4A90E2) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: isSelected ? null : Border.all(color: Colors.grey.shade300),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== انتخاب MBTI ====================

  Widget _buildMBTISection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '🧠 تایپ شخصیتی MBTI',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _showMBTITestDialog,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(
                    0xFF4A90E2,
                  ).withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'انجام تست',
                  style: TextStyle(
                    color: Color(0xFF4A90E2),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'شناخت تایپ شخصیتی به پیدا کردن هم‌مسیرهای مناسب کمک می‌کند',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),

          // نمایش MBTI فعلی
          if (_selectedMBTI != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF4A90E2).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    _selectedMBTI!.emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedMBTI!.displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        Text(
                          _selectedMBTI!.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedMBTI = null;
                      });
                    },
                    icon: const Icon(Icons.close, size: 18),
                    color: Colors.grey.shade500,
                  ),
                ],
              ),
            ),
          ] else ...[
            // دکمه انتخاب MBTI
            GestureDetector(
              onTap: _showMBTIPickerDialog,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      'انتخاب تایپ شخصیتی',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showMBTITestDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('🧠 تست شخصیت MBTI'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'برای انجام تست شخصیت MBTI روی لینک زیر کلیک کنید:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: GestureDetector(
                onTap: () {
                  // باز کردن لینک در مرورگر
                  // می‌توانید از url_launcher استفاده کنید
                },
                child: const Text(
                  '🔗 www.16personalities.com/fa',
                  style: TextStyle(
                    color: Color(0xFF4A90E2),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'پس از انجام تست، تایپ شخصیتی خود را در اپلیکیشن وارد کنید.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showMBTIPickerDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('ورود تایپ شخصیتی'),
          ),
        ],
      ),
    );
  }

  void _showMBTIPickerDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(20),
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'انتخاب تایپ شخصیتی MBTI',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'تایپ شخصیتی خود را از لیست زیر انتخاب کنید',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.5,
                        ),
                    itemCount: MBTIType.values.length,
                    itemBuilder: (context, index) {
                      final type = MBTIType.values[index];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedMBTI = type;
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _selectedMBTI == type
                                ? const Color(0xFF4A90E2).withValues(alpha: 0.1)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedMBTI == type
                                  ? const Color(0xFF4A90E2)
                                  : Colors.grey.shade200,
                              width: _selectedMBTI == type ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                type.emoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                type.displayName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _selectedMBTI == type
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: _selectedMBTI == type
                                      ? const Color(0xFF4A90E2)
                                      : const Color(0xFF1A1A2E),
                                ),
                                textAlign: TextAlign.center,
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
      },
    );
  }

  Widget _buildPersonalitySelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'نوع شخصیت',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'حداکثر ۳ مورد را انتخاب کنید',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _personalityOptions.map((item) {
              final type = item.keys.first;
              final label = item[type]!;
              final isSelected = _selectedPersonalities.contains(type);

              return GestureDetector(
                onTap: () {
                  if (_selectedPersonalities.contains(type)) {
                    _togglePersonality(type);
                  } else if (_selectedPersonalities.length < 3) {
                    _togglePersonality(type);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('حداکثر ۳ شخصیت می‌توانید انتخاب کنید'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF4A90E2)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? null
                        : Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'علاقه‌مندی‌ها',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _interestsController,
                  decoration: InputDecoration(
                    hintText: 'مثال: ورزش، مطالعه، ...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _addInterest(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _addInterest,
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          if (_interests.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _interests.map((interest) {
                return Chip(
                  label: Text(interest),
                  onDeleted: () => _removeInterest(interest),
                  deleteIcon: const Icon(Icons.close, size: 16),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGoalsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'اهداف',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _goalsController,
                  decoration: InputDecoration(
                    hintText: 'مثال: کاهش وزن، مطالعه روزانه، ...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _addGoal(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _addGoal,
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          if (_goals.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _goals.map((goal) {
                return Chip(
                  label: Text(goal),
                  onDeleted: () => _removeGoal(goal),
                  deleteIcon: const Icon(Icons.close, size: 16),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBioSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'درباره من',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bioController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'کمی درباره خودتان بنویسید...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePreference() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'زمان‌های ترجیحی',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _timeOptions.map((time) {
              final isSelected = _preferredTimes.contains(time);
              return GestureDetector(
                onTap: () => _toggleTime(time),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF4A90E2)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? null
                        : Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    time,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceLevel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'سطح تجربه',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _experienceLevel.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: const Color(0xFF4A90E2),
                  onChanged: (value) {
                    setState(() {
                      _experienceLevel = value.toInt();
                    });
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getExperienceLabel(_experienceLevel),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A90E2),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getExperienceLabel(int level) {
    switch (level) {
      case 1:
        return 'مبتدی';
      case 2:
        return 'نوآموز';
      case 3:
        return 'متوسط';
      case 4:
        return 'پیشرفته';
      case 5:
        return 'حرفه‌ای';
      default:
        return 'مبتدی';
    }
  }

  Widget _buildLookingForBuddy() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'به دنبال هم‌مسیر',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              Text(
                'در لیست پیشنهادات نمایش داده شوید',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          Switch(
            value: _lookingForBuddy,
            onChanged: (value) {
              setState(() {
                _lookingForBuddy = value;
              });
            },
            activeColor: const Color(0xFF4A90E2),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _savePersonality,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4A90E2),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'ذخیره اطلاعات',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
