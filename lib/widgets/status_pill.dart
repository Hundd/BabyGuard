import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

/// Small colored pill showing a status string (Connected / Idle / Monitoring etc.).
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusPill({super.key, required this.label, required this.color, this.icon});

  factory StatusPill.success(String label) =>
      StatusPill(label: label, color: AppColors.success, icon: Icons.check_circle);

  factory StatusPill.warning(String label) =>
      StatusPill(label: label, color: AppColors.warning, icon: Icons.error_outline);

  factory StatusPill.idle(String label) =>
      StatusPill(label: label, color: AppColors.textSecondary, icon: Icons.circle_outlined);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16, color: color), const SizedBox(width: 6)],
          Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}
