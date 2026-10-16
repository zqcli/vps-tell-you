# 界面语言与本地化

基线：已发布的中文文案审定版本 `9be096fcc1ffbca5136ead81c6acc660cc2175f9`。中文术语、费用边界及安全动作语义继续以 [UI_COPY_REVIEW](UI_COPY_REVIEW.md) 为准。

## 使用方式

在「设置 / 语言」选择：

- 简体中文：新安装与现有用户的默认选项，设备使用其他语言也不自动改变原中文界面。
- English：立即切换英文界面。
- 跟随系统：依次匹配设备首选语言中的中文或英文；均不支持时使用英文。中文的地区/书写体系变体统一显示简体中文。选择跟随系统后，系统语言改变会更新界面。

语言写入成功后立即生效并持久化；写入失败保留原选项。切换语言不重新打开数据库，不重新读取目录，不重建 SSH 服务或重放输入。已打开页面、输入控制器、选项与未发送草稿保持原有状态；已有验证错误会重新显示对应语言，但不会重新提交表单。

已保存的到期提醒会以新的界面语言重新核对和提交，仍受原通知权限、容量、时间窗和系统投递限制。设置成功不代表通知已经送达。设备原生权限窗口中的系统自有文字由操作系统管理；iOS 包内提供英文与简体中文 Face ID 用途说明，应用的设备验证原因和可配置按钮文案在明确发起验证时使用当前语言。切语言本身不会再次验证身份或读取秘密。

## 内容与数据边界

- 覆盖应用导航、表单、验证、安全/网络错误、空态、确认框、提示、无障碍标签、Material 内置控件、提醒内容，以及计算结果的复制文本和 PNG。
- 「发送 / Send」发送原始正文，不追加回车；「发送并执行 / Send and Execute」只在原文后追加一个 CR，由当前终端程序处理。已有换行或控制字符仍可能触发远端行为。
- 不翻译或改写用户名称、备注、命令正文、SSH 输出、IP/主机名、密钥、协议字段、枚举存储值、数据库 ID 或 JSON key。
- 已保存的演示资料、厂商待补填默认值和历史自动规格摘要继续保留原始内容。默认未分组是通过空分组 ID 表示的界面标签；旧版保留名称的输入约束使用固定历史值，不随语言变化。
- 日期继续采用无歧义的 `YYYY-MM-DD`，时间仍按明确的设备时区/24 小时制展示。原币代码、整数分金额、续费月数、汇率及服务期 `[start, due)` 的计算和序列化完全不随语言变化。英文日/月计数使用正确的单复数。
- 导出在用户请求时捕获不可变的语言快照，防止进行中的 PNG 与结果说明混用语言。导出白名单及隐私排除项不变。

## 英文文案规范

英文以 Apple HIG / iOS 的写法为准：短、地道、动作用动词、标题用名词，避免逐字直译中文结构。只改 `app_en.arb` 的值，key、占位符和 ICU 结构保持不变。

### 大小写

| 位置 | 写法 | 示例 |
| --- | --- | --- |
| 导航标题、Tab 名、按钮、菜单项、操作表/对话框按钮、动作行（点了就执行的行） | 标题式（Title Case） | `Add Server`、`Record Payment`、`Send and Execute`、`Keys & Security` |
| 打开另一页的设置/工具入口行 | 标题式，与目标页标题一致 | `Manage Groups`、`Notification Access` |
| 对话框标题：整句或疑问句 | 句式（Sentence case）加问号 | `Delete this payment record?` |
| 对话框标题：名词短语 | 标题式 | `Large File`、`Rename or Move` |
| 分组标题、字段/行标签、占位符、胶囊、指标、脚注、提示、Toast、错误 | 句式 | `Monthly cost reference`、`Search by server name` |

标题式：首词和末词大写；`a an the and but or nor for as at by in of on to with from into onto over vs via per` 小写；连字符两侧、`·` 或 `:` 之后的词按新片段处理；`SSH`、`iOS`、`vCPU` 等已含大写或数字的词保持原样。同一 key 同时用作标题和行标签时按较强的角色（标题/按钮）处理。句式标签里，`/` 后的词小写（`Group / purpose`），`·` 后的片段首字母大写（`Verified · Manual reads`）。

标点：按钮、标题、标签、胶囊不加句号；脚注和提示是完整句子时加句号；消息中自然使用缩写（`can’t`、`don’t`、`couldn’t`）。使用美式拼写（`canceled`）。占位符中的撇号一律用 `’`，因为 ASCII `'` 在 ICU 中是转义符。

