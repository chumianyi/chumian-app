import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/app_store.dart';
import '../../core/api.dart';
import '../../core/public_cache.dart';
import '../../models/models.dart';
import '../../ui/common.dart';
import '../player/video_page.dart';

class VideoList extends StatefulWidget {
  const VideoList({super.key, required this.store, this.feed = 'all', this.query = '', this.category,
    this.sort = 'new', this.header, this.ranking = false, this.embedded = false});
  final AppStore store;
  final String feed, query, sort;
  final int? category;
  final Widget? header;
  final bool ranking, embedded;
  @override
  State<VideoList> createState() => _VideoListState();
}
class _VideoListState extends State<VideoList> {
  List<Video> items = [];
  bool loading = false, hasMore = true;
  bool cached = false;
  int page = 0, generation = 0;
  String? error;
  CancelToken? cancel;
  int get session => widget.store.sessionRevision;
  late int lastSession;
  @override
  void initState() { super.initState(); lastSession = session; widget.store.addListener(storeChanged); load(reset: true); }
  void storeChanged() {
    if (lastSession != session) { lastSession = session; load(reset: true); }
  }
  @override
  void didUpdateWidget(VideoList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feed != widget.feed || oldWidget.query != widget.query || oldWidget.category != widget.category || oldWidget.sort != widget.sort) load(reset: true);
  }
  Future<void> load({bool reset = false}) async {
    if (reset) { generation++; cancel?.cancel(); }
    else if (loading || !hasMore) { return; }
    final stamp = generation;
    final cache = PublicCache(widget.store.prefs);
    final cacheKey = cache.key(widget.store.api.endpoint, widget.feed, widget.query, widget.category, widget.sort);
    final allowCache = ['all', 'recommended', 'ranking'].contains(widget.feed);
    cancel = CancelToken();
    setState(() { loading = true; error = null; if (reset) { items = []; page = 0; hasMore = true; cached = false; } });
    try {
      final result = await widget.store.api.videos(feed: widget.feed, q: widget.query,
        category: widget.category, sort: widget.sort, page: reset ? 1 : page + 1, cancelToken: cancel);
      if (!mounted || stamp != generation) return;
      setState(() {
        final seen = items.map((v) => v.id).toSet();
        items = [...items, ...result.items.where((v) => seen.add(v.id))];
        page = result.page; hasMore = result.hasMore && result.items.isNotEmpty;
      });
      if (reset && allowCache) { try { await cache.write(cacheKey, result); } catch (_) { /* Cache failure does not invalidate a network success. */ } }
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      if (mounted && stamp == generation) setState(() {
        error = '$e';
        if (reset && allowCache && e is ApiException && (e.status == null || e.status! >= 500)) {
          final value = cache.read(cacheKey);
          if (value != null) { items = PageResult.parse(value, Video.fromJson).items; cached = true; hasMore = false; }
        }
      });
    } finally { if (mounted && stamp == generation) setState(() => loading = false); }
  }
  @override
  void dispose() { generation++; cancel?.cancel(); widget.store.removeListener(storeChanged); super.dispose(); }
  void open(Video v) => Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPage(store: widget.store, videoId: v.id))).then((_) {
    if (mounted && ['favorite','history'].contains(widget.feed)) load(reset: true);
  });
  @override
  Widget build(BuildContext context) {
    final columns = MediaQuery.sizeOf(context).width >= 900 ? 4 : MediaQuery.sizeOf(context).width >= 600 ? 3 : 2;
    final slivers = <Widget>[
      if (widget.header != null) SliverToBoxAdapter(child: widget.header),
      if (cached) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(18), child: Text('网络暂不可用，以下是 30 分钟内的公开列表缓存。播放仍需联网。', style: TextStyle(fontSize: 12, color: Colors.orange)))),
      if (items.isEmpty && loading) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator()))),
      if (items.isEmpty && !loading) SliverToBoxAdapter(child: StatePanel(
        title: error != null ? '暂时没能加载' : widget.query.isNotEmpty ? '没有找到相关动画' : '这里还没有内容',
        message: error ?? (widget.query.isNotEmpty ? '试试更短的关键词，或换一个分类。' : widget.feed == 'favorite' ? '在详情页收藏喜欢的动画，它们就会出现在这里。' : widget.feed == 'history' ? '登录后观看，进度会同步到观看历史。' : '站点暂未上架动画，稍后回来看看吧。'),
        icon: error != null ? Icons.wifi_off_rounded : widget.query.isNotEmpty ? Icons.search_off_rounded : Icons.movie_outlined,
        onRetry: () => load(reset: true))),
      if (items.isNotEmpty && widget.ranking) SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 18),
        sliver: SliverList.separated(itemCount: items.length, separatorBuilder: (_,__) => const SizedBox(height: 10),
          itemBuilder: (_,i) => VideoTile(video: items[i], store: widget.store, rank: i + 1, onTap: () => open(items[i])))),
      if (items.isNotEmpty && !widget.ranking) SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 18),
        sliver: SliverGrid.builder(itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisExtent: 205 + MediaQuery.textScalerOf(context).scale(20), mainAxisSpacing: 12, crossAxisSpacing: 12),
          itemBuilder: (_,i) => VideoTile(video: items[i], store: widget.store, onTap: () => open(items[i])))),
      if (items.isNotEmpty) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(24), child: Center(child:
        loading ? const CircularProgressIndicator() : error != null ? Column(children: [Text(error!, textAlign: TextAlign.center), const SizedBox(height: 10), ActionButton('重试加载', onPressed: () => load(reset: cached))])
        : hasMore ? ActionButton('加载更多', onPressed: () => load()) : const Text('已经看到最后了', style: TextStyle(color: Colors.grey))))),
      const SliverToBoxAdapter(child: SizedBox(height: 20)),
    ];
    return RefreshIndicator(onRefresh: () => load(reset: true), child: NotificationListener<ScrollNotification>(
      onNotification: (n) { if (n.metrics.extentAfter < 400 && !loading && error == null && hasMore && items.isNotEmpty) load(); return false; },
      child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: slivers)));
  }
}
