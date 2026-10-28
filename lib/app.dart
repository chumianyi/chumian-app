import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_miuix/miuix.dart';
import 'core/app_store.dart';
import 'features/catalog/home_shell.dart';
import 'ui/common.dart';

class ChumianApp extends StatelessWidget {
  const ChumianApp({super.key, required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: store, builder: (_,__) => MiuixThemeController(
    colorSchemeMode: switch (store.theme) { 'light' => MiuixColorSchemeMode.monetLight, 'dark' => MiuixColorSchemeMode.monetDark, _ => MiuixColorSchemeMode.monetSystem },
    keyColor: brandColor,
    child: Builder(builder: (context) {
      final miuix = MiuixTheme.of(context);
      final scheme = ColorScheme.fromSeed(seedColor: miuix.colors.primary, brightness: miuix.brightness);
      final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: miuix.brightness);
      return MaterialApp(title: '初眠动漫', debugShowCheckedModeBanner: false,
        locale: const Locale('zh', 'CN'), supportedLocales: const [Locale('zh','CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: base.copyWith(scaffoldBackgroundColor: miuix.colors.background,
          textTheme: base.textTheme.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface).map((style) => style.copyWith(height: 1.35, letterSpacing: .3)),
          appBarTheme: AppBarTheme(backgroundColor: miuix.colors.background, elevation: 0, scrolledUnderElevation: 0, centerTitle: false,
            titleTextStyle: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: .3, color: scheme.onSurface))),
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(data: media.copyWith(disableAnimations: store.reducedMotion || media.disableAnimations), child: child!);
        },
        home: WelcomeGate(store: store),
      );
    })));
}

extension on TextTheme {
  TextTheme map(TextStyle Function(TextStyle) transform) => TextTheme(
    displayLarge: transform(displayLarge!), displayMedium: transform(displayMedium!), displaySmall: transform(displaySmall!),
    headlineLarge: transform(headlineLarge!), headlineMedium: transform(headlineMedium!), headlineSmall: transform(headlineSmall!),
    titleLarge: transform(titleLarge!), titleMedium: transform(titleMedium!), titleSmall: transform(titleSmall!),
    bodyLarge: transform(bodyLarge!), bodyMedium: transform(bodyMedium!), bodySmall: transform(bodySmall!),
    labelLarge: transform(labelLarge!), labelMedium: transform(labelMedium!), labelSmall: transform(labelSmall!));
}
class WelcomeGate extends StatefulWidget {
  const WelcomeGate({super.key, required this.store});
  final AppStore store;
  @override
  State<WelcomeGate> createState() => _WelcomeGateState();
}
class _WelcomeGateState extends State<WelcomeGate> {
  bool get welcomed => widget.store.prefs.getBool('welcomed') ?? false;
  @override
  Widget build(BuildContext context) => welcomed ? HomeShell(store: widget.store) : Scaffold(body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
    const SizedBox(height: 28), ClipRRect(borderRadius: BorderRadius.circular(30), child: AspectRatio(aspectRatio: 4/3, child: Image.asset('assets/images/night_journey.png', fit: BoxFit.cover))),
    const SizedBox(height: 32), const Text('你好，这里是初眠', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)), const SizedBox(height: 12),
    const Text('寻找动画故事，收藏喜欢的瞬间。\n让每一次继续播放，都从刚刚好的地方开始。'),
    const SizedBox(height: 24), const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.bookmark_border, color: brandColor), title: Text('收藏与进度，登录后同步')),
    const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.chat_bubble_outline, color: brandColor), title: Text('文明评论，让弹幕成为陪伴')),
    if (widget.store.api.insecure) const MiuixCard(child: Text('当前站点使用 HTTP，连接未加密。请在可信网络使用，不要复用重要账户密码。', style: TextStyle(fontSize: 13))),
    const SizedBox(height: 26), ActionButton('开始发现故事', icon: Icons.arrow_forward_rounded, onPressed: () async {
      await widget.store.prefs.setBool('welcomed', true); if (mounted) setState(() {});
    }), const SizedBox(height: 24),
  ])));
}
