import 'package:dio/dio.dart';
import '../models/models.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.status, this.retryAfter});
  final String message;
  final int? status, retryAfter;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(String endpoint) : _endpoint = normalizeEndpoint(endpoint) {
    dio = Dio(BaseOptions(baseUrl: _endpoint,
      connectTimeout: const Duration(seconds: 12), receiveTimeout: const Duration(seconds: 25),
      sendTimeout: const Duration(seconds: 20), followRedirects: false,
      headers: {'Accept': 'application/json', 'Content-Type': 'application/json'}));
  }
  static const defaultEndpoint = 'http://103.236.99.177:24512/happy/api';
  final String _endpoint;
  late final Dio dio;
  String? token;
  void Function()? onUnauthorized;
  String get endpoint => _endpoint;
  bool get insecure => Uri.parse(_endpoint).scheme == 'http';
  static String normalizeEndpoint(String value) {
    final u = Uri.tryParse(value.trim());
    if (u == null || !['http', 'https'].contains(u.scheme) || u.host.isEmpty ||
        u.userInfo.isNotEmpty || u.hasQuery || u.hasFragment) {
      throw const ApiException('请输入完整 HTTP 或 HTTPS API 地址，不含账号、参数或片段');
    }
    return value.trim().replaceAll(RegExp(r'/+$'), '');
  }
  String publicUrl(String value) {
    if (value.isEmpty) return '';
    final base = Uri.parse(_endpoint);
    final input = Uri.tryParse(value);
    if (input == null) return '';
    if (input.hasScheme) return ['http', 'https'].contains(input.scheme) ? input.toString() : '';
    if (value.startsWith('/')) return base.resolve(value).toString();
    // Bare cover identifiers live under /happy/covers, not /happy/api.
    final appPath = base.path.replaceFirst(RegExp(r'/api$'), '');
    return base.replace(path: '$appPath/covers/$value').toString();
  }
  String playbackUrl(String value) {
    final u = Uri.parse(_endpoint).resolve(value);
    if (!['http', 'https'].contains(u.scheme)) throw const ApiException('播放地址协议不受支持');
    return u.toString();
  }
  String pageLink(int id) {
    final base = Uri.parse(_endpoint);
    final path = base.path.replaceFirst(RegExp(r'/api$'), '');
    return base.replace(path: '$path/', queryParameters: {'video': '$id'}).toString();
  }
  Map<String, String> mediaHeaders(String url) {
    final u = Uri.parse(url), b = Uri.parse(_endpoint);
    // Do not disclose Bearer tokens to a third-party playback host.
    return token != null && u.origin == b.origin ? {'Authorization': 'Bearer $token'} : {};
  }
  Future<dynamic> request(String method, String path, {Json? data, Json? query, CancelToken? cancelToken}) async {
    final requestToken = token;
    try {
      final result = await dio.request<dynamic>(path, data: data, queryParameters: query,
        cancelToken: cancelToken,
        options: Options(method: method, headers: requestToken == null ? {} : {'Authorization': 'Bearer $requestToken'}));
      final envelope = object(result.data);
      if (envelope['ok'] != true) throw ApiException(string(envelope['error'], '服务暂时不可用'), status: result.statusCode);
      return envelope['data'];
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      final status = e.response?.statusCode;
      if (status == 401 && requestToken != null && token == requestToken) onUnauthorized?.call();
      final serverMessage = object(e.response?.data)['error'];
      final fallback = switch (status) {
        401 => '请重新登录后继续', 403 => '无访问权限，内容可能已下架或账户已受限',
        404 => '内容不存在或已下架', 429 => '请求过于频繁，请稍后重试',
        _ => switch (e.type) {
          DioExceptionType.connectionTimeout || DioExceptionType.receiveTimeout || DioExceptionType.sendTimeout => '连接超时，请检查网络后重试',
          DioExceptionType.connectionError => '无法连接服务器，请检查网络或服务地址',
          _ => '服务暂时不可用，请稍后重试',
        },
      };
      throw ApiException(string(serverMessage, fallback), status: status,
        retryAfter: int.tryParse(e.response?.headers.value('retry-after') ?? ''));
    }
  }
  Future<Json> me() async => object(await request('GET', '/auth/me'));
  Future<Json> settings() async => object(await request('GET', '/settings'));
  Future<List<Category>> categories() async {
    final result = await request('GET', '/categories');
    return (result is List ? result : <dynamic>[]).map((e) => Category.fromJson(object(e))).toList();
  }
  Future<PageResult<Video>> videos({String feed = 'all', String q = '', int? category,
      String sort = 'new', int page = 1, int limit = 20, CancelToken? cancelToken}) async {
    return PageResult.parse(await request('GET', '/videos', query: {
      'feed': feed, if (q.isNotEmpty) 'q': q, if (category != null) 'category': category,
      'sort': sort, 'page': page, 'limit': limit.clamp(1, 100),
    }, cancelToken: cancelToken), Video.fromJson, page: page, limit: limit);
  }
  Future<Video> video(int id) async => Video.fromJson(object(await request('GET', '/videos/$id')));
  Future<Json> playback(int id) async => object(await request('GET', '/videos/$id/playback'));
  Future<Json> login(String email, String password) async => object(await request('POST', '/auth/login', data: {'email': email, 'password': password}));
  Future<void> sendCode(String email, String purpose) async => request('POST', '/auth/send-code', data: {'email': email, 'purpose': purpose});
  Future<void> register(String email, String nickname, String password, String code) async => request('POST', '/auth/register', data: {'email': email, 'nickname': nickname, 'password': password, 'code': code});
  Future<void> resetPassword(String email, String password, String code) async => request('POST', '/auth/reset-password', data: {'email': email, 'password': password, 'code': code});
  Future<void> changePassword(String oldPassword, String password) async => request('POST', '/auth/change-password', data: {'old_password': oldPassword, 'password': password});
  Future<void> logout() async => request('POST', '/auth/logout');
  Future<void> like(int id, bool active) async => request('POST', '/videos/$id/like', data: {'active': active});
  Future<void> favorite(int id, bool active) async => request('POST', '/videos/$id/favorite', data: {'active': active});
  Future<void> history(int id, double position, double duration) async => request('POST', '/videos/$id/history', data: {'position': position, 'duration': duration});
  Future<void> report(int id, String reason) async => request('POST', '/videos/$id/report', data: {'reason': reason});
  Future<PageResult<Comment>> comments(int id, {int page = 1, int? parentId}) async =>
    PageResult.parse(await request('GET', '/videos/$id/comments', query: {'page': page, 'limit': 20, if (parentId != null) 'parent_id': parentId}), Comment.fromJson, page: page);
  Future<void> comment(int id, String text, {int? parentId}) async => request('POST', '/videos/$id/comments', data: {'text': text, if (parentId != null) 'parent_id': parentId});
  Future<void> deleteComment(int id) async => request('DELETE', '/comments/$id');
  Future<List<Danmaku>> danmaku(int id, double from, double to) async {
    final end = to.clamp(from, from + 600);
    final data = await request('GET', '/videos/$id/danmaku', query: {'from': from, 'to': end});
    final rows = data is List ? data : object(data)['items'];
    return (rows is List ? rows : <dynamic>[]).map((e) => Danmaku.fromJson(object(e))).toList();
  }
  Future<void> sendDanmaku(int id, {required String text, required double time,
      required String color, required int size, required String mode}) async => request('POST', '/videos/$id/danmaku',
    data: {'text': text, 'time': time, 'color': color, 'size': size.clamp(16, 40), 'mode': mode});
  void dispose() => dio.close(force: true);
}
