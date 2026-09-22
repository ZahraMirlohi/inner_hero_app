// lib/widgets/custom_animated_nav_bar.dart

import 'package:flutter/material.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AnimatedBottomNavigationBar.builder(
        itemCount: icons.length,
        activeIndex: currentIndex,
        gapLocation: showNotch ? GapLocation.center : GapLocation.none,
        notchSmoothness: NotchSmoothness.verySmoothEdge,
        leftCornerRadius: 30,
        rightCornerRadius: 30,
        backgroundColor: const Color(0xFF090909),
        elevation: 0,
        shadow: const BoxShadow(
          color: Colors.black26,
          blurRadius: 20,
          offset: Offset(0, 10),
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
                  color: isActive
                      ? const Color(0xFFB0CC5D)
                      : const Color(0xFF6A6A6A),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[index],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive
                        ? const Color(0xFFB0CC5D)
                        : const Color(0xFF6A6A6A),
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
