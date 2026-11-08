import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/auth_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Signed in as ${user?.email ?? ''}'),
            const SizedBox(height: 16),
            FilledButton(
              // Router redirect sends us back to /login once state is null.
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
