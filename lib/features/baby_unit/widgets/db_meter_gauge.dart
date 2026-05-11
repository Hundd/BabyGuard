import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../services/noise_meter_service.dart';

/// Animated horizontal gauge showing current dB plus a threshold marker.
class DbMeterGauge extends StatelessWidget {
  final double currentDb;
  final double thresholdDb;

  const DbMeterGauge({
    super.key,
    required this.currentDb,
    required this.thresholdDb,
  });

  Color _colorForDb(double db) {
    if (db < 60) return AppColors.dbLow;
    if (db < 80) return AppColors.dbMid;
    return AppColors.dbHigh;
  }

  @override
  Widget build(BuildContext context) {
    final fraction = NoiseMeterService.normalize(currentDb);
    final threshFraction = NoiseMeterService.normalize(thresholdDb);
    final isOver = currentDb >= thresholdDb;
    final dbColor = _colorForDb(currentDb);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Current sound level',
                    style: TextStyle(color: AppColors.textSecondary)),
                Text(
                  '${currentDb.toStringAsFixed(0)} dB',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: dbColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, c) {
              final width = c.maxWidth;
              return Stack(
                children: [
                  Container(
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 18,
                    width: width * fraction,
                    decoration: BoxDecoration(
                      color: dbColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Positioned(
                    left: width * threshFraction - 1,
                    top: -4,
                    child: Container(
                      width: 3,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                isOver ? 'Above threshold!' : 'Below threshold',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isOver ? AppColors.danger : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
