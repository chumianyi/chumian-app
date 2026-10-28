import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import '../../core/app_store.dart';
import '../../models/models.dart';
import '../../ui/common.dart';
import '../account/auth_page.dart';
import '../account/settings_page.dart';
import 'search_page.dart';
import 'video_list.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store});
  final AppStore store;
  @override
  State<HomeShell> createState() => _HomeShellState();
}
class _HomeShellState extends State<HomeShell> {
  int index = 0;
  static const titles = ['发现','分类','排行','我的'];
  static const icons = [Icons.explore_outlined, Icons.grid_view_rounded, Icons.leaderboard_outlined, Icons.person_outline_rounded];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(index == 0 ? '初眠动漫' : titles[index]), actions: [
      IconButton(tooltip: '搜索名称或简介', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchPage(store: widget.store))), icon: const Icon(Icons.search_rounded)),
      if (index == 3) IconButton(tooltip: '设置', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage(store: widget.store))), icon: const Icon(Icons.settings_outlined)),
    ]),
    body: SafeArea(top: false, bottom: false, child: IndexedStack(index: index, children: [
      DiscoverPage(store: widget.store), CategoriesPage(store: widget.store),
      VideoList(store: widget.store, feed: 'ranking', sort: 'popular', ranking: true,
        header: const Padding(padding: EdgeInsets.all(22), child: SectionTitle('正在被看见', subtitle: '按站点去重观看次数排序'))),
      ProfilePage(store: widget.store),
    ])),
    bottomNavigationBar: MiuixNavigationBar(children: [for (int i = 0; i < 4; i++)
      MiuixNavigationBarItem(selected: index == i, onPressed: () => setState(() => index = i), icon: Icon(icons[i]), label: titles[i])]),
  );
}
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key, required this.store});
  final AppStore store;
  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}
class _DiscoverPageState extends State<DiscoverPage> {
  String feed = 'recommended';
  String? settingsError;
  @override
  void initState() { super.initState(); loadSettings(); }
  Future<void> loadSettings() async {
    try { await widget.store.loadSettings(); if (mounted) setState(() => settingsError = null); }
    catch (e) { if (mounted) setState(() => settingsError = '$e'); }
  }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: widget.store, builder: (_,__) => VideoList(store: widget.store, feed: feed,
    header: Padding(padding: const EdgeInsets.fromLTRB(18, 10, 18, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(borderRadius: BorderRadius.circular(26), child: SizedBox(height: 195, child: Stack(fit: StackFit.expand, children: [
        Image.asset('assets/images/night_journey.png', fit: BoxFit.cover),
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xBB10102F), Colors.transparent]))),
        const Padding(padding: EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('把故事\n留给今晚', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.3, color: Colors.white)),
          SizedBox(height: 12), Text('初眠 · 每一次相遇都有回响', style: TextStyle(color: Color(0xFFDCD8FA), fontSize: 12)),
        ])),
      ]))),
      const SizedBox(height: 14), MiuixCard(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SearchPage(store: widget.store))),
        child: const Row(children: [Icon(Icons.search_rounded, color: brandColor), SizedBox(width: 12), Expanded(child: Text('寻找一个喜欢的故事…')), Icon(Icons.chevron_right)])),
      if (string(widget.store.publicSettings['announcement']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 14), child: MiuixCard(
        onPressed: () => openInformation(context, '站点公告', string(widget.store.publicSettings['announcement'])),
        child: Row(children: [const Icon(Icons.campaign_outlined, size: 20, color: brandColor), const SizedBox(width: 10), Expanded(child: Text(string(widget.store.publicSettings['announcement']), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)))]))),
      if (settingsError != null) TextButton(onPressed: loadSettings, child: const Text('公告加载失败，点此重试')),
      SectionTitle(feed == 'recommended' ? '为你发现' : '新故事抵达', subtitle: feed == 'recommended' ? '站点精选推荐 · 非个性化算法' : '按最新上架时间排列'),
      Wrap(spacing: 10, children: [ChoiceChip(label: const Text('精选推荐'), selected: feed == 'recommended', onSelected: (_) => setState(() => feed = 'recommended')),
        ChoiceChip(label: const Text('全部 / 最新'), selected: feed == 'all', onSelected: (_) => setState(() => feed = 'all'))]),
    ]))));
}
class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key, required this.store});
  final AppStore store;
  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}
