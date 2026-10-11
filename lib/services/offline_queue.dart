import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'api.dart';

class PendingRecitation {
  final String key; // Idempotency-Key, reused on every retry so the server never double-counts
  final int userId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  /// Set when the server rejected it (4xx). Such items are no longer retried.
  final String? error;

  const PendingRecitation({
    required this.key,
    required this.userId,
    required this.payload,
    required this.createdAt,
    this.error,
  });

  factory PendingRecitation.fromJson(Map<String, dynamic> j) => PendingRecitation(
        key: j['key'] as String,
        userId: (j['userId'] as num).toInt(),
        payload: Map<String, dynamic>.from(j['payload'] as Map),
        createdAt: DateTime.parse(j['createdAt'] as String),
        error: j['error'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'userId': userId,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
        'error': error,
      };

  PendingRecitation withError(String e) => PendingRecitation(
      key: key, userId: userId, payload: payload, createdAt: createdAt, error: e);
}

/// Recitations that could not reach the server. Each is stored as a JSON file on
/// the device (photos make them too big for SharedPreferences) and re-sent when
/// the app starts, returns to the foreground, regains connectivity, or every
/// minute while something is waiting.
class RecitationQueue extends ChangeNotifier with WidgetsBindingObserver {
  RecitationQueue({Future<void> Function(PendingRecitation item)? send})
      : _send = send ?? _sendToApi;
  static final RecitationQueue instance = RecitationQueue();

  static Future<void> _sendToApi(PendingRecitation item) => Api.instance.submitRecitation(
        userId: item.userId,
        idempotencyKey: item.key,
        payload: item.payload,
      );

  final Future<void> Function(PendingRecitation item) _send;

  static const _retryEvery = Duration(seconds: 60);

  Directory? _dir;
  List<PendingRecitation> _items = [];
  bool _syncing = false;
  Timer? _retry;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;

  /// Waiting to be sent (will be retried).
  List<PendingRecitation> get pending => _items.where((i) => i.error == null).toList();

  /// Rejected by the server; kept so the user can see why, until dismissed.
  List<PendingRecitation> get failed => _items.where((i) => i.error != null).toList();

  bool get syncing => _syncing;

  /// [dir] and [watch] exist for tests: a temp folder, and no platform listeners.
  Future<void> init({Directory? dir, bool watch = true}) async {
    _dir = dir ??
        Directory('${(await getApplicationSupportDirectory()).path}/pending_recitations');
    await _dir!.create(recursive: true);
    _items = await _readAll();

    if (watch) {
      WidgetsBinding.instance.addObserver(this);
      _connectivity = Connectivity().onConnectivityChanged.listen((results) {
        if (results.any((r) => r != ConnectivityResult.none)) sync();
      });
      unawaited(sync());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivity?.cancel();
    _retry?.cancel();
    super.dispose();
  }

  Future<void> add({
    required String key,
    required int userId,
    required Map<String, dynamic> payload,
  }) async {
    final item = PendingRecitation(
        key: key, userId: userId, payload: payload, createdAt: DateTime.now());
    await _write(item);
    _items = [..._items.where((i) => i.key != key), item];
    notifyListeners();
    _scheduleRetry();
  }

  /// Sends everything waiting, oldest first. Stops at the first transient
  /// failure (still offline); marks server rejections as failed.
  Future<void> sync() async {
    if (_syncing || pending.isEmpty) return;
    _syncing = true;
    notifyListeners();
    try {
      final queue = pending..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (final item in queue) {
        try {
          await _send(item);
          await _delete(item.key);
          _items.removeWhere((i) => i.key == item.key);
        } on ApiException catch (e) {
          if (e.isTransient) break;
          final rejected = item.withError(e.message);
          await _write(rejected);
          _items = [for (final i in _items) i.key == item.key ? rejected : i];
        }
      }
    } finally {
      _syncing = false;
      notifyListeners();
      _scheduleRetry();
    }
  }

  Future<void> dismiss(PendingRecitation item) async {
    await _delete(item.key);
    _items.removeWhere((i) => i.key == item.key);
    notifyListeners();
  }

  void _scheduleRetry() {
    if (pending.isEmpty) {
      _retry?.cancel();
      _retry = null;
    } else {
      _retry ??= Timer(_retryEvery, () {
        _retry = null;
        sync();
      });
    }
  }

  // ───────────────────────── storage ─────────────────────────
  File _file(String key) => File('${_dir!.path}/$key.json');

  Future<void> _write(PendingRecitation item) async {
    // Write then rename so a crash mid-write never leaves a half-written file.
    final tmp = File('${_file(item.key).path}.tmp');
    await tmp.writeAsString(jsonEncode(item.toJson()), flush: true);
    await tmp.rename(_file(item.key).path);
  }

  Future<void> _delete(String key) async {
    final f = _file(key);
    if (await f.exists()) await f.delete();
  }

  Future<List<PendingRecitation>> _readAll() async {
    final items = <PendingRecitation>[];
    await for (final entity in _dir!.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        items.add(PendingRecitation.fromJson(
            jsonDecode(await entity.readAsString()) as Map<String, dynamic>));
      } catch (_) {
        // Unreadable file: leave it on disk rather than lose the data.
      }
    }
    return items;
  }
}
