import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import '../../core/app_store.dart';
import '../../ui/common.dart';
import 'auth_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.store});
  final AppStore store;
  Future<void> endpoint(BuildContext context) async {
    final controller = TextEditingController(text: store.api.endpoint);
    final value = await showDialog<String>(context: context, builder: (c) => AlertDialog(
      shape: const MiuixSquircleBorder(cornerRadius: 28), title: const Text('服务 API 地址'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        MiuixTextField(controller: controller, label: '完整 /happy/api 地址', singleLine: true),
        const SizedBox(height: 12), const Text('更换地址将清除本机登录状态。请仅连接你信任的服务。')]),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
        ActionButton('保存', onPressed: () => Navigator.pop(c, controller.text))]));
    controller.dispose();
    if (value != null) { try { await store.setEndpoint(value); if (context.mounted) notice(context, '服务地址已更新，请重新登录'); } catch (e) { if (context.mounted) notice(context, '$e'); } }
  }
  Widget toggle(String title, String subtitle, bool value, void Function(bool) update) => ListTile(title: Text(title), subtitle: Text(subtitle),
    trailing: MiuixSwitch(value: value, onChanged: (v) { update(v); store.savePreferences(); }));
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: store, builder: (_,__) => PageFrame(title: '设置', child: ListView(padding: const EdgeInsets.all(18), children: [
    const SectionTitle('外观与体验'),
    MiuixCard(child: Column(children: [
      ListTile(title: const Text('主题模式'), subtitle: const Text('Miuix 原生主题配色'), trailing: DropdownButton<String>(value: store.theme,
        items: const [DropdownMenuItem(value: 'system', child: Text('跟随系统')), DropdownMenuItem(value: 'light', child: Text('浅色')), DropdownMenuItem(value: 'dark', child: Text('深色'))],
        onChanged: (v) { if (v != null) { store.theme = v; store.savePreferences(); } })),
      toggle('减少页面动效', '同时遵循系统的减少动画设置', store.reducedMotion, (v) => store.reducedMotion = v),
    ])),
    const SectionTitle('播放偏好'),
    MiuixCard(child: Column(children: [
      toggle('进入详情自动播放', '默认关闭，避免意外消耗流量', store.autoplay, (v) => store.autoplay = v),
      ListTile(title: const Text('默认播放速度'), trailing: DropdownButton<double>(value: store.speed,
        items: [.5,.75,1.0,1.25,1.5,2.0].map((v) => DropdownMenuItem(value: v, child: Text('${v}x'))).toList(),
        onChanged: (v) { if (v != null) { store.speed = v; store.savePreferences(); } })),
      toggle('显示弹幕', '所有播放页使用此默认偏好', store.danmakuEnabled, (v) => store.danmakuEnabled = v),
      const ListTile(title: Text('弹幕透明度')),
      MiuixSlider(value: store.danmakuOpacity, min: .2, max: 1, onValueChanged: (v) { store.danmakuOpacity = v; store.savePreferences(); }),
      const ListTile(title: Text('弹幕密度'), subtitle: Text('调低密度可以减少画面遮挡')),
      MiuixSlider(value: store.danmakuDensity, min: .2, max: 1, onValueChanged: (v) { store.danmakuDensity = v; store.savePreferences(); }),
    ])),
    const SectionTitle('账户与连接'),
    MiuixCard(child: Column(children: [
      if (store.user != null) ListTile(leading: const Icon(Icons.lock_outline), title: const Text('修改密码'), subtitle: const Text('修改后所有会话失效'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AuthPage(store: store, initialMode: AuthMode.change)))),
      ListTile(leading: const Icon(Icons.dns_outlined), title: const Text('服务 API 地址'), subtitle: Text(store.api.endpoint), onTap: () => endpoint(context)),
      if (store.api.insecure) const ListTile(leading: Icon(Icons.warning_amber_rounded, color: Colors.orange), title: Text('当前服务使用 HTTP'), subtitle: Text('账户数据传输未加密，请使用可信网络。')),
    ])),
    const SectionTitle('关于初眠'),
    MiuixCard(child: Column(children: [
      ListTile(leading: const Icon(Icons.help_outline), title: const Text('使用帮助'), trailing: const Icon(Icons.chevron_right), onTap: () => openInformation(context, '使用帮助', helpText)),
      ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: const Text('数据与隐私说明'), trailing: const Icon(Icons.chevron_right), onTap: () => openInformation(context, '数据与隐私说明', privacyText)),
      ListTile(leading: const Icon(Icons.code), title: const Text('开源许可'), subtitle: const Text('Flutter Miuix · Apache 2.0'), onTap: () => showLicensePage(context: context, applicationName: '初眠动漫', applicationVersion: '1.0.0')),
      const ListTile(title: Text('客户端版本'), trailing: Text('1.0.0')),
    ])), const SizedBox(height: 24),
  ])));
}
void openInformation(BuildContext context, String title, String text) => Navigator.push(context,
  MaterialPageRoute(builder: (_) => PageFrame(title: title, child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: SelectableText(text, style: const TextStyle(fontSize: 15, height: 1.6))))));
