import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snap) {
        final results = snap.data ?? const <ConnectivityResult>[];
        final offline = results.isEmpty ||
            results.every((r) => r == ConnectivityResult.none);
        if (!offline) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Material(
          color: scheme.errorContainer,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.cloud_off_rounded,
                      size: 18, color: scheme.onErrorContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "You're offline. Showing cached content.",
                      style: AppText.labelSm(scheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
