import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../providers/app_providers.dart';

/// Slim banner above the whole app. It appears when:
///  - the device has no connection,
///  - the server isn't answering,
///  - any list is showing saved data instead of fresh data, or
///  - changes made offline are waiting to upload.
/// Otherwise it shows [child] untouched.
class ConnectionBanner extends ConsumerWidget {
  const ConnectionBanner({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceOnline = ref.watch(connectivityProvider).value ?? true;
    final serverReachable = ref.watch(serverReachableProvider);
    final cachedSources = ref.watch(cachedFallbackProvider);

    // Rebuilds whenever the pending queue changes.
    return ValueListenableBuilder<Box<String>>(
      valueListenable: Hive.box<String>('pending_ops_box').listenable(),
      builder: (context, box, _) {
        final pending = box.length;
        final showingSavedData = cachedSources.isNotEmpty;

        // What is wrong, if anything (most specific cause first).
        String? problem;
        if (!deviceOnline) {
          problem = 'Offline';
        } else if (!serverReachable) {
          problem = "Can't reach the server";
        } else if (showingSavedData) {
          problem = "Couldn't refresh";
        }

        if (problem == null && pending == 0) return child;

        final parts = <String>[
          if (problem != null)
            '$problem${showingSavedData ? ' - showing saved data' : ''}',
          if (pending > 0)
            '$pending change${pending == 1 ? '' : 's'} waiting to upload',
        ];

        final scheme = Theme.of(context).colorScheme;
        final isProblem = problem != null;

        return Column(
          children: [
            Material(
              color: isProblem ? scheme.errorContainer : scheme.tertiaryContainer,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isProblem ? Icons.cloud_off : Icons.sync, size: 16),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          parts.join(' · '),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // The banner already covers the status bar, so the screens below
            // shouldn't add that padding a second time.
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}
