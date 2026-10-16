import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../config/env.dart';
import '../storage/token_storage.dart';

enum RealtimeStatus { disconnected, connecting, connected }

final realtimeClientProvider = Provider<RealtimeClient>((ref) {
  final client = RealtimeClient(ref.read(tokenStorageProvider));
  ref.onDispose(client.dispose);
  return client;
});

/// STOMP over native WebSocket at `/ws`. Only LIBRARIAN/ADMIN may connect.
class RealtimeClient {
  RealtimeClient(this._tokens);

  final TokenStorage _tokens;
  final status = ValueNotifier(RealtimeStatus.disconnected);
  StompClient? _client;

  void connect() {
    if (_client != null) return;
    status.value = RealtimeStatus.connecting;
    _client = StompClient(
      config: StompConfig(
        url: Env.wsUrl,
        reconnectDelay: const Duration(seconds: 5),
        beforeConnect: () async => status.value = RealtimeStatus.connecting,
        stompConnectHeaders: {'Authorization': 'Bearer ${_tokens.accessToken}'},
        onConnect: (_) => status.value = RealtimeStatus.connected,
        onDisconnect: (_) => status.value = RealtimeStatus.disconnected,
        onWebSocketError: (_) => status.value = RealtimeStatus.disconnected,
      ),
    )..activate();
  }

  /// Returns an unsubscribe callback.
  VoidCallback subscribeJson(String destination, void Function(Map<String, dynamic>) onMessage) {
    final client = _client;
    if (client == null) throw StateError('RealtimeClient.connect() must be called first');
    return client.subscribe(
      destination: destination,
      callback: (frame) {
        final body = frame.body;
        if (body != null) onMessage(jsonDecode(body) as Map<String, dynamic>);
      },
    );
  }

  void disconnect() {
    _client?.deactivate();
    _client = null;
    status.value = RealtimeStatus.disconnected;
  }

  void dispose() {
    disconnect();
    status.dispose();
  }
}
