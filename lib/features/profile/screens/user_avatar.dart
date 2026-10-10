// lib/features/profile/widgets/user_avatar.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '/providers/theme_provider.dart';
import 'package:provider/provider.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? name;
  final double size;
  final bool showBorder;
  final Color? borderColor;
  final VoidCallback? onTap;
  final bool showEditBadge;
  final VoidCallback? onEditTap;

  const UserAvatar({
    super.key,
    this.avatarUrl,
    this.name,
    this.size = 80,
    this.showBorder = false,
    this.borderColor,
    this.onTap,
    this.showEditBadge = false,
    this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    final initial = _getInitial(name);

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.primaryColor.withValues(alpha: 0.15),
        border: showBorder
            ? Border.all(
                color: borderColor ?? theme.primaryColor,
                width: 3,
              )
            : null,
      ),
      child: ClipOval(
        child: hasAvatar
            ? CachedNetworkImage(
                imageUrl: avatarUrl!,
                fit: BoxFit.cover,
                width: size,
                height: size,
                placeholder: (context, url) => _buildInitial(initial, theme),
                errorWidget: (context, url, error) =>
                    _buildInitial(initial, theme),
              )
            : _buildInitial(initial, theme),
      ),
    );

    if (onTap != null) {
      avatar = GestureDetector(onTap: onTap, child: avatar);
    }

    if (showEditBadge) {
      return Stack(
        children: [
          avatar,
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: onEditTap,
              child: Container(
                width: size * 0.32,
                height: size * 0.32,
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.surfaceColor,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: size * 0.16,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return avatar;
  }

  Widget _buildInitial(String initial, ThemeProvider theme) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
          color: theme.primaryColor,
        ),
      ),
    );
  }

  String _getInitial(String? name) {
    if (name == null || name.isEmpty) return '?';
    return name.trim().substring(0, 1).toUpperCase();
  }
}
