import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/pair_code.dart';
import '../../core/utils/permissions.dart';
import '../../providers/pairing_provider.dart';
import '../../services/fcm_service.dart';
import '../../services/firebase_service.dart';
import '../../services/pairing_service.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/big_button.dart';

class ParentPairingScreen extends ConsumerStatefulWidget {
  const ParentPairingScreen({super.key});

  @override
  ConsumerState<ParentPairingScreen> createState() => _ParentPairingScreenState();
}

class _ParentPairingScreenState extends ConsumerState<ParentPairingScreen> {
  final _codeController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (!PairCode.isValid(code)) {
      setState(() => _error = 'Enter a valid 6-character code');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final uid = await FirebaseService.instance.ensureSignedIn();
      final token = await FcmService.instance.requestAndGetToken() ?? '';
      final ok = await PairingService.instance.joinPair(
        code: code,
        parentUid: uid,
        parentToken: token,
      );
      if (!ok) {
        setState(() => _error = 'No baby unit found with that code.');
        return;
      }
      await ref.read(pairingProvider.notifier).setPairId(code);
      if (mounted) AppRouter.goReplaceAll(context, AppRouter.parentMonitor);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: AppStrings.pairingTitle,
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const Material(
              color: Colors.transparent,
              child: TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.qr_code_scanner), text: AppStrings.scanQr),
                  Tab(icon: Icon(Icons.dialpad), text: AppStrings.enterCode),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                children: [
                  _QrScanTab(busy: _busy, onCode: _join),
                  _CodeEntryTab(
                    controller: _codeController,
                    busy: _busy,
                    error: _error,
                    onSubmit: () => _join(_codeController.text),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrScanTab extends StatefulWidget {
  final bool busy;
  final ValueChanged<String> onCode;

  const _QrScanTab({required this.busy, required this.onCode});

  @override
  State<_QrScanTab> createState() => _QrScanTabState();
}

class _QrScanTabState extends State<_QrScanTab> {
  final MobileScannerController _controller = MobileScannerController();
  bool _consumed = false;

  @override
  void initState() {
    super.initState();
    PermissionHelper.requestCamera();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_consumed || widget.busy) return;
              for (final b in capture.barcodes) {
                final raw = b.rawValue;
                if (raw != null && PairCode.isValid(raw)) {
                  _consumed = true;
                  widget.onCode(raw);
                  break;
                }
              }
            },
          ),
          if (widget.busy)
            Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
    );
  }
}

class _CodeEntryTab extends StatelessWidget {
  final TextEditingController controller;
  final bool busy;
  final String? error;
  final VoidCallback onSubmit;

  const _CodeEntryTab({
    required this.controller,
    required this.busy,
    required this.error,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Icon(Icons.dialpad, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              textAlign: TextAlign.center,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              style: const TextStyle(
                fontSize: 32,
                letterSpacing: 8,
                fontWeight: FontWeight.w800,
              ),
              decoration: const InputDecoration(
                hintText: 'ABCDEF',
                counterText: '',
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 24),
            BigButton(
              label: 'Connect',
              icon: Icons.link,
              onPressed: busy ? null : onSubmit,
              loading: busy,
            ),
          ],
        ),
      ),
    );
  }
}