保持原样的名称：`VPS Tell You`（产品名）、SSH、SFTP、TCP、IP、IPv4/IPv6、vCPU、GiB/MiB/TiB、CNY/USD/EUR、JSON、PNG、Face ID、iOS、Android。

### 英文术语表

| 英文 | 中文 | 说明 |
| --- | --- | --- |
| ledger | 台账 | 应用内的本地账本；`local ledger` |
| record | 记录 | 服务器的本地记录；`Archive Local Record` 保留，强调不影响远端 |
| provider | 提供商 / 厂商 | 卖服务器的公司；不用 vendor |
| directory | 目录 | 提供商目录：从 GitHub 下载并缓存的公开提供商列表（名称、Logo、简介），界面写 `Directory` / `Provider Directory`，仓库目录叫 `catalog/` |
| due date | 到期日期 | 服务期结束日，不计入服务期；`expires` / `expired` 作动词和状态；提醒功能名保留 `Expiry reminders` |
| renewal price / cycle | 续费金额 / 周期 | 一个周期的价格与时长，不等于实际支付 |
| remaining value | 剩余价值 | 参考折算，不是退款或成交价 |
| payment record | 付款记录 | 仅记账；`Void` 对应撤销，`Delete` 对应删除 |
| archive | 归档 | 不取消服务、不停止计费 |
| host key | 主机公钥 | 界面统称 host key；输入公钥行时说 public key |
| credential / passphrase | 凭据 / 口令 | passphrase 仅指私钥解密口令 |
| snippet | 片段 | 命令片段；只进入草稿，不自动发送 |
| Send / Send and Execute | 发送 / 发送并执行 | 前者发送原文，后者追加 Enter |

安全含义不因措辞改变：归档不等于取消计费；付款只是记账；秘密不导出；主机公钥变化会阻止认证；电源命令的结果可能未知；未加密备份；提醒不保证送达；估值和汇率仅供参考。

## 实现

使用 Flutter 官方 `flutter_localizations`、`intl` 和 `gen-l10n`，不引入翻译服务、下载语言包、路由框架或运行时中文字符串查表。

- `lib/l10n/app_zh.arb`：审定中文模板及占位符定义。
- `lib/l10n/app_en.arb`：对应完整英文翻译。
- `lib/l10n/generated/`：提交官方工具生成的类型安全访问代码。
- `locale_preference.dart`：稳定偏好值、设备语言解析以及 `BuildContext.l10n`。
- `localized_message.dart`：安全的应用自有错误/状态在显示时解析的轻量接口；不承载原始插件或传输错误。

普通组件使用当前 `context.l10n`。无界面上下文的格式化方法显式接受 `AppLocalizations`；兼容性 getter 使用固定中文回退，不作为业务状态标识。长期保留的错误、确认内容和状态使用 `LocalizedMessage`，不要提前保存当前语言的 String，也不要通过比较译文判断字段、状态或操作。

开发时编辑 ARB 并运行：

```sh
flutter pub get --enforce-lockfile
flutter gen-l10n
dart format lib test
flutter analyze
flutter test
```

`flutter pub get` 和构建也会按 `l10n.yaml` 生成代码。占位符、复数和已生成代码需保持同步；catalog 测试检查双语 key 完整性、英文遗漏以及生产源码中的未迁移中文界面文字。

## 迁移与备份

schema v9 只向 `app_settings` 添加 `language` 列（`zh`、`en`、`system`；默认 `zh`），不改写服务器、付款、周期、凭据或原有偏好。旧版 v1–v8 通过原有迁移顺序升级；不提供清库或降级重建路径。

JSON 备份仍为格式 v1，应用偏好仍属于排除项。切换语言不改变备份记录内容；恢复备份保留当前设备的语言、外观等偏好。

## 验证范围

测试覆盖偏好迁移/保存/重新启动/系统回退、并发旧读取不能覆盖新语言、页面和草稿保留、旧错误/打开的确认框即时翻译、不重试设备验证/SSH 输入，以及英文与中文的 320px、2 倍字和横屏布局。

真实字体验证使用测试专用 Noto Sans CJK SC 子集，逐字核对原字体的 advance 与轮廓；应用生产字体和终端字节协议不变。界面截图来自隔离 Flutter engine，不能当作 Android/iOS 真机权限、IME、安装升级或通知实际送达验证。

最终全量测试、独立 Astra max 审查和 Linux 构建结果记录于 [ACCEPTANCE](ACCEPTANCE.md)。
