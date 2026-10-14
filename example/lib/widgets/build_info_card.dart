import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../build_info.dart';

/// Shows which SDK builds the app was compiled against. Sits at the bottom
/// of the Profile tab so a tester can quote exact refs in a bug report.
class BuildInfoCard extends StatelessWidget {
  const BuildInfoCard({super.key, required this.info});

  final BuildInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <(String, String)>[
      ('Flutter SDK', info.flutterSdkRef),
      ('iOS SDK', info.iosSdkRef),
      ('Android SDK', info.androidSdkRef),
      ('App', '${info.appVersion} (${info.buildNumber})'),
      ('Commit', '${info.commitShort} (${info.branch})'),
      ('Built', info.buildDate),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Build info',
                  style: theme.textTheme.titleSmall,
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copy build info',
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: info.toMultilineString()),
                    );
                  },
                ),
              ],
            ),
            const Divider(),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SelectableText(
                        value,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
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
