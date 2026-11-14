import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models.dart';
import 'net.dart';

/// Queue of file downloads with progress, visible in the Downloads tab.
class DownloadManager extends ChangeNotifier {
  final List<DownloadTask> tasks = [];
  final int maxConcurrent = 3;
  int _running = 0;
  final Set<String> _started = {};

  static final DownloadManager instance = DownloadManager();

  void Function()? onTaskDone;

  /// Adds a download; returns the created task.
  DownloadTask add({
    required String title,
    required String url,
    required String destPath,
    String? tag,
    void Function()? onDone,
  }) {
    final t = DownloadTask(
      id: DateTime.now().microsecondsSinceEpoch.toString() +
          (tasks.length).toString(),
      title: title,
      url: url,
      destPath: destPath,
      tag: tag,
    );
    tasks.insert(0, t);
    _onDone[t.id] = onDone;
    notifyListeners();
    _pump();
    return t;
  }

  final Map<String, void Function()> _onDone = {};

  void _pump() {
    while (_running < maxConcurrent) {
      final next = tasks.lastWhere(
        (t) => t.status == 'queued' && !_started.contains(t.id),
        orElse: () => _none,
      );
      if (next == _none) break;
      _started.add(next.id);
      _running++;
      _run(next);
    }
    notifyListeners();
  }

  static final _none = DownloadTask(
      id: '-1', title: '', url: '', destPath: '');

  Future<void> _run(DownloadTask t) async {
    t.status = 'running';
    notifyListeners();
    try {
      await File(t.destPath).parent.create(recursive: true);
      final req = http.Request('GET', Uri.parse(t.url));
      req.headers['User-Agent'] = Net.ua;
      final resp = await http.Client().send(req);
      if (resp.statusCode != 200) {
        throw HttpError(resp.statusCode, '');
      }
      t.total = resp.contentLength ?? 0;
      final sink = File(t.destPath).openWrite();
      try {
        await for (final chunk in resp.stream) {
          sink.add(chunk);
          t.received += chunk.length;
          notifyListeners();
        }
      } finally {
        await sink.close();
      }
      t.status = 'done';
      _onDone.remove(t.id)?.call();
    } catch (e) {
      t.status = 'error';
      t.error = e.toString();
    } finally {
      _running--;
      _pump();
    }
  }

  void cancel(DownloadTask t) {
    if (t.status == 'queued') {
      t.status = 'canceled';
      notifyListeners();
    }
  }

  void clearFinished() {
    tasks.removeWhere(
        (t) => t.status == 'done' || t.status == 'canceled' || t.status == 'error');
    notifyListeners();
  }

  bool get hasActive => tasks.any((t) => t.status == 'queued' || t.status == 'running');
}
