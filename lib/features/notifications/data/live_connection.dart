import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_netcore/signalr_client.dart';

/// A connection to the backend's real-time hub (tams-backend `LiveHub` at
/// `/hubs/live`, PRD 6.4), so tests can fake it. The hub only sends;
/// the app never calls it.
abstract interface class LiveConnection {
  /// The name of each event as it arrives, e.g. `approval.requested`.
  Stream<String> get events;

  /// Connected again after a drop. Events sent meanwhile were missed.
  Stream<void> get reconnected;

  /// Gave up reconnecting, or the server closed the connection.
  Stream<void> get closed;

  Future<void> start();
  Future<void> stop();
}

/// Builds a connection to [url] that reports [events]. [accessToken] is
/// asked for the JWT on every connect and reconnect.
typedef LiveConnectionFactory = LiveConnection Function(
  Uri url, {
  required List<String> events,
  required Future<String> Function() accessToken,
});

final liveConnectionFactoryProvider = Provider<LiveConnectionFactory>(
  (ref) => SignalRLiveConnection.new,
);

/// [LiveConnection] over ASP.NET Core SignalR. The JWT goes in the
/// `access_token` query parameter, as the hub expects (`AuthSetup`).
class SignalRLiveConnection implements LiveConnection {
  SignalRLiveConnection(
    Uri url, {
    required List<String> events,
    required Future<String> Function() accessToken,
  }) : _hub = HubConnectionBuilder()
           .withUrl(
             url.toString(),
             options: HttpConnectionOptions(
               accessTokenFactory: accessToken,
               // The 2 s default is too short for a cold start on Railway.
               requestTimeout: 15000,
             ),
           )
           // Retries after 0, 2, 10 and 30 s, then reports [closed].
           .withAutomaticReconnect()
           .build() {
    for (final e in events) {
      _hub.on(e, (_) => _events.add(e));
    }
    _hub.onreconnected(({connectionId}) => _reconnected.add(null));
    _hub.onclose(({error}) => _closed.add(null));
  }

  final HubConnection _hub;
  final _events = StreamController<String>.broadcast();
  final _reconnected = StreamController<void>.broadcast();
  final _closed = StreamController<void>.broadcast();

  @override
  Stream<String> get events => _events.stream;

  @override
  Stream<void> get reconnected => _reconnected.stream;

  @override
  Stream<void> get closed => _closed.stream;

  @override
  Future<void> start() => _hub.start() ?? Future.value();

  @override
  Future<void> stop() async {
    try {
      await _hub.stop();
    } finally {
      await _events.close();
      await _reconnected.close();
      await _closed.close();
    }
  }
}
