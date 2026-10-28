import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import '../../core/app_store.dart';
import '../../core/api.dart';
import '../../ui/common.dart';

enum AuthMode { login, register, reset, change }
Future<bool> requireLogin(BuildContext context, AppStore store) async {
  if (store.user != null) return true;
  await Navigator.push(context, MaterialPageRoute(builder: (_) => AuthPage(store: store)));
  return store.user != null;
}
class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.store, this.initialMode = AuthMode.login});
  final AppStore store;
  final AuthMode initialMode;
  @override
  State<AuthPage> createState() => _AuthPageState();
}
class _AuthPageState extends State<AuthPage> {
  late AuthMode mode;
  final email = TextEditingController(), nickname = TextEditingController(), password = TextEditingController(),
    repeated = TextEditingController(), code = TextEditingController(), oldPassword = TextEditingController();
  bool busy = false, sending = false, obscure = true, accepted = false;
  String? error;
  Timer? ticker;
  DateTime? cooldown;
  int get seconds => cooldown == null ? 0 : cooldown!.difference(DateTime.now()).inSeconds.clamp(0, 3600);
  String get title => switch (mode) { AuthMode.login => '欢迎回来', AuthMode.register => '创建初眠账户', AuthMode.reset => '找回密码', AuthMode.change => '修改密码' };
  @override
  void initState() { super.initState(); mode = widget.initialMode; ticker = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted && cooldown != null) setState(() {}); }); }
  String? validate({bool onlyEmail = false}) {
    if (mode != AuthMode.change && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.text.trim())) return '请输入有效的邮箱地址';
    if (onlyEmail) return null;
    if (password.text.length < 8 || password.text.length > 128) return '密码长度应为 8–128 位';
    if (mode != AuthMode.login && password.text != repeated.text) return '两次输入的密码不一致';
    if (mode == AuthMode.register && (nickname.text.trim().isEmpty || nickname.text.trim().runes.length > 30)) return '昵称需为 1–30 个字';
    if ([AuthMode.register, AuthMode.reset].contains(mode) && code.text.trim().isEmpty) return '请输入邮箱收到的验证码';
    if (mode == AuthMode.change && oldPassword.text.isEmpty) return '请输入当前密码';
    if (!accepted) return widget.store.api.insecure ? '请先阅读并勾选 HTTP 传输风险提示' : '请先阅读并勾选账户使用说明';
    return null;
  }
  Future<void> sendCode() async {
    if (sending || seconds > 0) return;
    final validation = validate(onlyEmail: true);
    if (validation != null) { setState(() => error = validation); return; }
    if (!accepted) { setState(() => error = '请先阅读并勾选传输与账户使用说明'); return; }
    setState(() { sending = true; error = null; });
    try {
      await widget.store.api.sendCode(email.text.trim(), mode == AuthMode.register ? 'register' : 'reset');
      if (!mounted) return;
      setState(() => cooldown = DateTime.now().add(const Duration(seconds: 60)));
      notice(context, '如果该邮箱符合条件，验证码将发送到收件箱；请同时检查垃圾邮件。');
    } catch (e) {
      if (mounted) setState(() { error = '$e'; if (e is ApiException && e.status == 429) cooldown = DateTime.now().add(Duration(seconds: e.retryAfter ?? 60)); });
    } finally { if (mounted) setState(() => sending = false); }
  }
  Future<void> submit() async {
    if (busy) return;
    final validation = validate();
    if (validation != null) { setState(() => error = validation); return; }
    FocusScope.of(context).unfocus();
    setState(() { busy = true; error = null; });
    try {
      switch (mode) {
        case AuthMode.login:
          await widget.store.login(email.text.trim(), password.text);
          if (mounted) Navigator.pop(context, true);
        case AuthMode.register:
          await widget.store.api.register(email.text.trim(), nickname.text.trim(), password.text, code.text.trim());
          if (mounted) { notice(context, '注册请求已完成，请使用新账户登录'); setState(() { mode = AuthMode.login; password.clear(); repeated.clear(); code.clear(); }); }
        case AuthMode.reset:
          await widget.store.api.resetPassword(email.text.trim(), password.text, code.text.trim());
          await widget.store.clearSession();
          if (mounted) { notice(context, '重置请求已完成，请使用新密码登录'); setState(() { mode = AuthMode.login; password.clear(); repeated.clear(); code.clear(); }); }
        case AuthMode.change:
          await widget.store.api.changePassword(oldPassword.text, password.text);
          await widget.store.clearSession();
          if (mounted) { notice(context, '密码已修改，所有会话已撤销，请重新登录'); Navigator.pop(context); }
      }
    } catch (e) { if (mounted) setState(() => error = '$e'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  void switchMode(AuthMode next) { setState(() { mode = next; error = null; password.clear(); repeated.clear(); code.clear(); }); }
  Widget field(TextEditingController c, String label, {bool secret = false, TextInputType? type}) => Padding(padding: const EdgeInsets.only(bottom: 14),
    child: MiuixTextField(controller: c, label: label, singleLine: true, enabled: !busy,
      obscureText: secret && obscure, keyboardType: type,
      trailingIcon: secret ? IconButton(tooltip: obscure ? '显示密码' : '隐藏密码', onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined)) : null));
  @override
  void dispose() { ticker?.cancel(); for (final c in [email,nickname,password,repeated,code,oldPassword]) { c.dispose(); } super.dispose(); }
  @override
  Widget build(BuildContext context) => PageFrame(title: '初眠账户', child: ListView(padding: const EdgeInsets.all(24), children: [
    Icon(mode == AuthMode.login ? Icons.nights_stay_rounded : Icons.lock_outline, size: 48, color: brandColor),
    const SizedBox(height: 20), Text(title, style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800)),
    const SizedBox(height: 8), const Text('收藏喜欢的故事，把观看进度带到下一次。'), const SizedBox(height: 28),
    if (mode != AuthMode.change) field(email, '邮箱地址', type: TextInputType.emailAddress),
    if (mode == AuthMode.register) field(nickname, '昵称 · 1–30 字'),
    if (mode == AuthMode.change) field(oldPassword, '当前密码', secret: true),
    field(password, mode == AuthMode.login ? '密码' : '新密码 · 8–128 位', secret: true),
    if (mode != AuthMode.login) field(repeated, '再次输入新密码', secret: true),
    if ([AuthMode.register, AuthMode.reset].contains(mode)) ...[
      Row(children: [Expanded(child: field(code, '邮箱验证码', type: TextInputType.number)), const SizedBox(width: 10),
        Padding(padding: const EdgeInsets.only(bottom: 14), child: ActionButton(seconds > 0 ? '${seconds}s 后重发' : '发送验证码', busy: sending, onPressed: seconds > 0 ? null : sendCode))]),
      const Text('验证码 10 分钟内有效，一次性使用。服务端不会回显验证码。', style: TextStyle(fontSize: 12)), const SizedBox(height: 12),
    ],
    MiuixCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.store.api.insecure ? '当前连接未加密' : '账户与隐私说明', style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6), Text(widget.store.api.insecure ? '站点当前使用 HTTP。请勿在公共或不可信网络输入敏感密码，也不要复用重要账户密码。客户端不会存储密码，但无法消除传输风险。' : '邮箱用于注册和找回密码；会话凭证仅存于设备安全存储。请文明使用评论与弹幕。', style: const TextStyle(fontSize: 13)),
      CheckboxListTile(contentPadding: EdgeInsets.zero, value: accepted, onChanged: busy ? null : (v) => setState(() => accepted = v ?? false), title: const Text('我已阅读并理解以上说明', style: TextStyle(fontSize: 13))),
    ])),
    if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
    const SizedBox(height: 18), ActionButton(mode == AuthMode.login ? '登录' : mode == AuthMode.register ? '注册账户' : '更新密码', busy: busy, onPressed: submit),
    if (mode != AuthMode.change) Wrap(alignment: WrapAlignment.center, children: [
      if (mode != AuthMode.login) TextButton(onPressed: busy ? null : () => switchMode(AuthMode.login), child: const Text('返回登录')),
      if (mode == AuthMode.login) TextButton(onPressed: busy ? null : () => switchMode(AuthMode.register), child: const Text('邮箱注册')),
      if (mode == AuthMode.login) TextButton(onPressed: busy ? null : () => switchMode(AuthMode.reset), child: const Text('忘记密码？')),
    ]),
  ]));
}
