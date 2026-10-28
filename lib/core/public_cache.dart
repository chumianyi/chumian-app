import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class PublicCache {
  PublicCache(this.prefs);
  final SharedPreferences prefs;
  static const prefix = 'public_list_cache:';
  static const maxEntries = 12;
  static const ttl = Duration(minutes: 30);
  String key(String endpoint, String feed, String q, int? category, String sort) => '$prefix${Uri.encodeComponent('$endpoint|$feed|$q|$category|$sort')}';
  Json? read(String key) {
    try {
      final value = object(jsonDecode(prefs.getString(key) ?? '{}'));
      final timestamp = integer(value['timestamp']);
      if (DateTime.now().millisecondsSinceEpoch - timestamp > ttl.inMilliseconds) return null;
      return object(value['data']);
    } catch (_) { return null; }
  }
  Future<void> write(String key, PageResult<Video> data) async {
    final safeItems = data.items.map((v) => {
      'id': v.id, 'title': v.title, 'description': v.description, 'category': v.category,
      'category_id': v.categoryId, 'cover': v.cover, 'views': v.views, 'likes': v.likes,
      'disclaimer_label': v.disclaimer, 'created': v.created, 'size': v.size, 'mime': v.mime,
    }).toList();
    await prefs.setString(key, jsonEncode({'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': {'items': safeItems, 'total': data.total, 'page': 1, 'limit': data.limit}}));
    final keys = prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
    keys.sort((a,b) => _timestamp(a).compareTo(_timestamp(b)));
    for (final old in keys.take((keys.length - maxEntries).clamp(0, keys.length))) { await prefs.remove(old); }
  }
  int _timestamp(String key) {
    try { return integer(object(jsonDecode(prefs.getString(key) ?? '{}'))['timestamp']); }
    catch (_) { return 0; }
  }
}
