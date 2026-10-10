import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Indian digit grouping (12,34,567).
String fmt(num? n) => NumberFormat.decimalPattern('en_IN').format(n ?? 0);

/// 0.004 -> "<0.01", 12.5 -> "12.5", 12 -> "12"
String fmtPct(num p) {
  if (p > 0 && p < 0.01) return '<0.01';
  return p.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}

String normalizeMobile(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 10) return '+91$digits';
  if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
  return '+$digits';
}

String onlyDigits(String s, [int? max]) {
  final d = s.replaceAll(RegExp(r'\D'), '');
  return max != null && d.length > max ? d.substring(0, max) : d;
}

String fmtDurationClock(int secs) {
  final h = secs ~/ 3600;
  final m = (secs % 3600) ~/ 60;
  final s = secs % 60;
  return [h, m, s].map((v) => v.toString().padLeft(2, '0')).join(':');
}

/// Decodes `data:image/...;base64,XXXX` strings (ads are stored this way).
Uint8List? decodeDataUrl(String? src) {
  if (src == null || !src.startsWith('data:')) return null;
  final i = src.indexOf(',');
  if (i < 0) return null;
  try {
    return base64Decode(src.substring(i + 1));
  } catch (_) {
    return null;
  }
}

Future<void> openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

String mapsUrl(double lat, double lng) => 'https://maps.google.com/?q=$lat,$lng';