const helpText = '''发现与搜索
发现页显示站点推荐和最新上架内容。顶部搜索支持名称和简介，分类和排序可以进一步缩小范围。排行依据站点去重观看次数，不是个性化推荐。

播放与续看
进入视频详情后点播放。拖动进度条跳转，双击画面暂停或继续，左右轻扫跳转 10 秒。全屏中可锁定控制栏，解锁后退出。进入后台会暂停。
登录观众的历史每 15 秒以及暂停/退出时尝试同步；网络失败仍保留本机进度并在下次播放继续尝试。匿名观众仅保留本机最近 100 个进度。

播放链接失效
链接有效期为 24 小时并绑定 IP。Wi-Fi 与移动网络切换后可能无法继续播放，点“刷新播放链接”重新签发。内容下架、编码不支持和服务器并发限制也可能导致失败。当前不提供清晰度切换和离线下载。

弹幕与评论
弹幕支持 #RRGGBB 颜色、16–40 字号、滚动/顶部/底部；设置可调整透明度与密度。评论仅纯文本，回复统一在原一级评论下。可删除自己的评论，或举报视频。

邮箱与账户
验证码有效 10 分钟，60 秒冷却，服务端限制次数与日额度。注册和找回统一反馈不会透露邮箱是否已注册；没有收到邮件请检查垃圾箱或联系站点维护者。

功能边界
客户端不提供投稿、私信、评论图片、管理员管理、会员支付、分集编排、转码或自适应清晰度。''';
const privacyText = '''本客户端连接你设置的初眠动漫服务，并非离线内容库。

邮箱、昵称、密码和验证码只在相应账户操作时发送到该服务。客户端不持久化密码或验证码；Bearer 会话保存在设备安全存储，退出或会话失效时清理。修改/重置密码会撤销服务端全部会话。

当前默认服务使用 HTTP，传输没有加密。设备安全存储不能保护网络传输，请勿在不可信网络输入敏感密码。建议站点迁移到 HTTPS。

搜索历史、主题、播放及弹幕偏好保存在本机。匿名观看进度仅保存在本机，最多 100 个条目。登录后观看位置、时长、收藏、点赞、评论、弹幕和举报会按需发送到服务端。

客户端不包含广告 SDK、数据统计 SDK 或联系人/相册/定位权限，不下载视频源文件，不保存或公开视频签名链接。视频和封面直接由站点提供，播放可能使用较多流量。

更换服务地址将清除当前本机登录凭证，原服务端会话会按服务端规则过期。清理搜索历史只影响本机。服务端账户数据的保留、删除和审核须联系该站点维护者处理。

以上是客户端实际的数据行为说明，不代替运营者正式发布的隐私政策。''';
