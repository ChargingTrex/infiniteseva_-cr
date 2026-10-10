import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../strings.dart';

class AppUser {
  final int id;
  final String name;
  final String? mobile;
  final String? role;

  const AppUser({required this.id, required this.name, this.mobile, this.role});

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: int.parse(j['id'].toString()),
        name: (j['name'] ?? '').toString(),
        mobile: j['mobile']?.toString(),
        role: j['role']?.toString(),
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'mobile': mobile, 'role': role};

  bool get isAdmin =>
      role == 'ADMIN' || role == 'SUPER_ADMIN' || role == 'CAMPAIGN_MANAGER';
}

/// Holds the logged-in user (replaces the web app's localStorage helper) and the
/// current language (replaces LanguageContext).
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  static const _userKey = 'currentUser';
  static const _langKey = 'app_language';

  AppUser? user;
  String language = 'en';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    language = prefs.getString(_langKey) ?? 'en';
    final raw = prefs.getString(_userKey);
    if (raw != null) {
      try {
        user = AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        user = null;
      }
    }
  }

  Future<void> saveUser(AppUser u) async {
    user = u;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(u.toJson()));
    notifyListeners();
  }

  Future<void> clearUser() async {
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    notifyListeners();
  }

  Future<void> toggleLanguage() async {
    language = language == 'en' ? 'ta' : 'en';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, language);
    notifyListeners();
  }

  bool get isTamil => language == 'ta';

  String t(String key) =>
      (language == 'ta' ? ta[key] : en[key]) ?? en[key] ?? key;
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!.notifier!;
  }
}

extension AppContext on BuildContext {
  /// Call from build() so the widget rebuilds on language / user change.
  AppState get app => AppScope.of(this);
}
