import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/brutalist_theme.dart';
import '../widgets/brutalist_button.dart';
import '../widgets/brutalist_card.dart';
import '../widgets/scan_progress_indicator.dart';
import 'credentials_screen.dart';

/// Screen 1: Network Scanner
/// Scans the local subnet for hosts with SMB ports open.
class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrutalistTheme.concrete,
      body: SafeArea(
        child: Consumer<AppState>(
          builder: (context, state, _) {
            return CustomScrollView(
              slivers: [
                // ─── HEADER ────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    color: BrutalistTheme.black,
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VIDEO//NET',
                          style: BrutalistTheme.displayLarge.copyWith(
                            color: BrutalistTheme.white,
                            fontSize: 42,
                            letterSpacing: -2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 4,
                          width: 80,
                          color: BrutalistTheme.accent,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'NETWORK VIDEO SCANNER',
                          style: BrutalistTheme.bodySmall.copyWith(
                            color: BrutalistTheme.accent,
                            letterSpacing: 4,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ─── LOCAL IP INFO ─────────────────
                if (state.localIp != null)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: BrutalistTheme.darkConcrete,
                        border: BrutalistTheme.hardBorder,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.wifi,
                              color: BrutalistTheme.portOpen, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            'LOCAL IP: ${state.localIp}',
                            style: BrutalistTheme.mono.copyWith(
                              color: BrutalistTheme.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ─── SCAN BUTTON ───────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: state.isScanning
                        ? Column(
                            children: [
                              if (state.scanProgress != null)
                                ScanProgressIndicator(
                                  progress:
                                      state.scanProgress!.percentage,
                                  label: 'SCANNING',
                                  sublabel:
                                      '${state.scanProgress!.scanned}/${state.scanProgress!.total} hosts checked',
                                ),
                              const SizedBox(height: 12),
                              BrutalistButton(
                                label: 'STOP SCAN',
                                backgroundColor: BrutalistTheme.error,
                                icon: Icons.stop,
                                onPressed: () => state.stopScan(),
                              ),
                            ],
                          )
                        : BrutalistButton(
                            label: 'SCAN NETWORK >>',
                            icon: Icons.radar,
                            backgroundColor: BrutalistTheme.accent,
                            textColor: BrutalistTheme.white,
                            onPressed: () => state.startScan(),
                          ),
                  ),
                ),

                // ─── ERROR ─────────────────────────
                if (state.scanError != null)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: BrutalistTheme.error.withValues(alpha: 0.1),
                        border: Border.all(
                            color: BrutalistTheme.error, width: 3),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: BrutalistTheme.error),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              state.scanError!,
                              style: BrutalistTheme.mono.copyWith(
                                color: BrutalistTheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ─── RESULTS HEADER ────────────────
                if (state.discoveredHosts.isNotEmpty ||
                    (!state.isScanning && state.localIp != null))
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            color: BrutalistTheme.black,
                            child: Text(
                              'FOUND: ${state.discoveredHosts.length}',
                              style: BrutalistTheme.labelLarge.copyWith(
                                color: BrutalistTheme.accent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: 3,
                              color: BrutalistTheme.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ─── HOST LIST ─────────────────────
                if (state.discoveredHosts.isEmpty &&
                    !state.isScanning &&
                    state.localIp != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: BrutalistCard(
                        backgroundColor: BrutalistTheme.concrete,
                        child: Column(
                          children: [
                            const Icon(Icons.search_off,
                                size: 48,
                                color: BrutalistTheme.darkConcrete),
                            const SizedBox(height: 12),
                            Text(
                              'NO SMB HOSTS FOUND',
                              style: BrutalistTheme.headlineMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Make sure devices with shared folders\nare on the same network.',
                              style: BrutalistTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final host = state.discoveredHosts[index];
                      return _HostCard(host: host);
                    },
                    childCount: state.discoveredHosts.length,
                  ),
                ),

                // ─── BOTTOM SPACER ─────────────────
                const SliverToBoxAdapter(
                  child: SizedBox(height: 32),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Card displaying a discovered SMB host.
class _HostCard extends StatelessWidget {
  final DiscoveredHost host;

  const _HostCard({required this.host});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: BrutalistCard(
        onTap: () {
          state.selectHost(host);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CredentialsScreen(host: host),
            ),
          );
        },
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: BrutalistTheme.portOpen,
                border: Border.all(
                    color: BrutalistTheme.black, width: 2),
              ),
            ),
            const SizedBox(width: 16),

            // Host info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    host.ip,
                    style: BrutalistTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      ...host.openPorts.map((port) => Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: BrutalistTheme.accent
                                  .withValues(alpha: 0.15),
                              border: Border.all(
                                  color: BrutalistTheme.accent,
                                  width: 2),
                            ),
                            child: Text(
                              'PORT $port',
                              style:
                                  BrutalistTheme.bodySmall.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: BrutalistTheme.accent,
                              ),
                            ),
                          )),
                    ],
                  ),
                  if (host.hostname != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      host.hostname!,
                      style: BrutalistTheme.bodySmall
                          .copyWith(fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),

            // Arrow
            Container(
              padding: const EdgeInsets.all(8),
              color: BrutalistTheme.black,
              child: const Icon(
                Icons.arrow_forward,
                color: BrutalistTheme.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