class _CategoriesPageState extends State<CategoriesPage> {
  List<Category> rows = [];
  bool busy = true;
  String? error;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async { setState(() { busy = true; error = null; }); try {
    final result = await widget.store.api.categories(); if (mounted) setState(() => rows = result);
  } catch (e) { if (mounted) setState(() => error = '$e'); } finally { if (mounted) setState(() => busy = false); } }
  @override
  Widget build(BuildContext context) => RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(18), physics: const AlwaysScrollableScrollPhysics(), children: [
    const SectionTitle('按心情找故事', subtitle: '全部分类来自当前站点'),
    if (busy) const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator()))
    else if (error != null) StatePanel(title: '分类加载失败', message: error!, onRetry: load)
    else ...rows.asMap().entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 12), child: MiuixCard(onPressed: () => Navigator.push(context,
      MaterialPageRoute(builder: (_) => PageFrame(title: e.value.name, child: VideoList(store: widget.store, category: e.value.id)))),
      child: Row(children: [Container(width: 56, height: 56, decoration: BoxDecoration(color: brandColor.withValues(alpha: .08 + e.key % 3 * .04), borderRadius: BorderRadius.circular(18)), child: Icon([Icons.auto_awesome, Icons.local_florist_outlined, Icons.movie_filter_outlined, Icons.brush_outlined, Icons.apps_rounded][e.key % 5], color: brandColor)),
        const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(e.value.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)), Text('${e.value.count} 部动画', style: Theme.of(context).textTheme.bodySmall)])), const Icon(Icons.chevron_right)])))),
    if (!busy && error == null && rows.isEmpty) const StatePanel(title: '暂无分类', message: '站点创建分类后会在此展示。'),
  ]));
}
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.store});
  final AppStore store;
  Future<void> library(BuildContext context, String feed, String title) async {
    if (!await requireLogin(context, store) || !context.mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AnimatedBuilder(animation: store, builder: (_,__) =>
      PageFrame(title: title, child: store.user == null ? StatePanel(title: '请先登录', message: '会话已结束，登录后查看账户内容。', retryLabel: '去登录', onRetry: () => requireLogin(context, store)) : VideoList(store: store, feed: feed)))));
  }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: store, builder: (_,__) => ListView(padding: const EdgeInsets.all(18), children: [
    const SizedBox(height: 10), MiuixCard(child: Row(children: [CircleAvatar(radius: 32, backgroundColor: brandColor.withValues(alpha: .12),
      child: Text(store.user == null ? '眠' : store.user!.nickname.characters.first, style: const TextStyle(fontSize: 27, color: brandColor))),
      const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(store.user?.nickname ?? '今晚，也有好故事', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6), Text(store.user?.email ?? '登录同步收藏与观看进度', style: Theme.of(context).textTheme.bodySmall)]))])),
    if (store.restoring) const LinearProgressIndicator(),
    if (store.sessionError != null) TextButton(onPressed: store.restore, child: const Text('会话恢复失败，点此重试')),
    if (store.user == null) Padding(padding: const EdgeInsets.only(top: 16), child: ActionButton('登录 / 注册', onPressed: () => requireLogin(context, store), icon: Icons.login)),
    const SectionTitle('我的故事'), MiuixCard(child: Column(children: [
      ListTile(leading: const Icon(Icons.bookmark_border_rounded, color: brandColor), title: const Text('我的收藏'), subtitle: const Text('喜欢的动画，随时再见'), trailing: const Icon(Icons.chevron_right), onTap: () => library(context, 'favorite', '我的收藏')),
      ListTile(leading: const Icon(Icons.history_rounded, color: brandColor), title: const Text('观看历史'), subtitle: const Text('从上次停下的地方继续'), trailing: const Icon(Icons.chevron_right), onTap: () => library(context, 'history', '观看历史')),
    ])), const SectionTitle('陪你看得更舒服'), MiuixCard(child: Column(children: [
      ListTile(leading: const Icon(Icons.tune_rounded), title: const Text('设置与播放偏好'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage(store: store)))),
      ListTile(leading: const Icon(Icons.help_outline), title: const Text('使用帮助'), trailing: const Icon(Icons.chevron_right), onTap: () => openInformation(context, '使用帮助', helpText)),
      ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: const Text('数据与隐私说明'), trailing: const Icon(Icons.chevron_right), onTap: () => openInformation(context, '数据与隐私说明', privacyText)),
    ])),
    if (store.user != null) Padding(padding: const EdgeInsets.only(top: 24), child: ActionButton('退出当前账户', onPressed: () async {
      if (!await confirm(context, '退出登录', '将撤销当前会话，收藏和历史仍保留在账户中。')) return;
      try { await store.logout(); } catch (e) { if (context.mounted) notice(context, '退出失败：$e。服务端会话尚未撤销。'); }
    })), const SizedBox(height: 30), const Center(child: Text('初眠动漫 · 为故事留一盏灯', style: TextStyle(fontSize: 12, color: Colors.grey))), const SizedBox(height: 20),
  ]));
}
