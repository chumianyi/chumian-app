# 初眠动漫 · Flutter 用户客户端

面向普通观众的 Flutter/Dart Android 客户端。接入现有初眠动漫站点真实 API，不是离线演示数据；不包含后端和管理员端。

## 技术与系统版本
- Flutter 最新稳定标签 **3.47.8**（获取时官方 stable/标签核对），`.fvmrc` 已固定；Dart **>=3.12.2 <4.0.0**。
- 最低 **Android 8.0 / API 26**，compile/target SDK 使用 Flutter 的当前 SDK 默认值 36。
- **GitHub 开源 flutter_miuix 1.3.0**，完整发布源码内置 `packages/flutter_miuix`，path dependency，不是自制仿款。
- 官方来源 https://github.com/ChuxinNeko/flutter_miuix 。Miuix 源码未修改，保留 LICENSE、README、shaders。
- 最新直接发布依赖：dio 5.11.1、video_player 2.14.1、flutter_secure_storage 11.2.0、shared_preferences 2.5.6。
- Android Java Activity，AGP 9.1.0 / Gradle 9.3.1 / JDK 17+，自带 Gradle wrapper。

## 已实现
- 固定 Miuix 底部导航：**发现 / 分类 / 排行 / 我的**。
- 推荐、全部/最新、真实分类和排行、公告、刷新、分页、空态和错误重试。
- 顶部与首页搜索入口，**名称/简介统一检索**、350ms 防抖、取消旧请求、搜索历史、分类筛选、最新/最热排序。
- 邮箱密码登录、邮箱验证码注册、验证码找回密码、修改密码、会话恢复、退出撤销；验证码冷却、表单校验和重复提交防护。
- 视频详情、免责声明、点赞、收藏、我的收藏、观看历史、续播。
- 原生 video_player，签名播放链接、手动刷新、播放暂停、静音、倍速、拖动、左右轻扫 10 秒、双击播放、横屏全屏、控制锁、后台暂停。
- 彩色弹幕，16–40 字号，滚动/顶部/底部，按视频时间渲染，窗口加载、去重、密度和透明度。
- 纯文字评论、一级根评论下回复、回复分页、本人评论删除确认、举报、官网页面链接复制。
- 深浅/系统主题、减少动效、默认速度/自动播放/弹幕偏好；原创欢迎插画、首次引导、帮助与隐私说明、开源许可、可信服务 API 地址配置。
- 公开内容首屏缓存：30 分钟、最多 12 份，失败时显式提示；不缓存收藏、历史、密码、Token 或签名播放 URL。

## 源码准备
此包只交付源码与资源，未编译，没有 APK。

1. 安装固定的 Flutter stable 3.47.8（或同时满足 Dart 3.12.2 和包要求的更新稳定版）、JDK 17+、Android SDK 36。
2. 在 `chumian_app` 项目根目录执行 `flutter pub get` 安装非内置依赖。这一步会生成 `android/local.properties`；不需要重建 Android 目录。
3. IDE 打开项目，默认入口 `lib/main.dart`。未提供机器专属 SDK 路径或伪造 `pubspec.lock`。
4. 依赖解析后提交生成的 lock 文件，部署时保持 SDK 和依赖锁定。

默认 API：`http://103.236.99.177:24512/happy/api`。
可从“我的 → 设置 → 服务 API 地址”更换为信任的同协议服务；更换地址会清除本机登录凭证。

正式签名配置：将 `android/key.properties.example` 复制为本机 `android/key.properties`，填写你自己的签名信息。此包没有密钥或真实密码；release 未配置签名时保持未签名，不冒用 debug 签名。

## 目录
```
lib/
  main.dart                 启动与初始化错误处理
  app.dart                  Miuix 根主题、首次引导
  core/                     API、安全会话、偏好与公开缓存
  models/                   官网字段模型
  ui/                       Miuix 共用卡片与状态面板
  features/catalog/         四栏、推荐/分类/排行/搜索/分页
  features/account/         登录注册、找回改密、设置说明
  features/player/          签名播放、全屏、弹幕与详情互动
  features/comments/        评论、回复、本人删除
android/                    API 26 工程与 wrapper
packages/flutter_miuix/      最新原库发布源码和许可证
assets/                     原创品牌欢迎图及许可文本
 test/models_test.dart       真实字段和地址边界测试源码
 docs/                      设计、功能对照、来源和审查说明
```

## 官网核对
依据上传文档，以及官网 `/happy/` 公开页面、`/happy/assets/site.js`、`/happy/assets/common.js` 校准。详情真实字段为 `my_reactions: ['like','favorite']`、`likes`、数值 `resume`；评论回复数使用 `replies`；时间是 Unix 秒；分享使用 `/happy/?video=ID`；弹幕返回 `items`。

GET settings、categories、videos、auth/me 已只读核对。核对时正式站 `videos.items` 为空，因此未对真实非空视频、真实播放或账户写请求进行端到端验收；不伪造视频填充首页。

## 安全与交付边界
- 站点目前只有 HTTP，客户端明确提示传输风险。安全存储不能使 HTTP 加密；正式运营建议站点迁移 HTTPS。
- Bearer 会话仅存设备安全存储，不存密码、不打印 Token、不通过 URL 参数发送 Token。媒体跨域不带凭证。
- 退出操作只有服务端成功撤销后才报告退出成功；网络失败不冒充已撤销。
- 公开列表缓存不是离线视频，影片播放仍需联网。源码没有下载功能。
- 无用户投稿、评论图片、私信、会员支付、分集编排、HLS 自适应清晰度或管理员功能，避免虚构服务器能力。
- **按要求未执行 Flutter 编译、flutter analyze、Flutter 测试、APK 生成、安装或真机验收。** 完成的是源码实现、语法树解析、资源/导入/XML/接口对照及 ZIP 完整性检查。详见 `docs/REVIEW.md`。
- 包内提供的是实现较完整的客户端源码，不等同已经通过生产验收的商业成品。正式发布仍需运行测试、设备兼容、账号邮件、非空数据与实际播放联调，以及运营者正式隐私政策和签名。
