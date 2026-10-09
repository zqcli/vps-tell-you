# vps tell you · 移动端 UI 重设计方案（已确认 · 以 iOS 为基准）

Demo：`docs/ui-redesign/index.html`（浏览器直接打开；左侧切换设备外观、浅/深色与空台账）。
旧版截图未入库（仅评审时在本机临时目录生成）。

## 1. 现状问题（来自实际渲染截图）

- 整套界面由「白卡 + 1px 描边 + 整宽描边按钮 + 描边输入框」组成，观感接近网页表单。
- 页内大标题和右上按钮是自绘的，不会随滚动收起；刷新靠按钮，没有下拉刷新、左滑、长按或底部弹层。
- 信息密度低：服务器列表每行 4 行文字，一屏约 2.5 台；详情页约 3200px，每项都是「上标签、下值」的竖排。
- 说明文字过多：费用页每张卡都重复「折算覆盖 / 缺汇率 / 原币小计」三行。
- 筛选用 AlertDialog 加下拉框；操作按钮用 Wrap 排列，左右对不齐。

## 2. 设计语言（已定：两端统一，以 iOS 为基准）

Android 与 iOS 使用**同一套组件和交互**，不按平台分支。以下差异来自操作系统本身，不需要额外代码：系统字体（iOS 为 SF/PingFang，Android 为 Roboto/Noto）、状态栏和安全区，以及 Android 的系统返回键 / 返回手势（Flutter Navigator 会自动处理，也会关闭弹层和对话框）。

| 维度 | 统一方案 |
|---|---|
| 导航栏 | 大标题，滚动后收起为居中小标题，背景变为毛玻璃；返回按钮显示上一页标题 |
| 底栏 | 4 个 Tab，半透明 Tab Bar |
| 添加入口 | 导航栏「+」，打开「添加服务器」底部弹层（不用 FAB） |
| 列表 | Inset grouped 分组列表，圆角 14，内缩分隔线，带 › |
| 弹层 | 带 grabber 的 sheet，右上 ✕；筛选 / 选择 / 快捷操作都用它 |
| 危险确认 | Action Sheet（红色按钮），文案和二次确认不变 |
| 一般提示 | 居中 Alert |
| 表单 | 分组表单：标签在左，输入在右；模态以 page sheet 打开 |
| 控件 | Cupertino 开关、滑动分段控件、步进器、日期 / 时间滚轮 |
| 转场 | Cupertino 左右推入，两端都支持从左边缘右滑返回 |
| 滚动 | 两端都用回弹滚动，支持 Cupertino 下拉刷新 |

## 3. 页面要点

- **服务器**：搜索框；可横滑的筛选胶囊（全部 / 常用 / 待续费 / 各分组 / 筛选弹层）；三格统计（已过期、30 天内、月费用）；两行列表行（头像、名称·用途、提供商·地区；右侧价格 + 到期胶囊）；左滑可 SSH / 常用 / 归档；长按弹出快捷菜单；下拉刷新；排序用菜单选择。
- **服务器详情**：头部；地址条可复制；四个快捷操作（不可用时点击会说明原因并引导配置）；费用卡（金额、服务期进度、剩余价值、付款记录 / 试算）；提醒行；硬件 3×2 网格；基本信息键值列表；提供商与面板；连接（SSH 配置 / 主机公钥）；备注；元信息。编辑在导航栏，归档在「更多」里。
- **费用**：范围和币种用顶部胶囊；渐变主卡（月费用 + 剩余价值 + 30 天续费）；单条琥珀色缺失提示；即将续费时间线；分布（分段控件 + 堆叠条 + 图例）；六个月柱状图；记录与工具。
- **工具**：2 列磁贴。SSH / 电源先在弹层中选服务器，TCP 在弹层中直接显示结果。
- **设置**：彩色图标设置列表，右侧显示当前值；外观、语言在弹层中直接切换。
- **添加 / 编辑**：两端都用 page sheet；分组表单，单位用分段控件，vCPU 用步进器，计费方式切换后只显示相关字段，硬件分组可折叠。
- **提醒**：开关、提前天数胶囊、时间、使用计划单选；底部实时预览提醒日期。
- **SSH**：连接确认弹层（目标、凭据、主机公钥状态）→ 首次连接时核验指纹 → 全屏终端（保持现有设计，只统一顶栏和快捷键栏）。

## 4. Flutter 落地方案（评审通过后执行）

不新增第三方依赖，全部使用 Flutter SDK 自带的 Material 3 + Cupertino 组件；不改动数据层或业务逻辑。

1. **设计系统**（`lib/core`）：重写 `app_theme.dart` 的 tokens；`pageTransitionsTheme` 对所有平台使用 `CupertinoPageTransitionsBuilder`，全局 `ScrollBehavior` 使用回弹滚动。新增统一组件（无平台分支），尽量直接封装 SDK 自带的 Cupertino 组件：
   - 页面骨架：`AppScaffold`（`CupertinoSliverNavigationBar` 大标题 + `CupertinoSliverRefreshControl`）。
   - 列表：`GroupedSection` / `GroupedRow`（基于 `CupertinoListSection.insetGrouped`）。
   - 状态与头像：`StatusPill`、`ProviderAvatar`。
   - 弹层和确认：`showAppSheet`、`showAppActionMenu`（`CupertinoActionSheet`）、`showAppConfirm`（`CupertinoAlertDialog` / Action Sheet）。
   - 控件：`AppSegmented`（`CupertinoSlidingSegmentedControl`）、`AppSearchField`（`CupertinoSearchTextField`）。
   - 迁移方式：保留 `LedgerCard` / `SettingRow` 等旧 API 作为兼容层，逐页替换。
2. **外壳**：`HomeShell` 改为 `CupertinoTabBar` 风格底栏，导航栏「+」打开统一的添加弹层。
3. **按页迁移**（每页一个提交，每页验证 test + analyze）：服务器列表 → 详情 → 费用 → 工具 / 设置 → 表单 / 提醒 → SSH 连接弹层 → 其余二级页（提供商、云、付款、安全、备份、片段、TCP）统一换成新组件。
4. **测试**：保留所有 `ValueKey`、语义与确认流程；会改动 UI 结构的 widget 测试按新交互更新查找方式，不放宽业务断言。golden 在评审后重新生成。双语 / 320px / 2 倍字号 / 深色布局检查继续通过。
5. **验证**：`flutter analyze`、全量 `flutter test`（关键页面另以 `TargetPlatform.android` 冒烟一次，确认返回键能关闭弹层、页面能正确返回）、iOS 模拟器实际安装截图、Android APK 构建。

## 5. 已确认的决定

1. 两端统一采用 iOS 样式；不使用 FAB，不做 Material/Cupertino 分支。
2. 服务器列表顶部三格统计：已过期 / 30 天内到期 / 月费用参考。
3. 费用主卡使用主色渐变卡片。
4. 详情页快捷操作保留「电源」，沿用现有影响确认与目标二次核对流程。
5. 列表左滑提供 SSH / 常用 / 归档；长按提供同等快捷菜单（复制地址、SSH、记录付款、常用、归档）。
6. 终端页本轮只统一顶栏与快捷键栏样式，不改变输入、发送、断线等交互和字节行为。

## 6. 迁移约束

- 不新增依赖；不改变数据层、财务计算、SSH / 安全 / 云协议行为与确认流程。
- 保留现有 `ValueKey`、语义标签和本地化；新文案同时加入 `app_zh.arb` / `app_en.arb` 并用官方 gen-l10n 生成。
- 已知不准确的说明不随意删除安全边界提示：长说明可移到分组脚注或 ⓘ 弹层，但不能丢失。
