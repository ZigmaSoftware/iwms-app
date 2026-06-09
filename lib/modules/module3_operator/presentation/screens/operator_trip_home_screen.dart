import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:iwms_citizen_app/data/models/operator_trip_models.dart';
import 'package:iwms_citizen_app/data/repositories/operator_trip_repository.dart';
import 'package:iwms_citizen_app/modules/module3_operator/logic/operator_trip_bloc.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_trip_history_screen.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/theme/operator_theme.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/widgets/bin_detail_sheet.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/widgets/operator_cp_card.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/widgets/operator_trip_header_card.dart';

/// Operator trip home screen — main screen for the daily trip flow.
///
/// Shows the assigned panchayat, waste-type chip, vehicle, and a list of CPs
/// the operator must visit. The floating QR FAB opens the universal scanner
/// which validates against today's trip and, on success, presents the
/// [BinDetailSheet] for weight entry + submission.
class OperatorTripHomeScreen extends StatelessWidget {
  const OperatorTripHomeScreen({super.key});

  static const routeName = '/operator/trip';

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: OperatorTheme.background,
      body: SafeArea(child: OperatorTripBody(showScanFab: true)),
    );
  }
}

/// Embeddable trip body: shows today's panchayat + CP list with loading,
/// empty and error states. Set [showScanFab] to render the scanner CTA at
/// the bottom-right (used when this widget is the *only* content on screen);
/// set it to `false` when the host screen already owns its own FAB.
class OperatorTripBody extends StatelessWidget {
  final bool showScanFab;
  final EdgeInsets listPadding;

  const OperatorTripBody({
    super.key,
    this.showScanFab = false,
    this.listPadding = const EdgeInsets.fromLTRB(20, 16, 20, 96),
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<OperatorTripBloc>(
      create: (_) => GetIt.instance<OperatorTripBloc>()
        ..add(const OperatorTripLoadRequested()),
      child: _OperatorTripBodyView(
        showScanFab: showScanFab,
        listPadding: listPadding,
      ),
    );
  }
}

class _OperatorTripBodyView extends StatelessWidget {
  final bool showScanFab;
  final EdgeInsets listPadding;

  const _OperatorTripBodyView({
    required this.showScanFab,
    required this.listPadding,
  });

