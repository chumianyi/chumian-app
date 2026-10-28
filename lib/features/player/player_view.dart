import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:video_player/video_player.dart';
import '../../models/models.dart';
import '../../ui/common.dart';
import 'danmaku_layer.dart';
import 'playback_controller.dart';

class PlayerView extends StatefulWidget {
  const PlayerView({super.key, required this.controller, this.fullscreen = false});
  final PlaybackController controller;
  final bool fullscreen;
  @override
  State<PlayerView> createState() => _PlayerViewState();
}
class _PlayerViewState extends State<PlayerView> {
  bool controls = true, locked = false;
  Timer? hideTimer;
  double? dragging;
  double swipe = 0;
  void showControls() { setState(() => controls = !controls); hideTimer?.cancel(); if (controls) hideTimer = Timer(const Duration(seconds: 5), () { if (mounted && widget.controller.playing) setState(() => controls = false); }); }
  Future<void> fullscreen() async {
    if (widget.fullscreen) { Navigator.pop(context); return; }
    await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (!mounted) return;
    try { await Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(backgroundColor: Colors.black,
      body: SafeArea(child: Center(child: PlayerView(controller: widget.controller, fullscreen: true)))))); }
    finally { await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]); await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); }
  }
  @override
  void dispose() { hideTimer?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: widget.controller, builder: (_,__) {
    final p = widget.controller;
    return AspectRatio(aspectRatio: widget.fullscreen ? MediaQuery.sizeOf(context).aspectRatio : 16/9,
      child: ColoredBox(color: Colors.black, child: Stack(fit: StackFit.expand, children: [
        if (p.initialized) Center(child: AspectRatio(aspectRatio: p.video!.value.aspectRatio > 0 ? p.video!.value.aspectRatio : 16/9, child: VideoPlayer(p.video!))),
        if (p.initialized && p.danmakuEnabled) DanmakuLayer(rows: p.danmaku, position: p.position, opacity: p.store.danmakuOpacity, density: p.store.danmakuDensity),
        GestureDetector(behavior: HitTestBehavior.opaque, onTap: showControls,
          onDoubleTap: locked ? null : p.toggle,
          onHorizontalDragStart: locked ? null : (_) { swipe = 0; },
          onHorizontalDragUpdate: locked ? null : (d) { swipe += d.delta.dx; },
          onHorizontalDragEnd: locked ? null : (_) { if (swipe.abs() > 30) p.seek(p.position + (swipe > 0 ? 10 : -10)); }, child: const SizedBox.expand()),
        if (p.loading || p.buffering && p.error == null) const Center(child: CircularProgressIndicator(color: Colors.white)),
        if (p.error != null) Center(child: Container(color: Colors.black87, padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(p.error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12)), const SizedBox(height: 12),
          ActionButton('刷新播放链接', onPressed: () => p.open(autoplay: true)),
        ]))),
        if (!p.initialized && !p.loading && p.error == null) Center(child: IconButton(tooltip: '开始播放', iconSize: 58, onPressed: () => p.open(autoplay: true), icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white))),
        if (controls && p.initialized && !locked && p.error == null) ...[
          const IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black45, Colors.transparent, Colors.black87], stops: [0,.45,1])))),
          Positioned(left: 4, top: 2, child: Row(children: [
            IconButton(tooltip: '锁定控制', onPressed: () => setState(() => locked = true), icon: const Icon(Icons.lock_open_outlined, color: Colors.white)),
            IconButton(tooltip: p.muted ? '打开声音' : '静音', onPressed: p.toggleMute, icon: Icon(p.muted ? Icons.volume_off_outlined : Icons.volume_up_outlined, color: Colors.white)),
          ])),
          Positioned(top: 2, right: 4, child: Row(children: [
            IconButton(tooltip: '弹幕开关', onPressed: p.toggleDanmaku, icon: Icon(Icons.subtitles_outlined, color: p.danmakuEnabled ? const Color(0xFFBFB2FF) : Colors.white)),
            PopupMenuButton<double>(tooltip: '播放倍速', onSelected: p.setSpeed,
              itemBuilder: (_) => [.5,.75,1.0,1.25,1.5,2.0].map((v) => PopupMenuItem(value: v, child: Text('${v}x'))).toList(),
              child: Padding(padding: const EdgeInsets.all(12), child: Text('${p.speed}x', style: const TextStyle(color: Colors.white)))),
          ])),
          Center(child: IconButton(tooltip: p.playing ? '暂停' : '播放', onPressed: p.toggle, iconSize: 50, icon: Icon(p.playing ? Icons.pause_circle_outline : Icons.play_circle_outline, color: Colors.white))),
          Positioned(bottom: 2, left: 10, right: 4, child: Column(children: [
            if (p.duration > 0) MiuixSlider(value: (dragging ?? p.position).clamp(0, p.duration), min: 0, max: p.duration,
              onValueChanged: (v) => setState(() => dragging = v), onValueChangeFinished: () { final value = dragging; setState(() => dragging = null); if (value != null) p.seek(value); }),
            Row(children: [Text('${clock(dragging ?? p.position)} / ${clock(p.duration)}', style: const TextStyle(color: Colors.white, fontSize: 12)), const Spacer(),
              IconButton(tooltip: widget.fullscreen ? '退出全屏' : '全屏', onPressed: fullscreen, icon: Icon(widget.fullscreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white))]),
          ])),
        ],
        if (locked) Positioned(left: 8, top: 8, child: IconButton(tooltip: '解锁控制', onPressed: () => setState(() { locked = false; controls = true; }), icon: const Icon(Icons.lock_outline, color: Colors.white))),
      ])));
  });
}
