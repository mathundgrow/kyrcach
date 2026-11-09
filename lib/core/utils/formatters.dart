import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

class Formatters {
  const Formatters._();

  static final DateFormat _time = DateFormat('HH:mm:ss');
  static final DateFormat _dateTime = DateFormat('dd.MM.yyyy · HH:mm');

  static String clock(DateTime value) => _time.format(value);

  static String dateTime(DateTime value) => _dateTime.format(value);

  static String duration(Duration value) {
    if (value.inMilliseconds < 1000) {
      return '${value.inMilliseconds} мс';
    }
    final seconds = value.inMilliseconds / 1000;
    return '${seconds.toStringAsFixed(seconds < 10 ? 2 : 1)} с';
  }

  static String count(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final remaining = text.length - i;
      buffer.write(text[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write(' ');
    }
    return buffer.toString();
  }

  static String relativePath(String absolutePath) {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null || home.isEmpty) return absolutePath;
    if (!p.isWithin(home, absolutePath)) return absolutePath;
    return '~${p.separator}${p.relative(absolutePath, from: home)}';
  }

  static String shortPath(String path, {int maxSegments = 3}) {
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/').where((e) => e.isNotEmpty).toList();
    if (segments.length <= maxSegments) return normalized;
    return '…/${segments.sublist(segments.length - maxSegments).join('/')}';
  }
}
