import 'package:flutter/material.dart';

import '../services/app_state.dart';
import '../services/offline_queue.dart';
import '../theme.dart';

/// Shows recitations saved offline that are waiting to be sent, and any the
/// server rejected. Renders nothing when the queue is empty.
class SyncBanner extends StatelessWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.app.t;
    final queue = RecitationQueue.instance;

    return ListenableBuilder(
      listenable: queue,
      builder: (context, _) {
        final pending = queue.pending.length;
        final failed = queue.failed;
        if (pending == 0 && failed.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              if (pending > 0)
                _box(
                  color: C.blue,
                  icon: Icons.cloud_upload_outlined,
                  text: pending == 1
                      ? t('sync.pendingOne')
                      : t('sync.pendingMany').replaceAll('{n}', '$pending'),
                  action: queue.syncing
                      ? Text(t('sync.sending'), style: body(12, color: C.blue))
                      : _link(t('sync.sendNow'), C.blue, queue.sync),
                ),
              for (final item in failed) ...[
                if (pending > 0) const SizedBox(height: 8),
                _box(
                  color: C.maroon,
                  icon: Icons.error_outline,
                  text: '${t('sync.failed')}: ${item.error}',
                  action: _link(t('sync.dismiss'), C.maroon, () => queue.dismiss(item)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _box({
    required Color color,
    required IconData icon,
    required String text,
    required Widget action,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: body(12.5, color: color, weight: FontWeight.w600))),
          const SizedBox(width: 8),
          action,
        ],
      ),
    );
  }

  Widget _link(String label, Color color, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Text(label,
            style: body(12, color: color, weight: FontWeight.w700)
                .copyWith(decoration: TextDecoration.underline)),
      );
}
