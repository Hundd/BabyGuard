import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../providers/pairing_provider.dart';
import '../../services/fcm_service.dart';
import '../../services/firebase_service.dart';
import '../../services/pairing_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/status_pill.dart';

/// Baby Unit pairing screen: generates a code, shows it + QR,
/// waits for the Parent to join.
class BabyPairingScreen extends ConsumerStatefulWidget {
  const BabyPairingScreen({super.key});

  @override
  ConsumerState<BabyPairingScreen> createState() => _BabyPairingScreenState();
}

class _BabyPairingScreenState extends ConsumerState<BabyPairingScreen> {
  bool _creating = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final pairing = ref.read(pairingProvider);
      if (pairing.pairId != null) {
        setState(() => _creating = false);
        return;
      }

      final uid = await FirebaseService.instance.ensureSignedIn();
      final token = await FcmService.instance.requestAndGetToken() ?? '';
      final code = await PairingService.instance.createPair(
        babyUid: uid,
        babyToken: token,
      );
      await ref.read(pairingProvider.notifier).setPairId(code);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pairing = ref.watch(pairingProvider);
    final pairDoc = ref.watch(pairDocProvider);

    // Once parent joins (status == "paired"), navigate to the monitoring screen.
    ref.listen<AsyncValue<DocumentSnapshot<Map<String, dynamic>>?>>(pairDocProvider,
        (prev, next) {
      final data = next.value?.data();
      if (data != null && data['status'] == 'paired' && mounted) {
        Navigator.of(context).pushReplacementNamed('/baby/monitor');
      }
    });

    return AppScaffold(
      title: AppStrings.pairingTitle,
      body: _creating
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _bootstrap)
              : _PairedBody(
                  code: pairing.pairId!,
                  isParentConnected: pairDoc.value?.data()?['status'] == 'paired',
                ),
    );
  }
}

class _PairedBody extends StatelessWidget {
  final String code;
  final bool isParentConnected;

  const _PairedBody({required this.code, required this.isParentConnected});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: isParentConnected
              ? StatusPill.success('Parent connected')
              : StatusPill.warning(AppStrings.waitingForParent),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text('Scan this on the Parent device',
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accent, width: 2),
                  ),
                  child: QrImageView(
                    data: code,
                    version: QrVersions.auto,
                    size: 220,
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Or enter this code:',
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                SelectableText(
                  code,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
