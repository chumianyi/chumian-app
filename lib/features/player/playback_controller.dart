import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import '../../core/app_store.dart';
import '../../core/api.dart';
import '../../models/models.dart';

class PlaybackController extends ChangeNotifier {
  PlaybackController(this.store, this.videoId, this.serverResume) {
    danmakuEnabled = store.danmakuEnabled;
    speed = store.speed;
    timer = Timer.periodic(const Duration(milliseconds: 100), (_) => tick());
  }
  final AppStore store;
  final int videoId;
  final double serverResume;
  VideoPlayerController? video;
  Timer? timer;
  String? error, danmakuError, syncError;
  bool loading = false, closed = false, danmakuEnabled = true, muted = false;
  bool _syncing = false;
  double speed = 1;
  int generation = 0, currentWindow = -1;
  DateTime lastSaved = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? expiresAt;
  List<Danmaku> danmaku = [];
  bool get initialized => video?.value.isInitialized ?? false;
  double get position => (video?.value.position.inMilliseconds ?? 0) / 1000;
  double get duration => (video?.value.duration.inMilliseconds ?? 0) / 1000;
  bool get playing => video?.value.isPlaying ?? false;
  bool get buffering => video?.value.isBuffering ?? false;
  Future<void> open({bool? autoplay}) async {
    if (loading || closed) return;
    final stamp = ++generation;
    final resume = initialized ? position : math.max(serverResume, store.resumePosition(videoId));
    loading = true; error = null; notifyListeners();
    final old = video;
    video = null;
    VideoPlayerController? candidate;
    try {
      if (old != null) { await old.pause(); await old.dispose(); }
      final data = await store.api.playback(videoId);
      final raw = string(data['url']);
      if (raw.isEmpty) throw const ApiException('服务器未返回播放地址');
      final url = store.api.playbackUrl(raw);
      final expires = data['expires_at'];
      expiresAt = expires is num ? DateTime.fromMillisecondsSinceEpoch((expires * 1000).toInt()) : DateTime.tryParse('$expires');
      candidate = VideoPlayerController.networkUrl(Uri.parse(url), httpHeaders: store.api.mediaHeaders(url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false));
      await candidate.initialize().timeout(const Duration(seconds: 30));
      if (closed || stamp != generation) { await candidate.dispose(); return; }
      video = candidate;
      await candidate.setPlaybackSpeed(speed);
      await candidate.setVolume(muted ? 0 : 1);
      if (resume > 0 && resume < duration - 3) await candidate.seekTo(Duration(milliseconds: (resume * 1000).round()));
      if (autoplay ?? store.autoplay) await candidate.play();
      currentWindow = -1;
      unawaited(loadDanmaku(force: true));
    } catch (e) {
      if (candidate != null) { if (video == candidate) video = null; await candidate.dispose(); }
      if (!closed) error = '播放未成功：$e。网络切换后请刷新链接，或检查源文件编码。';
    } finally { if (!closed && stamp == generation) { loading = false; notifyListeners(); } }
  }
  void tick() {
    if (closed || !initialized) return;
    if (video!.value.hasError && error == null) error = '播放中断。内容可能下架、链接已失效或编码不受支持。可手动刷新播放链接。';
    if (danmakuEnabled) unawaited(loadDanmaku());
    if (playing && DateTime.now().difference(lastSaved).inSeconds >= 15) unawaited(saveProgress());
    notifyListeners();
  }
  Future<void> toggle() async {
    if (!initialized) { await open(autoplay: true); return; }
    if (playing) { await video!.pause(); await saveProgress(); }
    else { if (position >= duration - .5) await seek(0); await video!.play(); }
    if (!closed) notifyListeners();
  }
  Future<void> pause() async { if (initialized) { await video!.pause(); await saveProgress(); } }
  Future<void> seek(double seconds) async {
    if (!initialized) return;
    await video!.seekTo(Duration(milliseconds: (seconds.clamp(0, duration) * 1000).round()));
    await loadDanmaku(force: true);
    if (!closed) notifyListeners();
  }
  Future<void> setSpeed(double value) async {
    speed = value;
    await video?.setPlaybackSpeed(value);
    store.speed = value; await store.savePreferences();
    if (!closed) notifyListeners();
  }
  Future<void> toggleMute() async { muted = !muted; await video?.setVolume(muted ? 0 : 1); if (!closed) notifyListeners(); }
  void toggleDanmaku() { danmakuEnabled = !danmakuEnabled; if (danmakuEnabled) unawaited(loadDanmaku(force: true)); notifyListeners(); }
  Future<void> saveProgress() async {
    if (!initialized || duration <= 0 || _syncing) return;
    _syncing = true;
    lastSaved = DateTime.now();
    final pos = position, dur = duration;
    try {
      await store.saveLocalResume(videoId, pos, dur);
      if (store.user != null) await store.api.history(videoId, pos, dur);
      syncError = null;
    } catch (_) { syncError = '进度暂未同步到服务器，本机进度将保留'; }
    finally { _syncing = false; if (!closed) notifyListeners(); }
  }
  Future<void> loadDanmaku({bool force = false}) async {
    if (closed || !initialized || !danmakuEnabled) return;
    final window = position ~/ 300;
    if (!force && currentWindow == window) return;
    currentWindow = window;
    final stamp = generation;
    try {
      final from = math.max(0, window * 300 - 10).toDouble();
      final rows = await store.api.danmaku(videoId, from, from + 320);
      if (closed || stamp != generation || currentWindow != window) return;
      final seen = <int>{};
      danmaku = rows.where((r) => seen.add(r.id)).toList()..sort((a,b) { final t = a.time.compareTo(b.time); return t != 0 ? t : a.id.compareTo(b.id); });
      danmakuError = null;
    } catch (_) { if (!closed && currentWindow == window) danmakuError = '弹幕加载失败，可在弹幕面板重试'; }
    if (!closed) notifyListeners();
  }
  @override
  void dispose() {
    unawaited(saveProgress());
    closed = true; generation++; timer?.cancel();
    final old = video; video = null;
    if (old != null) unawaited(old.dispose());
    super.dispose();
  }
}
