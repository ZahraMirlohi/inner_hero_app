// lib/features/profile/widgets/character_customization.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/character_model.dart';
import '../models/hero_class_model.dart';
import '/providers/theme_provider.dart';

class CharacterCustomization extends StatefulWidget {
  final Character character;
  final Function(Character) onCharacterUpdated;

  const CharacterCustomization({
    super.key,
    required this.character,
    required this.onCharacterUpdated,
  });

  @override
  State<CharacterCustomization> createState() => _CharacterCustomizationState();
}

class _CharacterCustomizationState extends State<CharacterCustomization> {
  late Character _tempCharacter;
  late HeroClass _heroClass;

  @override
  void initState() {
    super.initState();
    _tempCharacter = widget.character;
    _heroClass = HeroClass.getClass(_tempCharacter.heroClass);
  }

  // ✅ کپی کردن کاراکتر با تغییرات
  Character _copyCharacter({
    String? heroClass,
    String? outfit,
    String? accessory,
    String? catchphrase,
  }) {
    return Character(
      id: _tempCharacter.id,
      userId: _tempCharacter.userId,
      name: _tempCharacter.name,
      heroClass: heroClass ?? _tempCharacter.heroClass,
      outfit: outfit ?? _tempCharacter.outfit,
      accessory: accessory ?? _tempCharacter.accessory,
      background: _tempCharacter.background,
      catchphrase: catchphrase ?? _tempCharacter.catchphrase,
      bgMusic: _tempCharacter.bgMusic,
      currentAnimation: _tempCharacter.currentAnimation,
      level: _tempCharacter.level,
      xp: _tempCharacter.xp,
      totalXp: _tempCharacter.totalXp,
      streak: _tempCharacter.streak,
      bestStreak: _tempCharacter.bestStreak,
      badges: _tempCharacter.badges,
      createdAt: _tempCharacter.createdAt,
      lastActive: _tempCharacter.lastActive,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final primaryColor = theme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'شخصی‌سازی قهرمان',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildClassSelector(theme),
          const SizedBox(height: 16),
          _buildOutfitSelector(theme),
          const SizedBox(height: 16),
          _buildAccessorySelector(theme),
          const SizedBox(height: 16),
          _buildCatchphraseInput(theme),
          const SizedBox(height: 16),
          _buildSaveButton(primaryColor),
        ],
      ),
    );
  }

  Widget _buildClassSelector(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'کلاس قهرمان',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.textColor,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: HeroClass.allClasses.length,
            itemBuilder: (context, index) {
              final heroClass = HeroClass.allClasses[index];
              final isSelected = _tempCharacter.heroClass == heroClass.id;
              final color = _parseColor(heroClass.primaryColor);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _tempCharacter = Character(
                      id: _tempCharacter.id,
                      userId: _tempCharacter.userId,
                      name: _tempCharacter.name,
                      heroClass: heroClass.id,
                      outfit: heroClass.defaultOutfit,
                      accessory: heroClass.defaultAccessory,
                      background: _tempCharacter.background,
                      catchphrase: _tempCharacter.catchphrase,
                      bgMusic: _tempCharacter.bgMusic,
                      currentAnimation: _tempCharacter.currentAnimation,
                      level: _tempCharacter.level,
                      xp: _tempCharacter.xp,
                      totalXp: _tempCharacter.totalXp,
                      streak: _tempCharacter.streak,
                      bestStreak: _tempCharacter.bestStreak,
                      badges: _tempCharacter.badges,
                      createdAt: _tempCharacter.createdAt,
                      lastActive: _tempCharacter.lastActive,
                    );
                    _heroClass = heroClass;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color
                        : (theme.isDarkMode
                            ? const Color(0xFF2A2A2A)
                            : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? color : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        heroClass.icon,
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        heroClass.name,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : theme.textSecondaryColor,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
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
    );
  }

  Widget _buildOutfitSelector(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'لباس',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.textColor,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _heroClass.outfits.map((outfit) {
            final isSelected = _tempCharacter.outfit == outfit;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _tempCharacter = _copyCharacter(outfit: outfit);
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _parseColor(_heroClass.primaryColor)
                      : (theme.isDarkMode
                          ? const Color(0xFF2A2A2A)
                          : Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? _parseColor(_heroClass.primaryColor)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Text(
                  _getOutfitDisplayName(outfit),
                  style: TextStyle(
                    color: isSelected ? Colors.white : theme.textSecondaryColor,
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAccessorySelector(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'اکسسوری',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.textColor,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            'none',
            _heroClass.defaultAccessory,
            'glasses',
            'medal_gold',
            'crown',
          ].map((accessory) {
            final isSelected = _tempCharacter.accessory == accessory;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _tempCharacter = _copyCharacter(accessory: accessory);
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _parseColor(_heroClass.primaryColor)
                      : (theme.isDarkMode
                          ? const Color(0xFF2A2A2A)
                          : Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? _parseColor(_heroClass.primaryColor)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Text(
                  _getAccessoryDisplayName(accessory),
                  style: TextStyle(
                    color: isSelected ? Colors.white : theme.textSecondaryColor,
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCatchphraseInput(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'تکه‌کلام',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.textColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: _tempCharacter.catchphrase)
            ..selection = TextSelection.fromPosition(
              TextPosition(offset: _tempCharacter.catchphrase.length),
            ),
          style: TextStyle(color: theme.textColor),
          onChanged: (value) {
            setState(() {
              _tempCharacter = _copyCharacter(catchphrase: value);
            });
          },
          decoration: InputDecoration(
            hintText: 'تکه‌کلام قهرمان خود را وارد کنید...',
            hintStyle: TextStyle(color: theme.textSecondaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: theme.isDarkMode
                ? const Color(0xFF2A2A2A)
                : Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          maxLength: 50,
        ),
      ],
    );
  }

  Widget _buildSaveButton(Color primaryColor) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          widget.onCharacterUpdated(_tempCharacter);
          Navigator.pop(context);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'ذخیره تغییرات',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  String _getOutfitDisplayName(String outfit) {
    switch (outfit) {
      case 'armor_blue':
        return 'زره آبی';
      case 'armor_red':
        return 'زره قرمز';
      case 'armor_gold':
        return 'زره طلایی';
      case 'armor_dark':
        return 'زره تاریک';
      case 'lab_coat':
        return 'کت آزمایشگاه';
      case 'scrubs_blue':
        return 'لباس آبی';
      case 'scrubs_green':
        return 'لباس سبز';
      case 'white_coat':
        return 'کت سفید';
      case 'sport_blue':
        return 'ورزشی آبی';
      case 'sport_red':
        return 'ورزشی قرمز';
      case 'sport_black':
        return 'ورزشی مشکی';
      case 'sport_white':
        return 'ورزشی سفید';
      case 'lab_white':
        return 'لباس سفید';
      case 'lab_blue':
        return 'لباس آبی';
      case 'lab_green':
        return 'لباس سبز';
      case 'professor':
        return 'استادی';
      case 'uniform_blue':
        return 'یونیفرم آبی';
      case 'uniform_red':
        return 'یونیفرم قرمز';
      case 'uniform_gold':
        return 'یونیفرم طلایی';
      case 'uniform_dark':
        return 'یونیفرم تاریک';
      case 'robe_purple':
        return 'ردای بنفش';
      case 'robe_blue':
        return 'ردای آبی';
      case 'robe_red':
        return 'ردای قرمز';
      case 'robe_dark':
        return 'ردای تاریک';
      default:
        return outfit;
    }
  }

  String _getAccessoryDisplayName(String accessory) {
    switch (accessory) {
      case 'none':
        return 'هیچ';
      case 'sword':
        return '🗡️ شمشیر';
      case 'stethoscope':
        return '🩺 گوشی پزشکی';
      case 'medal':
        return '🏅 مدال';
      case 'glasses':
        return '👓 عینک';
      case 'medal_gold':
        return '🥇 مدال طلا';
      case 'crown':
        return '👑 تاج';
      case 'staff':
        return '🪄 عصا';
      default:
        return accessory;
    }
  }

  Color _parseColor(String colorStr) {
    try {
      if (colorStr.startsWith('#')) {
        return Color(int.parse('FF${colorStr.substring(1)}', radix: 16));
      }
      return const Color(0xFF2563EB);
    } catch (e) {
      return const Color(0xFF2563EB);
    }
  }
}
