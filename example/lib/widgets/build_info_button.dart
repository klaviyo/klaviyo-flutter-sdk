import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../build_info.dart';

/// App-bar button that opens the build-info sheet. Only the Profile tab has
/// it; the sheet is the single copy of the content.
class BuildInfoButton extends StatelessWidget {
  const BuildInfoButton({super.key});

  static const buttonKey = Key('build-info-button');

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: buttonKey,
      icon: const Icon(Icons.info_outline),
      tooltip: 'Build info',
      onPressed: () async {
        final info = await BuildInfo.load();
        if (!context.mounted) return;
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (context) => BuildInfoSheet(info: info),
        );
      },
    );
  }
}

/// Bottom sheet listing which SDK builds the app was compiled against, so a
/// tester can quote exact refs in a bug report.
class BuildInfoSheet extends StatelessWidget {
  const BuildInfoSheet({super.key, required this.info});

  final BuildInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Build info', style: theme.textTheme.titleMedium),
                IconButton(
                  key: const Key('copy-build-info'),
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copy build info',
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: info.toHeaderBlock()),
                    );
                  },
                ),
              ],
            ),
            const Divider(),
            for (final (label, value) in info.rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 150,
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
