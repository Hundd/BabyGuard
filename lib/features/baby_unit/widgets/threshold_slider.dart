import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class ThresholdSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const ThresholdSlider({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Trigger above',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                Text(
                  '${value.toStringAsFixed(0)} dB',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ],
            ),
            Slider(
              min: 50,
              max: 90,
              divisions: 40,
              value: value.clamp(50, 90),
              label: '${value.toStringAsFixed(0)} dB',
              onChanged: onChanged,
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Quiet', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                Text('Loud', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
