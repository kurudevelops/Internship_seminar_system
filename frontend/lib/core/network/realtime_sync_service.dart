import 'dart:async';
import 'package:flutter/foundation.dart';

class RealtimeSyncService {
  Timer? _syncTimer;
  final VoidCallback onSyncRequested;

  RealtimeSyncService({required this.onSyncRequested});

  /// Starts automatic silent background synchronization across all active stations.
  void start({Duration interval = const Duration(seconds: 4)}) {
    stop();
    _syncTimer = Timer.periodic(interval, (_) {
      onSyncRequested();
    });
  }

  void stop() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }
}