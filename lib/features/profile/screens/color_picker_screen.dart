// lib/features/profile/screens/color_picker_screen.dart
// صفحهٔ انتخاب رنگ اپلیکیشن — مطابق artboard «ColorPicker».

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/l10n/app_strings.dart';
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

  // شش رنگ اول همان رنگ‌های artboard هستند؛ بقیه برای حفظ گزینه‌های قبلی می‌مانند.
  final List<Color> _presetColors = const [
    Color(0xFFB0CC5D),
    Color(0xFF7FD1B0),
    Color(0xFFF4A261),
    Color(0xFFA78BFA),
    Color(0xFFF28BA8),
    Color(0xFF6CB4EE),
    Color(0xFF4A90E2),
    Color(0xFFFF6B6B),
    Color(0xFFFFA500),
    Color(0xFF9B59B6),
    Color(0xFF2ECC71),
    Color(0xFF1ABC9C),
    Color(0xFFE74C3C),
    Color(0xFFF39C12),
    Color(0xFF7C3AED),
    Color(0xFF06B6D4),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      final hsl = HSLColor.fromColor(themeProvider.primaryColor);
      setState(() {
        _selectedColor = themeProvider.primaryColor;
        _customHue = hsl.hue / 360;
        _customSaturation = hsl.saturation;
        _customLightness = hsl.lightness;
      });
    });
  }

  void _applyHsl() {
    _selectedColor = HSLColor.fromAHSL(
      1.0,
      _customHue * 360,
      _customSaturation,
      _customLightness,
    ).toColor();
  }

  Color _onColor(Color c) =>
      c.computeLuminance() > 0.5 ? const Color(0xFF090909) : Colors.white;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final black = theme.isDarkMode ? theme.cardSecondaryColor : const Color(0xFF090909);

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTopBar(theme),
                  const SizedBox(height: 16),
                  _buildPreview(theme, black),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final color in _presetColors)
                        _buildPreset(theme, color),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSliders(theme),
                ],
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: Row(
                children: [
                  Expanded(
                    flex: 10,
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _resetToDefault,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.cardColor,
                          foregroundColor: theme.textSecondaryColor,
                          elevation: 0,
                          shape: const StadiumBorder(),
                        ),
                        child: Text(context.tr('pm.cp.default'),
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 14,
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveColor,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: black,
                          foregroundColor: _selectedColor,
                          elevation: 0,
                          shape: const StadiumBorder(),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: _selectedColor))
                            : Text(context.tr('pm.cp.save'),
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
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

  Widget _buildTopBar(ThemeProvider theme) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.cardColor,
              shape: BoxShape.circle,
              boxShadow: theme.softShadow,
            ),
            child: Icon(Icons.arrow_back_rounded,
                size: 22, color: theme.textColor),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('pm.cp.title'),
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.textColor)),
              Text(context.tr('pm.cp.sub'),
                  style: TextStyle(
                      fontSize: 12, color: theme.textSecondaryColor)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreset(ThemeProvider theme, Color color) {
    final isSelected = _selectedColor.toARGB32() == color.toARGB32();
    return GestureDetector(
      onTap: () {
        final hsl = HSLColor.fromColor(color);
        setState(() {
          _selectedColor = color;
          _customHue = hsl.hue / 360;
          _customSaturation = hsl.saturation;
          _customLightness = hsl.lightness;
        });
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: theme.textColor, width: 3)
              : null,
        ),
        child: isSelected
            ? Icon(Icons.check_rounded, color: _onColor(color), size: 24)
            : null,
      ),
    );
  }

  Widget _buildPreview(ThemeProvider theme, Color black) {
    final soft = Color.lerp(_selectedColor, Colors.white, 0.7)!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: theme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('pm.cp.preview'),
              style:
                  TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _selectedColor,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.menu_book_rounded,
                      size: 22, color: Color(0xFF090909)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('pm.cp.sample_title'),
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF090909))),
                      Text(context.tr('pm.cp.sample_sub'),
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF2B3010))),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration:
                      BoxDecoration(color: black, shape: BoxShape.circle),
                  child: Icon(Icons.check_rounded,
                      size: 22, color: _selectedColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: black, borderRadius: BorderRadius.circular(22)),
                child: Text(context.tr('pm.cp.main_button'),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _selectedColor)),
              ),
              const SizedBox(width: 10),
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: soft, borderRadius: BorderRadius.circular(22)),
                child: Text(context.tr('pm.cp.tag'),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF090909))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSliders(ThemeProvider theme) {
    final hueColors = const [
      Color(0xFFFF3B30),
      Color(0xFFFFCC00),
      Color(0xFF34C759),
      Color(0xFF32ADE6),
      Color(0xFF5856D6),
      Color(0xFFFF2D55),
      Color(0xFFFF3B30),
    ];
    final hsl = HSLColor.fromAHSL(1, _customHue * 360, 1, _customLightness);
    final satColors = [
      HSLColor.fromAHSL(1, _customHue * 360, 0, _customLightness).toColor(),
      hsl.toColor(),
    ];
    final lightColors = [
      HSLColor.fromAHSL(1, _customHue * 360, _customSaturation, 0.08)
          .toColor(),
      HSLColor.fromAHSL(1, _customHue * 360, _customSaturation, 0.5)
          .toColor(),
      HSLColor.fromAHSL(1, _customHue * 360, _customSaturation, 0.95)
          .toColor(),
    ];

    Widget block(String label, double v, List<Color> cs,
        ValueChanged<double> onChanged) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.textColor)),
          const SizedBox(height: 8),
          _GradientSlider(value: v, colors: cs, onChanged: onChanged),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: theme.softShadow,
      ),
      child: Column(
        children: [
          block(context.tr('pm.cp.hue'), _customHue, hueColors, (v) {
            setState(() {
              _customHue = v;
              _applyHsl();
            });
          }),
          const SizedBox(height: 18),
          block(context.tr('pm.cp.sat'), _customSaturation, satColors, (v) {
            setState(() {
              _customSaturation = v;
              _applyHsl();
            });
          }),
          const SizedBox(height: 18),
          block(context.tr('pm.cp.light'), _customLightness, lightColors, (v) {
            setState(() {
              _customLightness = v;
              _applyHsl();
            });
          }),
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
          SnackBar(
            content: Text(context.tr('pm.cp.saved')),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('pm.cp.error', {'n': e.toString()})),
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
    final theme = Provider.of<ThemeProvider>(context, listen: false);

    final confirm = await showDialog<bool>(
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
              Text(ctx.tr('pm.cp.reset_title'),
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.textColor)),
              const SizedBox(height: 8),
              Text(ctx.tr('pm.cp.reset_body'),
                  style: TextStyle(
                      fontSize: 14, color: theme.textSecondaryColor)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.cardSecondaryColor,
                          foregroundColor: theme.textColor,
                          elevation: 0,
                          shape: const StadiumBorder(),
                        ),
                        child: Text(ctx.tr('common.cancel')),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF090909),
                          foregroundColor: theme.primaryColor,
                          elevation: 0,
                          shape: const StadiumBorder(),
                        ),
                        child: Text(ctx.tr('pm.cp.reset_ok'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800)),
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

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final themeProvider =
            Provider.of<ThemeProvider>(context, listen: false);
        await themeProvider.resetToDefault();
        if (!mounted) return;
        setState(() {
          _selectedColor = const Color(0xFFB0CC5D);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('pm.cp.reset_done')),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true);
      } catch (_) {
        // ignore
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }
}

/// اسلایدر با ریل گرادیانی و دستگیرهٔ سفید گرد (مثل artboard).
class _GradientSlider extends StatelessWidget {
  final double value;
  final List<Color> colors;
  final ValueChanged<double> onChanged;

  const _GradientSlider({
    required this.value,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        void update(double dx) => onChanged((dx / w).clamp(0.0, 1.0));
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => update(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => update(d.localPosition.dx),
          child: SizedBox(
            height: 28,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 7,
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      gradient: LinearGradient(colors: colors),
                    ),
                  ),
                ),
                Positioned(
                  left: (value.clamp(0.0, 1.0) * w) - 14,
                  top: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF090909).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
