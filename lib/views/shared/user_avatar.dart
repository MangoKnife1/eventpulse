import 'package:flutter/material.dart';

/// Profile picture. Shows a neutral silhouette when the user has no photo
/// (or while / if the photo fails to load), so new accounts never show a
/// stock photo of a stranger.
class UserAvatar extends StatelessWidget {
  final String url;
  final double radius;

  const UserAvatar({super.key, required this.url, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasPhoto = url.trim().isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
      // The silhouette is the child, so it stays visible until the photo loads.
      foregroundImage: hasPhoto ? NetworkImage(url) : null,
      onForegroundImageError: hasPhoto ? (_, __) {} : null,
      child: Icon(
        Icons.person,
        size: radius * 1.25,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      ),
    );
  }
}
