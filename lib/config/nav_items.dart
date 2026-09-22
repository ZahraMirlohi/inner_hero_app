// lib/config/nav_items.dart

import 'package:flutter/material.dart';
import '../widgets/custom_bottom_nav_bar.dart';

class NavItems {
  static const List<BottomNavItem> items = [
    BottomNavItem(
      icon: Icons.emoji_events_outlined,
      label: 'میدان',
    ),
    BottomNavItem(
      icon: Icons.chat_outlined,
      label: 'گپ',
    ),
    BottomNavItem(
      icon: Icons.explore_outlined,
      label: 'اکسپلور',
    ),
    BottomNavItem(
      icon: Icons.person_outline,
      label: 'پروفایل',
    ),
  ];
}
