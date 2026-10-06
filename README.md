# vps tell you

本地优先的个人 VPS 台账，Flutter 原生应用。当前为 **阶段 1（0.1.0）**，以 V6.2 为视觉与交互基础。Android / iOS 工程已生成，Linux 用于原生开发与验证。

## 当前可以做什么

- 默认空台账；用户确认后才载入 4 条明确标注的演示数据
- 手动新增、编辑、查看服务器，保存地址、厂商、用途、规格、备注与原币费用资料
- 搜索、常用、分组、到期筛选及排序；复制主机地址
- 分组重命名、排序与删除，删除分组后记录进入“未分组”
- 归档与撤销、归档列表恢复；服务器 ID 不变，不销毁云资源、不停止扣费
- SQLite 持久化、错误重试；数据库打不开时绝不自动删库重建

费用统计 / 付款 / 计算器（阶段 2），凭据和主机信任（阶段 3），SSH / TCP / 片段 / 电源（阶段 4），SolusVM 1/2（阶段 5），提醒 / 备份 / 移动分享（阶段 6）均未实现。界面明确说明，未模拟成功。没有系统快照、最近使用或费用“接下来需要做什么”。

## 环境与运行

验证 SDK：**Flutter 3.47.6 stable**，framework `5fc346839b`，**Dart 3.13.5**。

```sh
flutter pub get --enforce-lockfile
flutter run -d linux
```

Linux 需要 clang、CMake、Ninja、pkg-config、GTK 3 开发包以及 SQLite 运行环境。默认窗口 430×900，可缩放；界面最大宽度 760。首次打开空数据，演示日期相对于当前设备日期生成，演示 IP 使用文档保留地址，不进行真实网络请求。

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build linux --release
```

Linux 可执行文件：`build/linux/x64/release/bundle/vps_tell_you`。运行时需保留整个 bundle。

Android / iOS 是真实 Flutter 工程，不是 Web 包装。当前没有验证手机安装、Android 构建、iOS 构建 / 签名；后续阶段进行，不能以 Linux 通过替代真机结果。当前无生产 Web 数据库适配。

## 代码结构与数据规则

- `lib/core`：V6.2 视觉组件、纯 Dart 日期 / Money 值类型
- `lib/data`：实际 schema v1、SQLite 事务与平台打开方式
- `lib/servers`：本地字段模型、ChangeNotifier 控制器、列表 / 表单 / 详情
- `lib/settings`：分组、归档、能力说明
- `lib/app.dart`：启动恢复状态和四 Tab；使用 Flutter Navigator

只有一个本地数据库，无后端、代码生成、额外状态或路由框架。依赖来自 pub.dev 维护者，直接版本固定，传递版本保存于 `pubspec.lock`。

服务器和分组使用稳定本地 ID。归档不删除服务器。当前模型属于用户手动资料；未来厂商观测必须单独存储，不得整对象覆盖用户字段。没有为未来阶段预建业务表。

USD / CNY / EUR 金额使用整数分，0 是免费、null 是未知，不跨币种直接相加。日期是日历日期，服务期 `[start, due)`；UTC 仅作日序数，避免 DST 午夜毫秒差。缺日期保持未知。未来 30 天为今天起 `[0, 30)`，不含第 30 天。显示的“未检测”不代表运行状态。

编辑使用版本检查。归档撤销只恢复归档标记；分组删除不会把旧分组复活。写入成功但读取失败会保留成功结果；当前页面显示重读提示，并暂停后续修改直到重读成功，避免重复提交或把已提交写入误判为失败。

## 数据与恢复

数据库 `ledger.sqlite3` 位于平台的 application-support 目录，Linux 通常是 `$XDG_DATA_HOME/com.vpstellyou.vps_tell_you/`。应用没有遥测、自动上传或云同步。

当前尚无备份导出。不要清除应用数据、卸载重装或删除数据库来“修复”。打不开时先检查磁盘空间、权限与应用版本，再点“重试打开”。较新 schema 会阻止旧应用打开，不执行破坏性降级。后续真实 schema 变更必须增加事务迁移并验证旧数据；阶段 1 没有虚构升级迁移。

恢复开发：先读本文件、`docs/STATUS.md`、`docs/ACCEPTANCE.md` → 检查 `git status`、当前分支与远端 → 核对远端 SHA/CI → 执行分析与最小测试 → 从首个未通过项继续。不要自动 tag、强推或改变其他分支。

不得提交真实密码、私钥、API Token、用户数据库或凭据文件。当前备注也不应存秘密。
