import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/network/token_provider.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/jwt.dart';
import '../../../alerts/presentation/controllers/alerts_controller.dart';
import '../../../approvals/presentation/controllers/approvals_controller.dart';
import '../../../loans/presentation/controllers/loan_detail_provider.dart';
import '../../data/live_connection.dart';

/// The hub's path, from the API's root (tams-backend `Program.cs`).
const liveHubPath = '/hubs/live';

/// The PRD 6.4 events the hub sends to an instructor's own group
/// (`user:{id}`). Staff-only events such as `asset.statusChanged` never
/// reach the app, so My Loans still polls for check-ins at the room.
const liveEvents = [
  'approval.requested',
  'instructor.frozen',
  'instructor.unfrozen',
  'warning.issued',
  'anomaly.raised',
  'anomaly.resolved',
  'loan.overdue',
];

/// Keeps the app connected to the real-time hub while signed in (PRD 6.1),
/// and reloads the list an event is about: a new request shows on Pending
/// Approvals, a freeze on the banner, a warning on Alerts and My Loans,
/// within a second instead of at the next poll.
///
/// Only reloads data; pushes are what the user sees and taps
/// ([PushNotifications]), so an event never shows twice. In the
/// background the OS drops the socket and pushes take over (PRD 6.4).
class LiveUpdates {
  LiveUpdates(this._ref);

  final Ref _ref;

  /// How long to wait before connecting again after the hub gave up.
  static const retryEvery = Duration(seconds: 30);

  /// A token this close to expiry is renewed before connecting.
  static const _renewWithin = Duration(seconds: 30);

  bool _started = false;
  LiveConnection? _connection;
  final _subscriptions = <StreamSubscription<Object?>>[];
  Timer? _retry;

  /// Who [_connection] is for: the token's `sub`, or the token itself.
  String? _user;

  /// Bumped on every connect and disconnect, so a slow start that finishes
  /// after a sign-out is dropped.
  int _generation = 0;

  /// True once this user's hub connection has been up. After that, a new
  /// connection may have missed events, so the lists are reloaded.
  bool _wasConnected = false;

  /// Starts following the session. Safe to call more than once.
  void start() {
    if (_started) return;
    _started = true;
    _ref.listen(
      authTokenProvider,
      (_, token) => _onToken(token),
      fireImmediately: true,
    );
  }

  /// The app is back in the foreground: connect now if the hub was lost,
  /// instead of waiting for the next retry.
  void resume() {
    if (_user != null && _retry != null) _connect();
  }

  void _onToken(String? token) {
    if (token == null) {
      _disconnect();
      _user = null;
      _wasConnected = false;
      return;
    }
    final sub = jwtClaims(token)?['sub'];
    final user = sub is String && sub.isNotEmpty ? sub : token;
    // A renewed token for the same user keeps the open connection.
    if (user == _user && _connection != null) return;
    _disconnect();
    if (user != _user) _wasConnected = false;
    _user = user;
    _connect();
  }

  Future<void> _connect() async {
    _disconnect();
    final generation = _generation;
    final base = Uri.parse(_ref.read(dioProvider).options.baseUrl);
    final connection = _ref.read(liveConnectionFactoryProvider)(
      base.resolve(liveHubPath),
      events: liveEvents,
      accessToken: _accessToken,
    );
    _connection = connection;
    _subscriptions
      ..add(connection.events.listen(_onEvent))
      ..add(connection.reconnected.listen((_) => _reloadAll()))
      ..add(connection.closed.listen((_) => _lost(generation)));
    try {
      await connection.start();
    } catch (e) {
      debugPrint('Live updates unavailable: $e');
      _lost(generation);
      return;
    }
    if (generation != _generation) return;
    if (_wasConnected) _reloadAll();
    _wasConnected = true;
  }

  /// The hub reads the JWT from the URL and refuses an expired one, so an
  /// old token is renewed first: any API call does that, through the Dio
  /// interceptor.
  Future<String> _accessToken() async {
    var token = _ref.read(authTokenProvider);
    final expiry = token == null ? null : jwtExpiry(token);
    final now = _ref.read(clockProvider)();
    if (expiry != null && expiry.isBefore(now.add(_renewWithin))) {
      await _ref.read(dioProvider).get<Object?>('/auth/me');
      token = _ref.read(authTokenProvider);
    }
    if (token == null) throw StateError('Signed out.');
    return token;
  }

  void _lost(int generation) {
    if (generation != _generation || _retry != null) return;
    _retry = Timer(retryEvery, () {
      _retry = null;
      if (generation == _generation) _connect();
    });
  }

  void _disconnect() {
    _generation++;
    _retry?.cancel();
    _retry = null;
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    final connection = _connection;
    _connection = null;
    if (connection != null) {
      unawaited(
        connection.stop().catchError(
          (Object e) => debugPrint('Could not close live updates: $e'),
        ),
      );
    }
  }

  void _onEvent(String event) {
    switch (event) {
      case 'approval.requested':
      // The freeze banner comes with the pending list.
      case 'instructor.frozen' || 'instructor.unfrozen':
        _ref.invalidate(approvalsControllerProvider);
      default:
        // Warnings, anomalies and overdue loans: a new alert, a loan's live
        // status changed, and maybe a freeze, in case `instructor.frozen`
        // doesn't come with it.
        _reloadAll();
    }
  }

  void _reloadAll() {
    _ref
      ..invalidate(approvalsControllerProvider)
      ..invalidate(alertsControllerProvider)
      ..invalidate(myLoansProvider);
  }

  void dispose() {
    _disconnect();
  }
}

final liveUpdatesProvider = Provider<LiveUpdates>((ref) {
  final live = LiveUpdates(ref);
  ref.onDispose(live.dispose);
  return live;
});
