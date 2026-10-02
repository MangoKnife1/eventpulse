import 'package:flutter/material.dart';

/// Event banner with a loading placeholder and a clean fallback, so lists of
/// many remote (Cloudinary) images never flash errors or jump around.
class NetworkBanner extends StatelessWidget {
  final String url;
  final double height;

  const NetworkBanner({super.key, required this.url, required this.height});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final fg = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    Widget placeholder({bool loading = false}) => Container(
          height: height,
          width: double.infinity,
          color: bg,
          child: Center(
            child: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                : Icon(Icons.image_outlined, size: 36, color: fg),
          ),
        );

    if (url.trim().isEmpty) return placeholder();

    return Image.network(
      url,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      cacheWidth: 1000, // decode at a sensible size: smoother scrolling with many images
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder(loading: true),
      errorBuilder: (_, __, ___) => placeholder(),
    );
  }
}
