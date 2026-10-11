import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../util.dart';

class ApiException implements Exception {
  final String message;
  final String? code;
  final int? status;
  ApiException(this.message, {this.code, this.status});

  /// No internet, a timeout or a server-side failure: the same request may
  /// succeed later. Anything else (4xx) is a rejection that retrying won't fix.
  bool get isTransient =>
      code == 'NETWORK' ||
      code == 'TIMEOUT' ||
      status == 408 ||
      status == 429 ||
      (status ?? 0) >= 500;

  @override
  String toString() => message;
}

class Ad {
  final int id;
  final String position;
  final String? title;
  final String? imageUrl;
  final String? mobileImageUrl;
  final String? linkUrl;
  final int displayOrder;
  final bool isActive;

  const Ad({
    required this.id,
    required this.position,
    this.title,
    this.imageUrl,
    this.mobileImageUrl,
    this.linkUrl,
    this.displayOrder = 0,
    this.isActive = true,
  });

  factory Ad.fromJson(Map<String, dynamic> j) => Ad(
        id: int.parse(j['id'].toString()),
        position: (j['position'] ?? 'LEFT').toString(),
        title: j['title']?.toString(),
        imageUrl: _nonEmpty(j['image_url']),
        mobileImageUrl: _nonEmpty(j['mobile_image_url']),
        linkUrl: _nonEmpty(j['link_url']),
        displayOrder: int.tryParse((j['display_order'] ?? 0).toString()) ?? 0,
        isActive: j['is_active'] == null
            ? true
            : (j['is_active'] == 1 || j['is_active'] == true),
      );

  static String? _nonEmpty(dynamic v) {
    final s = v?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }
}

class Api {
  Api._();
  static final Api instance = Api._();

  static const _timeout = Duration(seconds: 60);

  // ───────────────────────── core ─────────────────────────
  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}$path');
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?headers,
    };

    http.Response res;
    try {
      switch (method) {
        case 'POST':
          res = await http.post(uri, headers: h, body: jsonEncode(body ?? {})).timeout(_timeout);
          break;
        case 'PUT':
          res = await http.put(uri, headers: h, body: jsonEncode(body ?? {})).timeout(_timeout);
          break;
        case 'DELETE':
          res = await http.delete(uri, headers: h).timeout(_timeout);
          break;
        default:
          res = await http.get(uri, headers: h).timeout(_timeout);
      }
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.', code: 'TIMEOUT');
    } catch (_) {
      throw ApiException('Network error. Check your internet connection.', code: 'NETWORK');
    }

    dynamic decoded;
    try {
      decoded = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      decoded = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (decoded is Map && decoded.containsKey('data')) return decoded['data'];
      return decoded;
    }

    var msg = 'Request failed (${res.statusCode})';
    String? code;
    if (decoded is Map) {
      msg = decoded['message']?.toString() ?? msg;
      final err = decoded['error'];
      if (err is Map) code = err['code']?.toString();
    }
    throw ApiException(msg, code: code, status: res.statusCode);
  }

  Map<String, dynamic> _map(dynamic v) => Map<String, dynamic>.from(v as Map);

  // ───────────────────────── auth ─────────────────────────
  Future<bool> userExists(String mobile) async {
    final d = _map(await _send('POST', '/auth/check-user', body: {'mobile': mobile}));
    return d['exists'] == true;
  }

  Future<Map<String, dynamic>> verifyPassword(String mobile, String password) async {
    final d = _map(await _send('POST', '/auth/verify-password',
        body: {'mobile': mobile, 'password': password}));
    return _map(d['user']);
  }

  /// Creates the account if it doesn't exist (backend behaviour).
  Future<Map<String, dynamic>> login(String name, String mobile, String password) async {
    final d = _map(await _send('POST', '/auth/login',
        body: {'name': name, 'mobile': mobile, 'password': password}));
    return _map(d['user']);
  }

  // ───────────────────────── dashboards ─────────────────────────
  Future<Map<String, dynamic>> publicDashboard(int campaignId) async =>
      _map(await _send('GET', '/campaigns/$campaignId/dashboard'));

  Future<Map<String, dynamic>> myDashboard(int userId) async =>
      _map(await _send('GET', '/users/$userId/dashboard'));

  Future<List<Map<String, dynamic>>> myHistory(int userId) async {
    final d = await _send('GET', '/users/$userId/recitations');
    return (d as List).map((e) => _map(e)).toList();
  }

  // ───────────────────────── recitation ─────────────────────────
  Future<Map<String, dynamic>> submitRecitation({
    required int userId,
    required String idempotencyKey,
    required Map<String, dynamic> payload,
  }) async {
    final body = {'userId': userId.toString(), ...payload};
    final d = await _send(
      'POST',
      '/campaigns/${AppConfig.campaignId}/batches/${AppConfig.batchNumber}/recitations',
      body: body,
      headers: {'Idempotency-Key': idempotencyKey},
    );
    return _map(d);
  }

  String photoUrl(int recitationId) => '${AppConfig.baseUrl}/recitations/$recitationId/photo';

  // ───────────────────────── ads ─────────────────────────
  Future<List<Ad>> activeAds() async {
    final d = await _send('GET', '/ads/active');
    return (d as List).map((e) => Ad.fromJson(_map(e))).toList();
  }

  Future<List<Ad>> allAds() async {
    final d = await _send('GET', '/admin/ads');
    return (d as List).map((e) => Ad.fromJson(_map(e))).toList();
  }

  Future<void> createAd(Map<String, dynamic> payload) =>
      _send('POST', '/admin/ads', body: payload);

  Future<void> updateAd(int id, Map<String, dynamic> payload) =>
      _send('PUT', '/admin/ads/$id', body: payload);

  Future<void> deleteAd(int id) => _send('DELETE', '/admin/ads/$id');
}

// Convenience re-export so pages only import api.dart for helpers they need.
String formatMobileForApi(String raw) => normalizeMobile(raw);
