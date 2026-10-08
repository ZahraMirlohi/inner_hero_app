// lib/widgets/custom_animated_nav_bar.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import '/providers/theme_provider.dart';

class CustomAnimatedNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<IconData> icons;
  final List<String> labels;
  final bool showNotch;

  const CustomAnimatedNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.icons,
    required this.labels,
    this.showNotch = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final primaryColor = theme.primaryColor;

    // ✅ رنگ پس‌زمینه:
    // - در تم شب: سفید
    // - در تم روز: مشکی
    final Color navBarColor =
        theme.isDarkMode ? Colors.white : const Color(0xFF090909);

    // ✅ رنگ آیکون غیرفعال:
    // - در تم شب: خاکستری (خوانا روی سفید)
    // - در تم روز: خاکستری تیره (خوانا روی مشکی)
    final Color inactiveColor =
        theme.isDarkMode ? Colors.grey.shade400 : const Color(0xFF6A6A6A);

    // ✅ رنگ آیکون فعال (همیشه primaryColor)
    final Color activeColor = primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AnimatedBottomNavigationBar.builder(
        itemCount: icons.length,
        activeIndex: currentIndex,
        gapLocation: showNotch ? GapLocation.center : GapLocation.none,
        notchSmoothness: NotchSmoothness.verySmoothEdge,
        leftCornerRadius: 30,
        rightCornerRadius: 30,
        // ✅ تم‌محور
        backgroundColor: navBarColor,
        elevation: 0,
        shadow: BoxShadow(
          color: Colors.black.withValues(
            alpha: theme.isDarkMode ? 0.25 : 0.26,
          ),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
        splashRadius: 0,
        onTap: onTap,
        tabBuilder: (int index, bool isActive) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icons[index],
                  size: 24,
                  // ✅ تم‌محور
                  color: isActive ? activeColor : inactiveColor,
                ),
                const SizedBox(height: 4),
                Text(
                  labels[index],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    // ✅ تم‌محور
                    color: isActive ? activeColor : inactiveColor,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
