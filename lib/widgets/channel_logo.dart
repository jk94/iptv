import 'package:flutter/material.dart';

/// Rounded channel logo with a TV-icon fallback while loading or on error.
class ChannelLogo extends StatelessWidget {
  final String? logoUrl;
  final double size;

  const ChannelLogo({super.key, required this.logoUrl, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.live_tv_rounded,
        size: size * 0.5,
        color: Theme.of(context).colorScheme.primary,
      ),
    );

    if (logoUrl == null) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        logoUrl!,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}
