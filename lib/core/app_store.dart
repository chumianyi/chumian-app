import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'api.dart';

class AppStore extends ChangeNotifier {
  AppStore._(this.prefs, this.secure, this.api);
  final SharedPreferences prefs;
  final FlutterSecureStorage secure;
  ApiClient api;
  Account? user;
  String? sessionError;
  int sessionRevision = 0;
  int _authEpoch = 0;
  bool _disposed = false;
  bool restoring = true;
  String theme = 'system';
  bool autoplay = false, danmakuEnabled = true, reducedMotion = false;
  double speed = 1, danmakuOpacity = .85, danmakuDensity = .6;
  List<String> searchHistory = [];
  Json publicSettings = {};
  static Future<AppStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    const storage = FlutterSecureStorage();
    final store = AppStore._(prefs, storage, ApiClient(prefs.getString('endpoint') ?? ApiClient.defaultEndpoint));
    store.theme = prefs.getString('theme') ?? 'system';
    store.autoplay = prefs.getBool('autoplay') ?? false;
    store.danmakuEnabled = prefs.getBool('danmaku') ?? true;
    store.reducedMotion = prefs.getBool('reducedMotion') ?? false;
    store.speed = prefs.getDouble('speed') ?? 1;
    store.danmakuOpacity = prefs.getDouble('danmakuOpacity') ?? .85;
    store.danmakuDensity = prefs.getDouble('danmakuDensity') ?? .6;
    store.searchHistory = prefs.getStringList('searchHistory') ?? [];
    store._wireApi();
    unawaited(store.restore());
    return store;
  }
  void _wireApi() { api.onUnauthorized = () { unawaited(clearSession()); }; }
  Future<void> restore() async {
    if (restoring && _authEpoch > 0) return;
    final epoch = ++_authEpoch;
    final client = api;
    restoring = true;
    sessionError = null;
    if (!_disposed) notifyListeners();
    try {
      final token = await secure.read(key: 'session_token');
      if (_disposed || epoch != _authEpoch) return;
      client.token = token;
      if (token != null) {
        final result = await client.me();
        if (_disposed || epoch != _authEpoch) return;
        if (result['user'] != null) {
          user = Account.fromJson(object(result['user']));
        } else {
          await clearSession();
        }
      }
    } catch (e) {
      if (!_disposed && epoch == _authEpoch) sessionError = '$e';
      // Network errors do not erase a valid stored session.
    } finally {
      if (!_disposed) { restoring = false; notifyListeners(); }
    }
  }
  Future<void> login(String email, String password) async {
    final epoch = ++_authEpoch;
    final client = api;
    final result = await api.login(email, password);
    if (_disposed || epoch != _authEpoch || api != client) throw const ApiException('登录环境已变更，请重试');
    final token = string(result['token']);
    if (token.isEmpty || result['user'] == null) throw const ApiException('登录响应不完整，请联系站点维护者');
    await secure.write(key: 'session_token', value: token);
    api.token = token;
    user = Account.fromJson(object(result['user']));
    sessionError = null;
    sessionRevision++;
    if (!_disposed) notifyListeners();
  }
  Future<void> clearSession() async {
    _authEpoch++;
    api.token = null;
    user = null;
    sessionRevision++;
    notifyListeners();
    await secure.delete(key: 'session_token');
  }
  Future<void> logout() async {
    // If offline, do not pretend that the server session was revoked.
    await api.logout();
    await clearSession();
  }
  Future<void> setEndpoint(String value) async {
    final normalized = ApiClient.normalizeEndpoint(value);
    if (normalized == api.endpoint) return;
    await clearSession();
    api.dispose();
    api = ApiClient(normalized);
    _wireApi();
    publicSettings = {};
    await prefs.setString('endpoint', normalized);
    sessionRevision++;
    notifyListeners();
  }
  Future<void> loadSettings() async {
    publicSettings = await api.settings();
    notifyListeners();
  }
  Future<void> rememberSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    searchHistory = [q, ...searchHistory.where((s) => s != q)].take(15).toList();
    await prefs.setStringList('searchHistory', searchHistory);
    notifyListeners();
  }
  Future<void> clearSearchHistory() async {
    searchHistory = [];
    await prefs.remove('searchHistory');
    notifyListeners();
  }
  Future<void> savePreferences() async {
    await prefs.setString('theme', theme);
    await prefs.setBool('autoplay', autoplay);
    await prefs.setBool('danmaku', danmakuEnabled);
    await prefs.setBool('reducedMotion', reducedMotion);
    await prefs.setDouble('speed', speed);
    await prefs.setDouble('danmakuOpacity', danmakuOpacity);
    await prefs.setDouble('danmakuDensity', danmakuDensity);
    notifyListeners();
  }
  String get _resumeKey => 'local_resume_${Uri.encodeComponent(api.endpoint)}_${user?.id ?? 'guest'}';
  Json get localResume {
    try { return object(jsonDecode(prefs.getString(_resumeKey) ?? '{}')); }
    catch (_) { return {}; }
  }
  double resumePosition(int id) => decimal(object(localResume['$id'])['position']);
  Future<void> saveLocalResume(int id, double position, double duration) async {
    final key = _resumeKey;
    final entries = localResume;
    entries['$id'] = {'position': position, 'duration': duration, 'updated': DateTime.now().millisecondsSinceEpoch};
    if (entries.length > 100) {
      final keys = entries.keys.toList()..sort((a,b) => integer(object(entries[a])['updated']).compareTo(integer(object(entries[b])['updated'])));
      for (final key in keys.take(entries.length - 100)) { entries.remove(key); }
    }
    await prefs.setString(key, jsonEncode(entries));
  }
  @override
  void dispose() { _disposed = true; _authEpoch++; api.dispose(); super.dispose(); }
}
