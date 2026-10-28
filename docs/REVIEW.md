# 交付审查与限制

## 已完成的非编译审查
1. 全部应用 Dart 文件和测试源码使用独立语法树解析，检查 ERROR/missing 节点；不是 Dart 编译器，不提供类型或运行结果保证。
2. 相对 import 文件存在性；pubspec YAML 解析；主题 path dependency；应用 assets 与 Miuix shader 文件存在性。
3. Android XML 解析；minSdk=26；Activity 包名与 manifest/namespace 对应；Gradle wrapper JAR 可读取。
4. Miuix 1.3.0 原始构造参数对照，实际使用 ThemeController、NavigationBar、NavigationBarItem、Card、Button、Switch、Slider、TextField 和 Squircle。
5. 最新 video_player 2.14.1 发布源码核对 networkUrl/httpHeaders/VideoPlayerOptions 用法。
6. 官网 site.js 确认 my_reactions、replies、Unix日期、resume、分享 video 参数与弹幕 items；公开 API GET 核对成功且当前列表为空。
7. 安全审阅：没有密码持久化、Token 日志、查询参数 Token、非幂等自动重试、管理员 API 或伪造内容；未把签名媒体 URL 存到本地。
8. 状态审阅：取消旧搜索请求、列表请求 generation、会话 epoch、播放器 dispose/后台暂停、旧流先释放、失败草稿保留、回复根 parent_id。
9. ZIP 路径与完整性检查，全部资源包含，未加入 APK、机器配置、真实密钥或远端用户数据。

## 没有执行
按要求不编译、不构建、不跑 flutter analyze、不执行 Flutter unit/widget 测试，不生成/安装 APK，不做浏览器客户端运行验证，不调用正式注册、发邮件、登录、写评论、弹幕、举报或管理接口。

## 待发布前验收
- 依赖解析与 lock 文件、类型检查、完整测试、实际 Android 8/新版本设备与大字体布局。
- 真实视频（MP4/WebM、Range）、低网速、seek、切网络、签名失效、下架、暂停/后台/全屏退出、进度服务端同步。
- 邮箱到达与验证码、账户封禁、会话过期、实际收藏历史、非空评论/回复/本人删除权限。
- API 文档未定义的更多响应字段若实际后端变化，需联调校准；前台脚本已有字段已适配。
- HTTP 迁移 HTTPS、正式应用签名、商店要求、运营者隐私政策。源码实现不等于生产验收结论。
