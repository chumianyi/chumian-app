typedef Json = Map<String, dynamic>;

Json object(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
int integer(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse('$v') ?? fallback;
double decimal(dynamic v, [double fallback = 0]) => v is num ? v.toDouble() : double.tryParse('$v') ?? fallback;
bool flag(dynamic v) => v == true || v == 1;
String string(dynamic v, [String fallback = '']) => v == null ? fallback : '$v';

class Account {
  const Account({required this.id, required this.nickname, required this.email});
  final int id;
  final String nickname, email;
  factory Account.fromJson(Json j) => Account(id: integer(j['id']), nickname: string(j['nickname'], '初眠观众'), email: string(j['email']));
}

class Category {
  const Category({required this.id, required this.name, required this.count});
  final int id, count;
  final String name;
  factory Category.fromJson(Json j) => Category(id: integer(j['id']), name: string(j['name']), count: integer(j['count']));
}

class Video {
  const Video({required this.id, required this.title, required this.description,
    required this.category, required this.categoryId, required this.cover,
    required this.views, required this.likes, required this.liked,
    required this.favorited, required this.resume, required this.disclaimer,
    required this.created, required this.size, required this.mime});
  final int id, categoryId, views, likes, size;
  final String title, description, category, cover, disclaimer, created, mime;
  final bool liked, favorited;
  final double resume;
  factory Video.fromJson(Json j) {
    final interaction = object(j['my']);
    final reactions = j['my_reactions'] is List ? j['my_reactions'] as List : const [];
    final resume = j['resume'];
    final disclaimer = string(j['disclaimer_text']).isNotEmpty
        ? string(j['disclaimer_text']) : string(j['disclaimer_label'], '无');
    return Video(id: integer(j['id']), title: string(j['title']),
      description: string(j['description']), category: string(j['category']),
      categoryId: integer(j['category_id']), cover: string(j['cover']),
      views: integer(j['views']), likes: integer(j['likes'] ?? j['like_count']),
      liked: reactions.contains('like') || flag(j['liked'] ?? interaction['liked']),
      favorited: reactions.contains('favorite') || flag(j['favorited'] ?? interaction['favorited']),
      resume: resume is Map ? decimal(resume['position']) : decimal(resume),
      disclaimer: disclaimer, created: string(j['created']),
      size: integer(j['size']), mime: string(j['mime']));
  }
}

class Comment {
  const Comment({required this.id, required this.userId, required this.nickname,
    required this.text, required this.created, required this.parentId, required this.replyCount});
  final int id, userId, replyCount;
  final int? parentId;
  final String nickname, text, created;
  factory Comment.fromJson(Json j) => Comment(id: integer(j['id']),
    userId: integer(j['user_id']), nickname: string(j['nickname'] ?? object(j['user'])['nickname'], '观众'),
    text: string(j['text']), created: string(j['created']),
    parentId: j['parent_id'] == null ? null : integer(j['parent_id']),
    replyCount: integer(j['replies'] ?? j['reply_count'] ?? j['replies_count']));
}

class Danmaku {
  const Danmaku({required this.id, required this.text, required this.time,
    required this.color, required this.size, required this.mode});
  final int id, size;
  final String text, color, mode;
  final double time;
  factory Danmaku.fromJson(Json j) => Danmaku(id: integer(j['id']),
    text: string(j['text']), time: decimal(j['time']),
    color: RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(string(j['color'])) ? string(j['color']) : '#FFFFFF',
    size: integer(j['size'], 25).clamp(16, 40), mode: string(j['mode'], 'scroll'));
}

class PageResult<T> {
  const PageResult(this.items, this.total, this.page, this.limit);
  final List<T> items;
  final int total, page, limit;
  bool get hasMore => page * limit < total;
  factory PageResult.parse(dynamic value, T Function(Json) convert, {int page = 1, int limit = 20}) {
    final j = object(value);
    final raw = value is List ? value : j['items'];
    final rows = raw is List ? raw : <dynamic>[];
    return PageResult(rows.map((e) => convert(object(e))).toList(),
      integer(j['total'], rows.length), integer(j['page'], page), integer(j['limit'], limit));
  }
}

String clock(double seconds) {
  final s = seconds.isFinite ? seconds.floor().clamp(0, 359999) : 0;
  final h = s ~/ 3600;
  return '${h > 0 ? '$h:' : ''}${(s ~/ 60 % 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}
String compactCount(int n) => n >= 10000 ? '${(n / 10000).toStringAsFixed(1)}万' : '$n';
String displayDate(String value) {
  final seconds = double.tryParse(value);
  final date = seconds != null ? DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round()) : DateTime.tryParse(value);
  if (date == null) return '';
  final local = date.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}
