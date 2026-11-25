import 'package:flutter/material.dart';

/// Asks the user to confirm before signing out, so a stray tap on the app
/// bar button doesn't end the session. Returns true only if they confirmed.
Future<bool> showSignOutSheet(
  BuildContext context, {
  String? email,
  int unsyncedScans = 0,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => SignOutSheet(email: email, unsyncedScans: unsyncedScans),
    ) ??
    false;

class SignOutSheet extends StatelessWidget {
  const SignOutSheet({super.key, this.email, this.unsyncedScans = 0});

  /// Shown so the user can see which account they're leaving.
  final String? email;

  final int unsyncedScans;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = this.email;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Sign out?', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            email == null || email.isEmpty
                ? "You'll need to sign in again to use TAMS on this device."
                : "You're signed in as $email. You'll need to sign in again "
                      'to use TAMS on this device.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (unsyncedScans > 0) ...[
            const SizedBox(height: 16),
            Container(
              key: const Key('sign-out-unsynced'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      unsyncedScans == 1
                          ? "1 audit scan hasn't synced yet. It stays on this "
                                'phone and syncs the next time you sign in.'
                          : "$unsyncedScans audit scans haven't synced yet. "
                                'They stay on this phone and sync the next '
                                'time you sign in.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('sign-out-confirm'),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('sign-out-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
