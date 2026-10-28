import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';
import '../../core/app_store.dart';
import '../../models/models.dart';
import '../../ui/common.dart';
import '../account/auth_page.dart';
import '../comments/comments_view.dart';
import 'playback_controller.dart';
import 'player_view.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({super.key, required this.store, required this.videoId});
  final AppStore store;
  final int videoId;
  @override
  State<VideoPage> createState() => _VideoPageState();
}
class _VideoPageState extends State<VideoPage> with WidgetsBindingObserver {
  Video? data;
  PlaybackController? playback;
  bool busy = true, reactionBusy = false;
  bool liked = false, favorited = false;
  int likes = 0;
  String? error;
  final dmDraft = TextEditingController(), reportDraft = TextEditingController();
  String dmColor = '#FFFFFF', dmMode = 'scroll';
  int dmSize = 25;
  late int session;
  @override
  void initState() { super.initState(); session = widget.store.sessionRevision; widget.store.addListener(sessionChanged); WidgetsBinding.instance.addObserver(this); load(); }
  void sessionChanged() {
    if (session == widget.store.sessionRevision) return;
    session = widget.store.sessionRevision;
    if (widget.store.user == null) { if (mounted) setState(() { liked = false; favorited = false; }); return; }
    final stamp = session;
    widget.store.api.video(widget.videoId).then((v) {
      if (mounted && stamp == session) setState(() { liked = v.liked; favorited = v.favorited; likes = v.likes; });
    }).catchError((Object _) { });
  }
  Future<void> load() async {
    setState(() { busy = true; error = null; });
    try {
      final v = await widget.store.api.video(widget.videoId);
      if (!mounted) return;
      playback?.dispose();
      playback = PlaybackController(widget.store, v.id, v.resume);
      setState(() { data = v; liked = v.liked; favorited = v.favorited; likes = v.likes; });
      if (widget.store.autoplay) unawaited(playback!.open());
    } catch (e) { if (mounted) setState(() => error = '$e'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { if (state != AppLifecycleState.resumed) unawaited(playback?.pause()); }
  Future<void> reaction(bool favorite) async {
    if (reactionBusy) return;
    if (!await requireLogin(context, widget.store) || !mounted) return;
    setState(() => reactionBusy = true);
    try {
      // Refresh after login because reactions are account-specific.
      final current = await widget.store.api.video(widget.videoId);
      if (favorite) { final active = !current.favorited; await widget.store.api.favorite(widget.videoId, active); if (mounted) setState(() => favorited = active); }
      else { final active = !current.liked; await widget.store.api.like(widget.videoId, active); if (mounted) setState(() { liked = active; likes = (current.likes + (active ? 1 : -1)).clamp(0, 1 << 31); }); }
    } catch (e) { if (mounted) notice(context, '$e'); }
    finally { if (mounted) setState(() => reactionBusy = false); }
  }
  Future<void> report() async {
    if (!await requireLogin(context, widget.store) || !mounted) return;
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true,
      builder: (c) => Padding(padding: EdgeInsets.fromLTRB(22, 10, 22, MediaQuery.viewInsetsOf(c).bottom + 24),
        child: SingleChildScrollView(child: SubmitSheet(title: '举报内容', description: '请说明版权、违规或其他具体原因，1–1000 字。',
          draft: reportDraft, limit: 1000, button: '提交举报', submit: (text) => widget.store.api.report(widget.videoId, text)))));
  }
  Future<void> danmaku() async {
    if (!await requireLogin(context, widget.store) || !mounted) return;
    if (!(playback?.initialized ?? false)) { notice(context, '请先开始播放，再发送弹幕'); return; }
    final p = playback!;
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true,
      builder: (c) => StatefulBuilder(builder: (c, update) => Padding(padding: EdgeInsets.fromLTRB(22, 8, 22, MediaQuery.viewInsetsOf(c).bottom + 24),
        child: SingleChildScrollView(child: SubmitSheet(title: '把此刻写进弹幕', description: '将在当前播放位置发送，最多 100 字。', draft: dmDraft, limit: 100, button: '发送弹幕',
          extra: Column(children: [
            Row(children: [const Text('位置模式'), const Spacer(), DropdownButton<String>(value: dmMode,
              items: const [DropdownMenuItem(value: 'scroll', child: Text('滚动')), DropdownMenuItem(value: 'top', child: Text('顶部')), DropdownMenuItem(value: 'bottom', child: Text('底部'))], onChanged: (v) => update(() => dmMode = v ?? 'scroll'))]),
            Row(children: [Text('字号 $dmSize'), Expanded(child: MiuixSlider(value: dmSize.toDouble(), min: 16, max: 40, steps: 23, onValueChanged: (v) => update(() => dmSize = v.round())))]),
            Wrap(spacing: 8, children: ['#FFFFFF','#FF6B81','#FFD166','#82E0AA','#73CFFF','#C5A3FF'].map((color) => InkWell(onTap: () => update(() => dmColor = color),
              child: Container(width: 40, height: 40, decoration: BoxDecoration(color: Color(int.parse('FF${color.substring(1)}', radix: 16)), shape: BoxShape.circle,
                border: Border.all(color: dmColor == color ? brandColor : Colors.grey, width: dmColor == color ? 3 : 1))))).toList()),
            const SizedBox(height: 10), TextButton(onPressed: () async {
              final value = await showDialog<String>(context: c, builder: (_) => HexColorDialog(initial: dmColor));
              if (value != null && c.mounted) update(() => dmColor = value);
            }, child: Text('自定义颜色 $dmColor')),
            if (p.danmakuError != null) TextButton(onPressed: () => p.loadDanmaku(force: true), child: const Text('重新加载弹幕')),
          ]), submit: (text) async {
            await widget.store.api.sendDanmaku(widget.videoId, text: text, time: p.position, color: dmColor, size: dmSize, mode: dmMode);
            await p.loadDanmaku(force: true);
          })))));
  }
  @override
  void dispose() { widget.store.removeListener(sessionChanged); WidgetsBinding.instance.removeObserver(this); playback?.dispose(); dmDraft.dispose(); reportDraft.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(data?.title ?? '视频详情', maxLines: 1, overflow: TextOverflow.ellipsis)),
    body: SafeArea(top: false, child: busy ? const Center(child: CircularProgressIndicator())
      : error != null ? StatePanel(title: '没能打开这个故事', message: error!, onRetry: load)
      : data == null ? const SizedBox.shrink() : ListView(children: [
        PlayerView(controller: playback!), Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(data!.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)), const SizedBox(height: 8),
          Text('${data!.category} · ${compactCount(data!.views)} 次观看 · ${displayDate(data!.created)}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16), AnimatedBuilder(animation: playback!, builder: (_,__) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 8, children: [ActionButton('发弹幕', icon: Icons.subtitles_outlined, onPressed: danmaku),
              ActionButton('刷新链接', icon: Icons.refresh_rounded, busy: playback!.loading, onPressed: () => playback!.open(autoplay: true))]),
            const SizedBox(height: 10), Text('播放链接有效 24 小时并绑定当前 IP；切换网络后需刷新。', style: Theme.of(context).textTheme.bodySmall),
            if (playback!.syncError != null) Text(playback!.syncError!, style: const TextStyle(fontSize: 12, color: Colors.orange)),
            if (playback!.danmakuError != null) Text(playback!.danmakuError!, style: const TextStyle(fontSize: 12, color: Colors.orange)),
          ])),
          const SizedBox(height: 20), Wrap(spacing: 8, runSpacing: 8, children: [
            ActionButton('${liked ? '已点赞' : '点赞'} · $likes', icon: liked ? Icons.favorite : Icons.favorite_border, onPressed: reactionBusy ? null : () => reaction(false)),
            ActionButton(favorited ? '已收藏' : '收藏', icon: favorited ? Icons.bookmark : Icons.bookmark_border, onPressed: reactionBusy ? null : () => reaction(true)),
            ActionButton('复制链接', icon: Icons.link, onPressed: () async { await Clipboard.setData(ClipboardData(text: widget.store.api.pageLink(widget.videoId))); if (mounted) notice(context, '官网页面链接已复制'); }),
            ActionButton('举报', icon: Icons.flag_outlined, onPressed: report),
          ]),
          const SectionTitle('故事简介'), SelectableText(data!.description.isEmpty ? '站点暂未提供简介。' : data!.description),
          const SizedBox(height: 16), MiuixCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.info_outline, size: 20), const SizedBox(width: 10),
            Expanded(child: Text('免责声明：${data!.disclaimer}', style: const TextStyle(fontSize: 13)))])),
          CommentsView(store: widget.store, videoId: widget.videoId), const SizedBox(height: 24),
        ])),
      ])));
}