  @override
  Widget build(BuildContext context) {
    final content = BlocBuilder<OperatorTripBloc, OperatorTripState>(
      builder: (context, state) {
        switch (state.status) {
          case OperatorTripStatus.loading:
          case OperatorTripStatus.initial:
            return const Center(child: CircularProgressIndicator());
          case OperatorTripStatus.failure:
            return _ErrorView(
              message: state.errorMessage ?? 'Something went wrong.',
              onRetry: () => context
                  .read<OperatorTripBloc>()
                  .add(const OperatorTripRefreshRequested()),
            );
          case OperatorTripStatus.empty:
            return _EmptyView(
              onRefresh: () => context
                  .read<OperatorTripBloc>()
                  .add(const OperatorTripRefreshRequested()),
            );
          case OperatorTripStatus.ready:
            return _LoadedView(
              trip: state.trip!,
              listPadding: listPadding,
            );
        }
      },
    );

    if (!showScanFab) return content;

    return Stack(
      children: [
        content,
        Positioned(
          right: 16,
          bottom: 16,
          child: BlocBuilder<OperatorTripBloc, OperatorTripState>(
            builder: (context, state) {
              final isReady = state.status == OperatorTripStatus.ready;
              return FloatingActionButton.extended(
                heroTag: 'operator-trip-fab',
                backgroundColor:
                    isReady ? OperatorTheme.accent : OperatorTheme.mutedText,
                foregroundColor: Colors.white,
                onPressed: !isReady ? null : () => openScanner(context),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scan Bin QR'),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Pushes the [OperatorTripScanScreen] and re-emits a refresh into the
/// surrounding [OperatorTripBloc] when the scan finalizes.
///
/// Exposed so a host widget (e.g. the operator Home screen) can wire its own
/// FAB to this same flow without duplicating logic.
Future<void> openScanner(BuildContext context) async {
  final bloc = context.read<OperatorTripBloc>();
  final result = await Navigator.of(context).push<BinScanSubmitResult?>(
    MaterialPageRoute(
      builder: (_) => const OperatorTripScanScreen(),
    ),
  );
  if (result != null) {
    bloc.add(OperatorTripBinScanFinalized(result));
  }
}

/// Validates the given [binQr] against today's trip and opens the
/// [BinDetailSheet] for weight entry, skipping the camera entirely.
///
/// Used when the operator taps a CP card on Home — we already know the bin
/// id from the trip payload, so there is nothing to scan.
Future<void> openBinSheetForBinQr(BuildContext context, String binQr) async {
  final bloc = context.read<OperatorTripBloc>();
  final repo = GetIt.instance<OperatorTripRepository>();
  final messenger = ScaffoldMessenger.maybeOf(context);

  // Quick optimistic loading indicator
  final dialogFuture = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  BinScanValidateResult? validation;
  String? errorText;
  try {
    validation = await repo.validateBinQr(binQr);
  } on OperatorTripException catch (e) {
    errorText = _friendlyErrorFor(e);
  } catch (e) {
    errorText = 'Could not load bin: $e';
  }

  // Close the loading dialog (if still up)
  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
  }
  // The pushed dialog completes when popped above; await guards us from races.
  await dialogFuture.catchError((_) {});

  if (errorText != null) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text(errorText),
        backgroundColor: OperatorTheme.danger,
      ),
    );
    return;
  }
  if (validation == null || !context.mounted) return;

  final result = await showModalBottomSheet<BinScanSubmitResult?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BinDetailSheet(validation: validation!),
  );
  if (result != null) {
    bloc.add(OperatorTripBinScanFinalized(result));
  }
}

String _friendlyErrorFor(OperatorTripException e) {
  switch (e.code) {
    case 'WRONG_WASTE_TYPE':
      return e.message;
    case 'WRONG_PANCHAYAT':
      return 'This bin is outside your assigned area.';
    case 'ALREADY_COLLECTED':
      return 'This bin was already collected.';
    case 'BIN_NOT_FOUND':
      return 'Bin not found.';
    case 'CP_NOT_IN_TRIP':
      return 'This collection point is not in your trip.';
    case 'NO_ACTIVE_TRIP':
      return 'You have no active trip today.';
    case 'NETWORK_UNREACHABLE':
    case 'NETWORK_TIMEOUT':
    case 'NETWORK_ERROR':
      return 'Cannot reach the server. Check your connection.';
    default:
      return e.message.isEmpty ? 'Something went wrong.' : e.message;
  }
}

// ============================================================
// LOADED VIEW
// ============================================================

class _LoadedView extends StatelessWidget {
  final OperatorTripToday trip;
  final EdgeInsets listPadding;
  const _LoadedView({
    required this.trip,
    this.listPadding = const EdgeInsets.fromLTRB(20, 16, 20, 96),
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: OperatorTheme.accent,
      onRefresh: () async {
        final bloc = context.read<OperatorTripBloc>();
        bloc.add(const OperatorTripRefreshRequested());
        await bloc.stream
            .firstWhere((s) => s.status != OperatorTripStatus.loading);
      },
      child: ListView(
        padding: listPadding,
        children: [
          OperatorTripHeaderCard.fromToday(trip),
          const SizedBox(height: 16),
          _ProgressCard(trip: trip),
          const SizedBox(height: 18),
          Row(
            children: [
              const Text(
                'Collection Points',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: OperatorTheme.strongText,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const OperatorTripHistoryScreen(),
                  ),
                ),
                icon: const Icon(Icons.history_rounded, size: 18),
                label: const Text('History'),
                style: TextButton.styleFrom(
                  foregroundColor: OperatorTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...trip.collectionPoints.map(
            (cp) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OperatorCpCard(
                cp: cp,
                onTap: cp.isCollected
                    ? null
                    : () => openBinSheetForBinQr(context, cp.bin.scanValue),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HEADER & PROGRESS
// ============================================================

class _ProgressCard extends StatelessWidget {
  final OperatorTripToday trip;
  const _ProgressCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final p = trip.progress;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OperatorTheme.surface,
        borderRadius: OperatorTheme.cardRadius,
        border: Border.all(color: OperatorTheme.hairline),
        boxShadow: OperatorTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Trip progress',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: OperatorTheme.mutedText,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              Text(
                '${p.collected} / ${p.total}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: OperatorTheme.strongText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: p.fraction,
              backgroundColor: OperatorTheme.hairline,
              valueColor: AlwaysStoppedAnimation(
                p.completed ? OperatorTheme.success : OperatorTheme.accent,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            p.completed
                ? 'Trip completed. All bins collected.'
                : 'Scan the next bin to continue collection.',
            style: TextStyle(
              fontSize: 12.5,
              color:
                  p.completed ? OperatorTheme.success : OperatorTheme.mutedText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// EMPTY / ERROR
// ============================================================

class _EmptyView extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyView({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: OperatorTheme.accentSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.event_busy_outlined,
                  size: 36, color: OperatorTheme.accent),
            ),
            const SizedBox(height: 14),
            const Text(
              'No trip today',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: OperatorTheme.strongText,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'You do not have a daily trip assigned yet. Pull down to refresh or check with your supervisor.',
              textAlign: TextAlign.center,
              style: TextStyle(color: OperatorTheme.mutedText),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: OperatorTheme.primary,
                side: const BorderSide(color: OperatorTheme.hairline),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
          ],
        ),
      ),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 36, color: OperatorTheme.danger),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: OperatorTheme.strongText),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: OperatorTheme.accent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SCANNER SCREEN (universal scan: any bin, validate against trip)
// ============================================================

class OperatorTripScanScreen extends StatefulWidget {
  const OperatorTripScanScreen({super.key});

  @override
  State<OperatorTripScanScreen> createState() => _OperatorTripScanScreenState();
}

class _OperatorTripScanScreenState extends State<OperatorTripScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );
  bool _busy = false;
  String? _errorBanner;

  OperatorTripRepository get _repo => GetIt.instance<OperatorTripRepository>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_busy) return;
    final raw =
        capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (raw == null || raw.isEmpty) return;
    setState(() {
      _busy = true;
      _errorBanner = null;
    });
    await _controller.stop();
    try {
      final validation = await _repo.validateBinQr(raw.trim());
      if (!mounted) return;
      final result = await showModalBottomSheet<BinScanSubmitResult?>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => BinDetailSheet(validation: validation),
      );
      if (!mounted) return;
      if (result != null) {
        Navigator.of(context).pop(result);
        return;
      }
      setState(() => _busy = false);
      await _controller.start();
    } on OperatorTripException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorBanner = _friendlyMessage(e);
      });
      await _controller.start();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorBanner = 'Could not validate bin. Try again.';
      });
      await _controller.start();
    }
  }

  String _friendlyMessage(OperatorTripException e) {
    switch (e.code) {
      case 'WRONG_WASTE_TYPE':
        return 'Wrong waste type. ${e.message}';
      case 'WRONG_PANCHAYAT':
        return 'Bin is outside your panchayat.';
      case 'ALREADY_COLLECTED':
        return 'Already collected.';
      case 'BIN_NOT_FOUND':
        return 'Bin not found for this QR.';
      case 'CP_NOT_IN_TRIP':
        return 'This CP is not in your trip.';
      case 'NO_ACTIVE_TRIP':
        return 'You do not have an active trip today.';
      default:
        return e.message.isEmpty ? 'Could not validate bin.' : e.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan Bin QR'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Toggle flash',
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetection,
          ),
          // Translucent overlay focus area
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: OperatorTheme.accent, width: 3),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          if (_errorBanner != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Material(
                color: OperatorTheme.danger,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorBanner!,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Align the bin QR within the frame',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
