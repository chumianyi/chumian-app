import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import '../../core/app_store.dart';
import '../../models/models.dart';
import '../../ui/common.dart';
import '../account/auth_page.dart';

class CommentsView extends StatefulWidget {
  const CommentsView({super.key, required this.store, required this.videoId, this.parentId});
  final AppStore store;
  final int videoId;
  final int? parentId;
  @override
  State<CommentsView> createState() => _CommentsViewState();
}
class _CommentsViewState extends State<CommentsView> {
  final draft = TextEditingController();
  List<Comment> items = [];
  int page = 0, generation = 0;
  bool loading = false, sending = false, hasMore = true;
  String? error, replyName;
  int? replyId;
  @override
  void initState() { super.initState(); replyId = widget.parentId; load(reset: true); }
  Future<void> load({bool reset = false}) async {
    if (loading && !reset) return;
    final stamp = reset ? ++generation : generation;
    setState(() { loading = true; error = null; });
    try {
      final result = await widget.store.api.comments(widget.videoId, page: reset ? 1 : page + 1, parentId: widget.parentId);
      if (!mounted || stamp != generation) return;
      setState(() { final seen = (reset ? <Comment>[] : items).map((c) => c.id).toSet();
        items = [...(reset ? <Comment>[] : items), ...result.items.where((c) => seen.add(c.id))];
        page = result.page; hasMore = result.hasMore && result.items.isNotEmpty; });
    } catch (e) { if (mounted && stamp == generation) setState(() => error = '$e'); }
    finally { if (mounted && stamp == generation) setState(() => loading = false); }
  }
  Future<void> send() async {
    if (sending) return;
    final text = draft.text.trim();
    if (text.isEmpty || text.runes.length > 2000) { notice(context, '评论需为 1–2000 字'); return; }
    if (!await requireLogin(context, widget.store) || !mounted) return;
    setState(() => sending = true);
    try {
      await widget.store.api.comment(widget.videoId, text, parentId: replyId ?? widget.parentId);
      if (!mounted) return;
      draft.clear(); setState(() { replyName = null; replyId = widget.parentId; });
      notice(context, '评论已发表'); await load(reset: true);
    } catch (e) { if (mounted) notice(context, '$e'); }
    finally { if (mounted) setState(() => sending = false); }
  }
  Future<void> delete(Comment c) async {
    if (!await confirm(context, '删除自己的评论', '这条评论及其回复将被隐藏，此操作由服务器执行。') || !mounted) return;
    try { await widget.store.api.deleteComment(c.id); if (mounted) { notice(context, '评论已隐藏'); await load(reset: true); } }
    catch (e) { if (mounted) notice(context, '$e'); }
  }
  Future<void> replies(Comment c) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => PageFrame(title: '${c.nickname} 的评论回复', child: ListView(padding: const EdgeInsets.all(18), children: [
      MiuixCard(child: Text(c.text)), const SizedBox(height: 20), CommentsView(store: widget.store, videoId: widget.videoId, parentId: c.parentId ?? c.id)]))));
    if (mounted) await load(reset: true);
  }
  @override
  void dispose() { generation++; draft.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (widget.parentId == null) const SectionTitle('一起聊聊这个故事', subtitle: '友善表达 · 仅支持纯文字'),
    if (replyName != null) Row(children: [Expanded(child: Text('正在回复 $replyName', style: const TextStyle(color: brandColor))), TextButton(onPressed: () => setState(() { replyName = null; replyId = widget.parentId; }), child: const Text('取消回复'))]),
    MiuixTextField(controller: draft, label: widget.parentId != null || replyId != null ? '写下回复…' : '分享你的感想…', minLines: 2, maxLines: 5, enabled: !sending),
    const SizedBox(height: 10), Row(children: [Expanded(child: ValueListenableBuilder<TextEditingValue>(valueListenable: draft, builder: (_,v,__) => Text('${v.text.runes.length}/2000', style: Theme.of(context).textTheme.bodySmall))),
      ActionButton('发表${replyId != null ? '回复' : '评论'}', onPressed: send, busy: sending)]),
    const SizedBox(height: 20),
    if (loading && items.isEmpty) const Center(child: CircularProgressIndicator()),
    if (!loading && items.isEmpty && error == null) const StatePanel(title: '还没有评论', message: '第一份感想，也许来自你。', icon: Icons.chat_bubble_outline),
    ...items.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: AnimatedBuilder(animation: widget.store, builder: (_,__) => MiuixCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [CircleAvatar(radius: 16, backgroundColor: brandColor.withValues(alpha: .1), child: const Icon(Icons.person_outline, size: 18, color: brandColor)), const SizedBox(width: 8),
        Expanded(child: Text(c.nickname, style: const TextStyle(fontWeight: FontWeight.w600))), Text(displayDate(c.created), style: Theme.of(context).textTheme.bodySmall)]),
      const SizedBox(height: 10), SelectableText(c.text),
      Wrap(spacing: 8, children: [TextButton(onPressed: () => setState(() { replyId = c.parentId ?? c.id; replyName = c.nickname; }), child: const Text('回复')),
        if (widget.parentId == null && c.replyCount > 0) TextButton(onPressed: () => replies(c), child: Text('查看 ${c.replyCount} 条回复')),
        if (widget.store.user?.id == c.userId) TextButton(onPressed: () => delete(c), child: const Text('删除')),
      ]),
    ]))))),
    if (error != null) StatePanel(title: '评论加载失败', message: error!, onRetry: () => load(reset: items.isEmpty)),
    if (items.isNotEmpty && hasMore && error == null) Center(child: ActionButton('加载更多评论', onPressed: () => load(), busy: loading)),
    if (items.isNotEmpty) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => load(reset: true), child: const Text('刷新评论'))),
  ]);
}
