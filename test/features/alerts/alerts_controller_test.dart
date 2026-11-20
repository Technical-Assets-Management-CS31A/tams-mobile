import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/core/network/token_provider.dart';
import 'package:tams_mobile/features/alerts/domain/entities/alert.dart';
import 'package:tams_mobile/features/alerts/presentation/controllers/alerts_controller.dart';

import '../../helpers/fake_alerts_repository.dart';

/// Holds [list] until [gate] completes, when one is set.
class _GatedAlertsRepository extends FakeAlertsRepository {
  _GatedAlertsRepository(super.alerts);

  Completer<void>? gate;

  @override
  Future<AlertsPage> list({int page = 1}) async {
    if (gate case final g?) await g.future;
    return super.list(page: page);
  }
}

ProviderContainer _container(
  FakeAlertsRepository repo, {
  bool signedIn = true,
}) {
  final container = ProviderContainer(
    overrides: [
      alertsRepositoryProvider.overrideWithValue(repo),
      if (signedIn) authTokenProvider.overrideWith(SignedInToken.new),
    ],
  );
  addTearDown(container.dispose);
  // Keep the controller alive between reads, as the shell does.
  container.listen(alertsControllerProvider, (_, _) {});
  return container;
}

void main() {
  test('signed out, refresh does nothing', () async {
    final repo = FakeAlertsRepository([alert('a')]);
    final container = _container(repo, signedIn: false);
    await container.read(alertsControllerProvider.future);

    await container.read(alertsControllerProvider.notifier).refresh();

    expect(repo.listedPages, isEmpty);
    expect(container.read(alertsControllerProvider).value!.items, isEmpty);
  });

  test('a refresh that ends after sign-out does not bring the '
      "previous user's alerts back", () async {
    final repo = _GatedAlertsRepository([alert('a')]);
    final container = _container(repo);
    expect(
      (await container.read(alertsControllerProvider.future)).items,
      hasLength(1),
    );

    final gate = repo.gate = Completer<void>();
    final refreshing = container
        .read(alertsControllerProvider.notifier)
        .refresh();

    container.read(authTokenProvider.notifier).clear();
    expect(
      (await container.read(alertsControllerProvider.future)).items,
      isEmpty,
    );

    gate.complete();
    await refreshing;

    final after = container.read(alertsControllerProvider);
    expect(after.value!.items, isEmpty);
    expect(after.value!.unreadCount, 0);
  });
}
