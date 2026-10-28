# 文档用户功能 → 实现对照

| 功能 | 客户端实现 | API |
|---|---|---|
| 推荐/全部/排行/分页 | catalog/home_shell.dart、video_list.dart | GET /videos feed/sort/page/limit |
| 分类 | CategoriesPage、搜索分类 chips | GET /categories、/videos category |
| 名称/简介搜索 | SearchPage、350ms 防抖、请求取消、历史 | GET /videos q |
| 公告 | DiscoverPage 及全文公告 | GET /settings |
| 邮箱注册验证码 | AuthPage register | POST /auth/send-code purpose=register、/auth/register |
| 找回密码验证码 | AuthPage reset | POST /auth/send-code purpose=reset、/auth/reset-password |
| 登录/恢复/退出 | AuthPage、AppStore | POST /auth/login、GET /auth/me、POST /auth/logout |
| 修改密码 | AuthPage change | POST /auth/change-password |
| 详情及免责声明 | VideoPage、Video 模型 | GET /videos/{id} |
| 点赞/收藏 | 详情互动、个人中心 | POST /videos/{id}/like、favorite |
| 收藏与历史列表 | ProfilePage library | GET /videos feed=favorite/history |
| 历史和续播 | PlaybackController 15秒、暂停/销毁保存，本机回退 | POST /videos/{id}/history，详情 resume |
| 签名播放/刷新 | PlaybackController、PlayerView | GET /videos/{id}/playback，签名媒体原生 Range |
| 弹幕读取 | 300秒分段含前10秒，320秒窗，不超过600秒 | GET /videos/{id}/danmaku from/to |
| 彩色16–40字号/模式弹幕 | VideoPage 面板、HexColorDialog、DanmakuLayer | POST /videos/{id}/danmaku |
| 开关与倍速 | PlayerView、SettingsPage | 本机播放器控制 |
| 评论与根评论下回复 | CommentsView，parent_id = 原根ID | GET/POST /videos/{id}/comments |
| 本人删除评论 | CommentsView 仅本人入口+确认 | DELETE /comments/{id} |
| 举报 | SubmitSheet 保留失败草稿，1000字边界 | POST /videos/{id}/report |
| 复制页面链接 | VideoPage Clipboard | 官网 /happy/?video=ID |

## 超出文档但真实可用的本地体验
首次引导、主题切换、减少动效、搜索历史、30分钟公开首屏缓存、自动播放偏好、静音、左右轻扫10秒、全屏控制锁、弹幕透明度/密度、错误重试、可信 API 配置和开源许可。

## 明确未做
后端、管理员端、上传、私信、图片评论、离线视频、会员支付、分集编排、编码转码、自适应清晰度。没有用空按钮包装不存在的接口。