class SubmitSheet extends StatefulWidget {
  const SubmitSheet({super.key, required this.title, required this.description, required this.draft, required this.limit,
    required this.button, required this.submit, this.extra});
  final String title, description, button;
  final TextEditingController draft;
  final int limit;
  final Future<void> Function(String) submit;
  final Widget? extra;
  @override
  State<SubmitSheet> createState() => _SubmitSheetState();
}
class _SubmitSheetState extends State<SubmitSheet> {
  bool busy = false;
  String? error;
  Future<void> submit() async {
    if (busy) return;
    final text = widget.draft.text.trim();
    if (text.isEmpty || text.runes.length > widget.limit) { setState(() => error = '请输入 1–${widget.limit} 字'); return; }
    setState(() { busy = true; error = null; });
    try { await widget.submit(text); if (mounted) { widget.draft.clear(); notice(context, '已提交'); Navigator.pop(context); } }
    catch (e) { if (mounted) setState(() => error = '$e'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(widget.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)), const SizedBox(height: 8), Text(widget.description), const SizedBox(height: 16),
    MiuixTextField(controller: widget.draft, label: '输入文字…', minLines: 2, maxLines: 4, enabled: !busy),
    if (widget.extra != null) widget.extra!,
    if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
    const SizedBox(height: 16), ActionButton(widget.button, busy: busy, onPressed: submit),
  ]);
}
class HexColorDialog extends StatefulWidget {
  const HexColorDialog({super.key, required this.initial});
  final String initial;
  @override
  State<HexColorDialog> createState() => _HexColorDialogState();
}
class _HexColorDialogState extends State<HexColorDialog> {
  late final TextEditingController controller = TextEditingController(text: widget.initial);
  String? error;
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(title: const Text('自定义弹幕颜色'), content: Column(mainAxisSize: MainAxisSize.min, children: [
    MiuixTextField(controller: controller, singleLine: true, label: '#RRGGBB'), if (error != null) Text(error!, style: const TextStyle(color: Colors.red))]),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')), ActionButton('确定', onPressed: () {
      final value = controller.text.trim().toUpperCase();
      if (!RegExp(r'^#[0-9A-F]{6}$').hasMatch(value)) { setState(() => error = '格式应为 #RRGGBB，例如 #FF6B81'); return; }
      Navigator.pop(context, value);
    })]);
}
