import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../services/notification_service.dart';
import '../../widgets/big_button.dart';

/// Full-screen alert UI. Opened by tapping the alert notification or
/// pushed automatically when the app is in the foreground and an alert arrives.
/// Keeps vibrating until the user taps STOP.
class AlertScreen extends StatefulWidget {
  const AlertScreen({super.key});

  @override
  State<AlertScreen> createState() => _AlertScreenState();
}

class _AlertScreenState extends State<AlertScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  Timer? _vibrationTimer;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _startVibration();
  }

  Future<void> _startVibration() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (!hasVibrator) return;
    // Long pattern: 500ms on, 200ms off, repeat. Most alerts get dismissed quickly.
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      Vibration.vibrate(duration: 500);
    });
  }

  Future<void> _stop() async {
    _vibrationTimer?.cancel();
    Vibration.cancel();
    await NotificationService.instance.cancelAlert();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _vibrationTimer?.cancel();
    Vibration.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.danger,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              ScaleTransition(
                scale: Tween(begin: 0.9, end: 1.05).animate(
                  CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                ),
                child: const Icon(Icons.notifications_active,
                    size: 160, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text(
                AppStrings.alertTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                AppStrings.alertBody,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
              const Spacer(),
              BigButton(
                label: AppStrings.stopAlert,
                icon: Icons.stop_circle,
                backgroundColor: Colors.white,
                foregroundColor: AppColors.danger,
                onPressed: _stop,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
