import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_seva/services/api.dart';
import 'package:infinite_seva/services/offline_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late List<String> sent;
  late Object? Function(PendingRecitation) behaviour; // returns an error to throw, or null
  late RecitationQueue queue;

  Future<RecitationQueue> open() async {
    final q = RecitationQueue(send: (item) async {
      final err = behaviour(item);
      if (err != null) throw err;
      sent.add(item.key);
    });
    await q.init(dir: dir, watch: false);
    return q;
  }

  Future<void> addItem(String key) => queue.add(
        key: key,
        userId: 7,
        payload: {'type': 'INDIVIDUAL', 'durationSeconds': 60, 'photoBase64': null},
      );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('queue_test');
    sent = [];
    behaviour = (_) => null;
    queue = await open();
  });

  tearDown(() async {
    queue.dispose();
    await dir.delete(recursive: true);
  });

  int filesOnDisk() => dir.listSync().where((f) => f.path.endsWith('.json')).length;

  test('saved recitation is written to disk and survives an app restart', () async {
    await addItem('k1');
    expect(queue.pending.map((i) => i.key), ['k1']);
    expect(filesOnDisk(), 1);

    final reopened = await open();
    expect(reopened.pending.single.key, 'k1');
    expect(reopened.pending.single.userId, 7);
    expect(reopened.pending.single.payload['durationSeconds'], 60);
    reopened.dispose();
  });

  test('still offline: stays queued and nothing is lost', () async {
    behaviour = (_) => ApiException('Network error', code: 'NETWORK');
    await addItem('k1');
    await queue.sync();
    expect(queue.pending.length, 1);
    expect(queue.failed, isEmpty);
    expect(filesOnDisk(), 1);
  });

  test('back online: sends everything with its original key, then clears it', () async {
    await addItem('k1');
    await addItem('k2');
    await queue.sync();
    expect(sent, ['k1', 'k2']);
    expect(queue.pending, isEmpty);
    expect(filesOnDisk(), 0);
  });

  test('stops at the first network failure and keeps the rest', () async {
    await addItem('k1');
    await addItem('k2');
    behaviour = (item) => item.key == 'k1' ? null : ApiException('t', code: 'TIMEOUT');
    await queue.sync();
    expect(sent, ['k1']);
    expect(queue.pending.map((i) => i.key), ['k2']);
  });

  test('server errors (5xx) are retried later', () async {
    behaviour = (_) => ApiException('Bad gateway', status: 502);
    await addItem('k1');
    await queue.sync();
    expect(queue.pending.length, 1);
    expect(queue.failed, isEmpty);
  });

  test('server rejection (4xx) is kept as failed, not retried, until dismissed', () async {
    behaviour = (_) => ApiException('This campaign is not currently active', status: 400);
    await addItem('k1');
    await queue.sync();
    expect(queue.pending, isEmpty);
    expect(queue.failed.single.error, 'This campaign is not currently active');
    expect(filesOnDisk(), 1, reason: 'kept on disk so the user sees why');

    behaviour = (_) => fail('a rejected item must not be re-sent');
    await queue.sync();

    final reopened = await open();
    expect(reopened.failed.single.key, 'k1');
    reopened.dispose();

    await queue.dismiss(queue.failed.single);
    expect(queue.failed, isEmpty);
    expect(filesOnDisk(), 0);
  });
}
