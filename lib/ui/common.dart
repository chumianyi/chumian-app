import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import '../core/app_store.dart';
import '../models/models.dart';

const brandColor = Color(0xFF6959EA);
void notice(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}
Future<bool> confirm(BuildContext context, String title, String message) async =>
  await showDialog<bool>(context: context, builder: (c) => AlertDialog(
    shape: const MiuixSquircleBorder(cornerRadius: 28), title: Text(title), content: Text(message),
    actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
      MiuixButton(onPressed: () => Navigator.pop(c, true), child: const Text('确定'))])) ?? false;

class ActionButton extends StatelessWidget {
  const ActionButton(this.label, {super.key, this.onPressed, this.busy = false, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => MiuixButton(onPressed: busy ? null : onPressed,
    minHeight: 48, child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
      else if (icon != null) Icon(icon, size: 20),
      if (busy || icon != null) const SizedBox(width: 8), Text(label)]));
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(4, 22, 4, 12),
    child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      if (subtitle != null) Text(subtitle!, style: Theme.of(context).textTheme.bodySmall)])), if (action != null) action!]));
}

class StatePanel extends StatelessWidget {
  const StatePanel({super.key, required this.title, required this.message, this.icon = Icons.inbox_outlined, this.onRetry, this.retryLabel = '重新加载'});
  final String title, message, retryLabel;
  final IconData icon;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 76, height: 76, decoration: BoxDecoration(color: brandColor.withValues(alpha: .09), borderRadius: BorderRadius.circular(24)),
        child: Icon(icon, color: brandColor, size: 35)), const SizedBox(height: 18),
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8), Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
      if (onRetry != null) ...[const SizedBox(height: 18), ActionButton(retryLabel, onPressed: onRetry)],
    ]));
}

class VideoTile extends StatelessWidget {
  const VideoTile({super.key, required this.video, required this.store, required this.onTap, this.rank});
  final Video video;
  final AppStore store;
  final VoidCallback onTap;
  final int? rank;
  Widget cover(BuildContext context) => ClipRRect(borderRadius: BorderRadius.circular(16), child: AspectRatio(aspectRatio: 16 / 9,
    child: Stack(fit: StackFit.expand, children: [
      ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: store.api.publicUrl(video.cover).isEmpty ? const Icon(Icons.movie_outlined, size: 40)
          : Image.network(store.api.publicUrl(video.cover), fit: BoxFit.cover,
            cacheWidth: 600, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 32))),
      Positioned(bottom: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
        child: Text('${compactCount(video.views)} 次观看', style: const TextStyle(fontSize: 11, color: Colors.white)))),
    ])));
  @override
  Widget build(BuildContext context) => MiuixCard(onPressed: onTap, insideMargin: const EdgeInsets.all(10), child:
    rank != null ? Row(children: [SizedBox(width: 32, child: Text('$rank', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: rank! <= 3 ? brandColor : Colors.grey))),
      SizedBox(width: 122, child: cover(context)), const SizedBox(width: 12), Expanded(child: metadata(context))])
    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [cover(context), const SizedBox(height: 10), metadata(context)]));
  Widget metadata(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
    const SizedBox(height: 5), Text(video.category.isEmpty ? '动画' : video.category, maxLines: 1, style: Theme.of(context).textTheme.bodySmall),
    if (video.resume > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Text('续看 ${clock(video.resume)}', style: const TextStyle(fontSize: 12, color: brandColor))),
  ]);
}

class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.title, required this.child, this.actions});
  final String title;
  final Widget child;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title), actions: actions),
    body: SafeArea(top: false, child: child));
}
