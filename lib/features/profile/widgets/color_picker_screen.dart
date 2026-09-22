// lib/features/profile/widgets/color_picker_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/providers/theme_provider.dart';

class ColorPickerScreen extends StatefulWidget {
  const ColorPickerScreen({super.key});

  @override
  State<ColorPickerScreen> createState() => _ColorPickerScreenState();
}

class _ColorPickerScreenState extends State<ColorPickerScreen> {
  Color _selectedColor = const Color(0xFFB0CC5D);
  bool _isLoading = false;
  double _customHue = 0.0;
  double _customSaturation = 0.5;
  double _customLightness = 0.5;

  final List<Color> _presetColors = [
    const Color(0xFFB0CC5D),
    const Color(0xFF4A90E2),
    const Color(0xFFFF6B6B),
    const Color(0xFFFFA500),
    const Color(0xFF9B59B6),
    const Color(0xFF2ECC71),
    const Color(0xFF1ABC9C),
    const Color(0xFFE74C3C),
    const Color(0xFFF39C12),
    const Color(0xFF3498DB),
    const Color(0xFFE67E22),
    const Color(0xFF7C3AED),
    const Color(0xFF10B981),
    const Color(0xFFF472B6),
    const Color(0xFF8B5CF6),
    const Color(0xFF06B6D4),
  ];

  @override
  void initState() {
    super.initState();
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    setState(() {
      _selectedColor = themeProvider.primaryColor;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'انتخاب رنگ اپلیکیشن',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A2E),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveColor,
            child: const Text(
              'ذخیره',
              style: TextStyle(color: Color(0xFF2563EB)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildColorPreview(themeProvider),
            const SizedBox(height: 24),
            const Text(
              'رنگ‌های پیشنهادی',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _presetColors.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.black, width: 3)
                          : Border.all(color: Colors.grey.shade300, width: 1),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            color: color.computeLuminance() > 0.5
                                ? Colors.black
                                : Colors.white,
                            size: 20,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text(
              'رنگ سفارشی',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('رنگ:', style: TextStyle(fontSize: 14)),
                Slider(
                  value: _customHue,
                  onChanged: (value) {
                    setState(() {
                      _customHue = value;
                      _selectedColor = HSLColor.fromAHSL(
                        1.0,
                        _customHue * 360,
                        _customSaturation,
                        _customLightness,
                      ).toColor();
                    });
                  },
                  min: 0,
                  max: 1,
                  activeColor: _selectedColor,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('اشباع:', style: TextStyle(fontSize: 14)),
                          Slider(
                            value: _customSaturation,
                            onChanged: (value) {
                              setState(() {
                                _customSaturation = value;
                                _selectedColor = HSLColor.fromAHSL(
                                  1.0,
                                  _customHue * 360,
                                  _customSaturation,
                                  _customLightness,
                                ).toColor();
                              });
                            },
                            min: 0,
                            max: 1,
                            activeColor: _selectedColor,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('روشنایی:',
                              style: TextStyle(fontSize: 14)),
                          Slider(
                            value: _customLightness,
                            onChanged: (value) {
                              setState(() {
                                _customLightness = value;
                                _selectedColor = HSLColor.fromAHSL(
                                  1.0,
                                  _customHue * 360,
                                  _customSaturation,
                                  _customLightness,
                                ).toColor();
                              });
                            },
                            min: 0,
                            max: 1,
                            activeColor: _selectedColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _resetToDefault,
                icon: const Icon(Icons.restore, color: Colors.orange),
                label: const Text(
                  'بازگشت به رنگ پیش‌فرض',
                  style: TextStyle(color: Colors.orange),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.orange),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPreview(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _selectedColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _selectedColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'A',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _selectedColor.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'رنگ انتخابی',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedColor.value.toRadixString(16).toUpperCase(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _selectedColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _selectedColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _selectedColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.fitness_center,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'نمونه عادت',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1A2E),
                        ),
                      ),
                      Text(
                        'با رنگ جدید',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _selectedColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveColor() async {
    setState(() => _isLoading = true);
    try {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      await themeProvider.setPrimaryColor(_selectedColor);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ رنگ با موفقیت تغییر کرد!'),
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
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetToDefault() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('بازگشت به رنگ پیش‌فرض'),
        content: const Text('آیا از بازگشت به رنگ سبز پیش‌فرض مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('بله، بازگشت',
                style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final themeProvider =
            Provider.of<ThemeProvider>(context, listen: false);
        await themeProvider.resetToDefault();
        setState(() {
          _selectedColor = const Color(0xFFB0CC5D);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ رنگ به پیش‌فرض بازگشت!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          if (mounted) Navigator.pop(context, true);
        }
      } catch (e) {
        // ignore
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }
}
