import 'package:flutter_test/flutter_test.dart';
import 'package:chumian_app/core/api.dart';
import 'package:chumian_app/models/models.dart';

void main() {
  group('官网数据兼容', () {
    test('详情使用 my_reactions 与数值 resume', () {
      final video = Video.fromJson({'id': 7, 'title': '测试', 'my_reactions': ['like','favorite'], 'likes': 9, 'resume': 125.5, 'disclaimer_label': 'AI生成'});
      expect(video.liked, isTrue); expect(video.favorited, isTrue);
      expect(video.likes, 9); expect(video.resume, 125.5); expect(video.disclaimer, 'AI生成');
    });
    test('评论回复使用 replies 且根 parent_id 保留', () {
      final comment = Comment.fromJson({'id': 12, 'parent_id': 3, 'replies': 4, 'user_id': 9});
      expect(comment.parentId, 3); expect(comment.replyCount, 4); expect(comment.userId, 9);
    });
    test('分页结束与空列表', () {
      final result = PageResult.parse({'items': [], 'total': 0, 'page': 1, 'limit': 20}, Video.fromJson);
      expect(result.hasMore, isFalse); expect(result.items, isEmpty);
    });
    test('弹幕颜色与字号容错', () {
      final row = Danmaku.fromJson({'color': '<script>', 'size': 90, 'time': 1.25});
      expect(row.color, '#FFFFFF'); expect(row.size, 40); expect(row.time, 1.25);
    });
    test('时长显示', () { expect(clock(125), '02:05'); expect(clock(3661), '1:01:01'); expect(clock(-1), '00:00'); });
    test('Unix 日期不是原始秒数', () { expect(displayDate('1700000000'), matches(RegExp(r'^\d{4}-\d{2}-\d{2}$'))); });
  });
  group('地址与凭证边界', () {
    late ApiClient api;
    setUp(() { api = ApiClient(ApiClient.defaultEndpoint); api.token = 'test-token'; });
    tearDown(() => api.dispose());
    test('根相对封面和 bare cover 标识', () {
      expect(api.publicUrl('/happy/covers/a.png'), 'http://103.236.99.177:24512/happy/covers/a.png');
      expect(api.publicUrl('a.png'), 'http://103.236.99.177:24512/happy/covers/a.png');
    });
    test('同源才带 Bearer', () {
      expect(api.mediaHeaders('https://untrusted.example/v.mp4'), isEmpty);
      expect(api.mediaHeaders('http://103.236.99.177:24512/happy/media/1')['Authorization'], 'Bearer test-token');
    });
    test('不能在配置 URL 夹带账号或 token', () {
      expect(() => ApiClient.normalizeEndpoint('https://name:secret@host/api'), throwsA(isA<ApiException>()));
      expect(() => ApiClient.normalizeEndpoint('https://host/api?token=x'), throwsA(isA<ApiException>()));
    });
    test('分享官网 video 查询参数', () { expect(api.pageLink(5), 'http://103.236.99.177:24512/happy/?video=5'); });
  });
}
