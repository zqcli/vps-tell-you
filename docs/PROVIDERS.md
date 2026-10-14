# 提供商与提供商目录

本文取代 `PROVIDERS_AND_PACKAGES.md`（套餐功能已整体移除，见第 8 节）。应用只管理**提供商**：谁卖给你服务器。内置的“提供商目录”（名称、Logo、简介、官网）放在仓库 `catalog/`，**不随应用打包**，由应用从 GitHub 下载、缓存并更新。用户也可以不选提供商，或自建提供商。

## 1. 领域模型

```
目录提供商 DirectoryProvider  ←—— catalogId ——  本地提供商 ProviderRecord(providers 表) 1 ── * 服务器(servers 表)
（只读，来自下载的目录）                         （用户的业务归属，台账的一部分）
```

| 概念 | 存放 | 说明 |
| --- | --- | --- |
| `DirectoryProvider` | 目录缓存（内存 + 应用支持目录文件） | `id`（稳定短标识）、中英文名称、别名、`kind`、`region`、官网、简介、Logo。只读。 |
| 本地提供商 `ProviderRecord` | SQLite `providers` | `id`、`name`、`revision`、`created_at`，可空唯一的 `catalog_id`。自建提供商的 `catalog_id` 为空。 |
| 服务器 | SQLite `servers` | `provider_id` 指向本地提供商；旧的 `vendor` 文字保持历史资料。 |

原则：

- **台账是事实来源，目录只是展示资料。** 目录里的名称、Logo、简介、官网从不写进台账；目录消失（离线、被删除）时，台账与服务器完全不受影响，已关联的提供商只是显示首字母头像。
- **目录提供商要“加入”才成为本地提供商。** 新增流程里选目录提供商并保存服务器时，才在同一事务内创建 `catalog_id` 非空的本地提供商（取消表单不留痕）；提供商页也可显式“添加”。同一目录提供商只会对应一个本地提供商（唯一索引）。
- **名称冲突不猜测地合并。** 本地已有同名（不区分大小写 ASCII）且无 `catalog_id` 的用户提供商时，加入目录提供商直接把它关联到目录，不重复创建、不改名、不移动服务器。
- **本地名称是显示副本。** 用户可重命名本地提供商，列表和服务器上显示本地名称；Logo、简介、官网仍由 `catalog_id` 对应的目录条目提供。目录改名不会改动本地名称。`catalog_id` 在目录里找不到时，只显示首字母头像。
- **删除提供商**（仅本地提供商，提供商页 ⋯ 菜单，需确认）：其服务器（含已归档）全部保留，只清除 `provider_id`（在用的服务器版本号 +1，已归档的保持不变），显示为“未指定提供商”；`vendor` 文字不动。目录提供商随后回到“目录”列表，可再次添加。

## 2. 目录数据（`catalog/`）

```
catalog/
  README.md                      如何添加 / 修改提供商、Logo 规则、商标说明
  index.json                     由 tool/build_catalog.py 生成；应用只轮询这一个文件
  providers/<id>/provider.json   每个提供商的数据（事实来源）
  providers/<id>/logo.png        256×256 PNG，≤ 64 KiB，透明或白底，居中留约 12 % 边距
```

字段与规则见 [catalog/README.md](../catalog/README.md)。`tool/build_catalog.py`（仅 Python 标准库）校验每个 `provider.json`（字段、id 与文件夹同名、名称与别名全局不重复、https 官网、PNG 文件头 / 尺寸 / 大小），计算 Logo 的 sha256，确定性地写出 `index.json`；内容有变化时 `catalogVersion` 加 1，没有变化则字节不变。`--check` 在 `index.json` 过期时以非零状态退出，CI 已接入。当前内容与取舍见 catalog/README.md，Logo 来源见 catalog/SOURCES.md；Logo 是可选的，缺失时应用显示首字母头像。

`index.json`：

```json
{
  "schemaVersion": 1,
  "catalogVersion": 3,
  "generatedAt": "2026-10-12T00:00:00Z",
  "providers": [
    {
      "id": "aliyun",
      "name": {"zh": "阿里云", "en": "Alibaba Cloud"},
      "aliases": ["Aliyun", "Alibaba Cloud", "阿里云"],
      "kind": "cloud", "region": "cn",
      "website": "https://www.aliyun.com",
      "description": {"zh": "…", "en": "…"},
      "logo": {"path": "providers/aliyun/logo.png", "sha256": "<hex>", "bytes": 5123}
    }
  ]
}
```

## 3. 应用端：`ProviderDirectory`

代码在 `lib/providers/`：`directory_models.dart`（模型与严格解析）、`directory_source.dart`（来源抽象与 HTTP 实现）、`provider_directory.dart`（缓存、检查、状态）、`directory_widgets.dart`（`ProviderLogo`、设置区、提示行）。

### 来源抽象

```dart
abstract interface class DirectorySource {
  List<Uri> get bases;
  Future<IndexFetch> fetchIndex(Uri base, {String? etag});
  Future<Uint8List> fetchFile(Uri base, String path, {required int maxBytes});
}
```

`HttpDirectorySource`（`package:http`）可注入 `Client`、基地址列表、超时（默认 10 秒）和索引大小上限；`ProviderDirectory` 可注入来源、缓存目录、时钟、自动检查间隔和 Logo 并发数。测试用 `MockClient` 与临时目录。`ProviderDirectory.memory(snapshot)` 是不联网、不落盘的实现（测试和默认的 `LedgerApp`）。

### 基地址（按顺序尝试）

1. `https://raw.githubusercontent.com/zqcli/vps-tell-you/dev/catalog/`
2. `https://cdn.jsdelivr.net/gh/zqcli/vps-tell-you@dev/catalog/`（镜像：中国大陆常无法直连 raw.githubusercontent.com）

`--dart-define=VPS_CATALOG_BASE=<url>` 用单个地址替代以上两个（本地测试）。

### 检查流程

1. 依次对每个基地址请求 `index.json`：`Accept: application/json`，超时 10 秒，大小上限 1 MiB（先看 `Content-Length`，再按流式累计，超限立即中止）。只有缓存的 ETag 来自**同一个基地址**时才发送 `If-None-Match`（镜像的校验值对 GitHub 没有意义）；`304` 沿用缓存。
2. 严格解析：`schemaVersion` 必须为 1，`catalogVersion` 必须是非负整数，`providers` 必须是不超过 1000 项的列表，否则整份文档作废并换下一个基地址。未知字段忽略；单个条目不合规（id 不符 `[a-z0-9-]{2,40}`、缺中英文名、非 https 官网、`kind` / `region` 不认识、Logo 路径不是 `providers/<id>/logo.png`、sha256 / 大小不合规、重复 id）则**跳过该条**，其余照用。简介在应用端的限制比作者端宽松一倍（中文 120、英文 360），避免文字小改动让条目消失。
3. `catalogVersion` 只增不减：比缓存小的文档被忽略（状态为“已是最新”），同版本不算更新。
4. 下载缓存中没有的 Logo（并发 4，单个上限 128 KiB）：必须等于索引声明的字节数、以 PNG 文件头开头且 sha256 一致，否则不保存（先试镜像，再放弃；该提供商显示首字母头像，下一次检查——包括 `304`——会重试缺失的 Logo）。
5. 写入顺序：Logo → `index.json` → `meta.json`；每个文件都先写 `.tmp` 再重命名，中断不会留下半个文件。最后清理索引不再引用的 Logo 和 `.tmp` 残留。
6. 任何失败（断网、HTTP 错误、超时、文档作废）都不会触碰已有缓存，只在状态里记为“无法连接 GitHub”。不抛异常、不弹错误。

缓存位置：应用支持目录 `provider_directory/`：`index.json`、`logos/<id>-<sha8>.png`（Logo 变化即新文件名）、`meta.json`（`etag`、`base`、`checkedAt`、`attemptedAt`、`outcome`）。缓存**不进台账 SQLite，也不进备份**。

### 启动与自动更新

- `LedgerApp` 在台账读取完成后 `unawaited(controller.startDirectory())`：先读缓存（不等网络），再在“启动时更新”打开且距上次成功检查 ≥ 12 小时（或从未检查）时后台检查。首帧从不等待目录；完成后界面自动刷新。
- 失败的检查不会推迟下一次自动检查（只有成功才更新 `checkedAt`）。
- 没有缓存且离线：目录分区为空，显示一行提示；“无”、自建提供商、已关联提供商的显示都不受影响。

### 设置与列表

- **设置 → 提供商 → 提供商目录**：状态行（“版本 N · M 个提供商”，副标题“已是最新 / 已更新 / 无法连接 GitHub · 检查于 3 小时前”）、“检查更新”按钮（检查期间显示转圈）、“启动时更新”开关（默认开，保存在 `app_settings.provider_directory_auto`），脚注说明只下载公开的提供商列表、台账不离开设备。
- **全部提供商**：下拉刷新触发同样的检查，失败时用提示说明。

## 4. 隐私

- 唯一与目录有关的网络行为：对 `index.json` 和 Logo 的 HTTPS **GET**（见第 3 节的基地址）。请求不带 Cookie、账号、设备或台账标识符，不带查询参数；不上传任何台账数据、服务器信息、凭据或提供商列表。
- GitHub / jsDelivr 作为普通 HTTP 服务器，会看到请求者的 IP 地址、请求时间和系统默认 User-Agent，与访问任何公开网页相同。应用不做遥测。
- 关闭“启动时更新”后，只有点“检查更新”或在“全部提供商”下拉刷新时才联网。
- 完整性：Logo 经索引里的 sha256 核对；索引本身的可信度来自 HTTPS 与 GitHub 仓库的写权限。应用不跟随任何目录内容执行代码、不打开网址（官网地址只能复制，没有 `url_launcher`）。

## 5. 本地存储与 schema v13

- `providers`：`catalog_id TEXT`，局部唯一索引 `providers_catalog_id ON providers(catalog_id) WHERE catalog_id IS NOT NULL`；名称唯一索引 `providers_name ON providers(name COLLATE NOCASE)`。
- `servers.provider_id`（可空外键）。
- `app_settings.provider_directory_auto INTEGER NOT NULL DEFAULT 1`。
- `LedgerStore.schemaVersion = 13`。新库直接建 v13 结构（没有 `package_*` 列）。

### 迁移 v12 → v13（任何更旧版本先走原有步骤再到 v13）

`onUpgrade` 在 sqflite 的版本变更事务内运行；任一步骤抛错则整体回滚，库保持原版本，**绝不重建或清空**。

1. `UPDATE servers SET package_id = NULL, package_snapshot = NULL`。`package_id`、`package_snapshot` 两列和索引 `servers_package` **保留**（老版 Android 的 SQLite 没有 `DROP COLUMN`），视为已退役：代码不再读写它们，新建的 v13 库里也没有。
2. `UPDATE providers SET catalog_id = NULL WHERE catalog_id IN ('example-cloud','demo-vps')`：第 6 轮内置示例目录的 id，不再存在。其他 `catalog_id` 保持。
3. `ALTER TABLE app_settings ADD COLUMN provider_directory_auto INTEGER NOT NULL DEFAULT 1`。

服务器的其他字段、付款、服务期间、SSH 配置、凭据、提醒和语言 / 外观偏好一概不动。验证：`test/schema13_store_migration_test.dart` 从字节级的真实 v12 DDL（`test/support/schema12_fixture.dart`，含套餐关联、示例 id、真实 id）升级，逐列对比；故障注入验证回滚且 `user_version` 仍为 12。

### 迁移 v11 及更早 → v12（仍然有效，每个更旧的库都会经过）

面板适配器（SolusVM 1/2、RackNerd ctrl、云账户、观测、关联）已整体移除，保留提供商。

1. **秘密引用入队。** 若 `cloud_accounts` 存在，把每个 `secret_ref` 在同一事务内 `INSERT OR IGNORE` 进 `secret_cleanup`，由“重试清理”从设备安全存储删除；迁移与启动都不读取钥匙环。`secret_cleanup` 对仍被 `credentials` 引用的 ref 有防护。
2. **删除适配器结构。** 先删 `providers` 守卫触发器（含建在 `servers` 上的 `server_provider_update`），再依次删除 `cloud_bindings`、`cloud_observations`、`cloud_accounts`。不删除任何服务器、付款、SSH 配置或凭据。
3. **提供商中性化。** 没有 `providers` 表（v10 本地 RackNerd 分支及更早）：创建表，增加 `servers.provider_id`，并按已知的 `vendor` 文字（不含 `服务商待填写`，不区分 ASCII 大小写）建立提供商。已有 `providers`：没有服务器的“待确认”提供商删除，仍有服务器的保留并标为已确认，重名追加 ` (2)`、` (3)`…（总长 ≤ 80）；`needs_review` 列保留但不再使用。随后建立 `providers_name` 唯一索引。
4. 新增 `providers.catalog_id`（及 v12 时的 `servers.package_*`，v13 立即退役）。
5. **清除 API 标记。** 删除每个 `resources_json` 的 `apiFields` 键，其余值逐字保留；无法解析的 JSON 保持原样。
6. `PRAGMA foreign_key_check` 必须为空，否则回滚。

验证：`test/schema12_store_migration_test.dart`（字节级真实 v11 DDL 夹具）。

## 6. 备份 JSON v2

- 写出方版本 **2**：顶层 `providers`（`id`、`name`、`catalog_id`、`created_at`），服务器行含 `provider_id`（可空）。**不再写出套餐字段。**
- 读取方接受 **v1 与 v2**。v2 对提供商严格校验：名称 1–80 且已 trim、大小写不重复、`catalog_id` 合法且不重复、服务器的 `provider_id` 必须存在。第 6–8 轮应用写出的 v2 文件里的 `package_id`、`package_snapshot` 两个键被**静默忽略**（只容忍这两个键，其他未知键仍被拒绝；v1 从来没有它们，出现则拒绝）。未知版本（>2）明确拒绝。
- 仍然**未加密、部分范围**，只恢复到空台账；含提供商的备份在目标已有提供商时判为冲突。目录本身（Logo、简介）不在备份里，恢复后由应用的目录提供。

## 7. 界面流程（iOS 风格，Material 图标）

**规模**：目录可达数百个提供商。所有长列表惰性构建并带搜索；日常入口只显示“在用”的内容。搜索忽略大小写、重音和全角，中文按子串匹配，并同时匹配两种语言的名称和别名（`lib/core/search_match.dart`）。

**Logo**：`ProviderAvatar(logo:)` 把 Logo 放在白色圆角方块上，带 0.5 px 发丝边框，深浅主题一致（Logo 为浅色背景设计）；`FilterQuality.medium`，按 `尺寸 × devicePixelRatio` 解码；无法解码时回退为首字母头像；语义标签是提供商名称；收藏星标徽章保持不变。界面里统一经过 `ProviderLogo`（按本地提供商的 `catalog_id` 或目录条目 id 取缓存的 Logo），所以服务器列表、服务器详情（头部与提供商行）、选择页、提供商页和“全部提供商”里同一个提供商长得一样。

- **设置 → 提供商**：只列有服务器的提供商（含已归档），副标题“N 台服务器”；“全部提供商（总数）”行；“目录”分区（见上）。导航栏“+”新建提供商。
- **全部提供商**：固定搜索框；“我的提供商”（本地，含已关联目录的）与“目录”（尚未添加的），惰性列表；下拉刷新目录；目录为空时显示提示行。
- **提供商详情**：Logo（大）、名称、服务器数、“目录 / 自建”标记；目录提供商显示简介（当前语言，缺失时英文 → 中文）与官网（点按复制，没有 `url_launcher`）；服务器列表（含已归档）；本地提供商 ⋯ 菜单有重命名与删除；尚未添加的目录提供商同一页有“添加”和“添加服务器”。
- **新增 / 编辑服务器**：表单里“提供商”是带箭头的行，点开是全屏选择页（可取消）：“不指定”、“新建提供商…”、“使用中”、“我的提供商”、“目录”；搜索时若输入不与现有名称完全相同，顶部给出“新建提供商“xxx””。新建的提供商与选择的目录提供商都只在保存服务器时创建 / 关联（同一事务）。目录提供商以当前界面语言的名称创建本地提供商。
- **服务器详情**：“提供商”分区一行（Logo、名称，进入提供商详情），更换通过编辑表单。

## 8. 删除的内容

- **套餐 / Package 整体移除**（第 6–8 轮曾有）：套餐模型与目录、套餐页 / 选择页 / 列表、选择套餐预填硬件与费用、服务器上的套餐关联与快照、“目录已更新”提示、备份里的套餐字段，以及随应用打包的 `assets/catalog/providers.json`。服务器自己的硬件与费用本来就是事实来源，不受影响。
- 面板适配器（SolusVM / RackNerd）见第 5 节；协议细节可在 git 历史中的 `docs/SOLUSVM.md` / `docs/RACKNERD.md` 查阅。套餐功能的旧设计文档可在 git 历史中的 `docs/PROVIDERS_AND_PACKAGES.md` 查阅。

## 9. 测试

| 文件 | 内容 |
| --- | --- |
| `test/provider_directory_test.dart` | 首次下载、304、镜像回退、坏 JSON / 坏条目、sha256 不符、大小上限、版本回退、离线、自动更新开关与 12 小时、缓存清理与原子写入（`MockClient`） |
| `test/provider_directory_ui_test.dart` | 设置区、检查更新、开关持久化、首帧不等待目录、下拉刷新、空目录提示、语言与别名搜索 |
| `test/provider_logo_test.dart` | Logo 白底方块（浅 / 深）、首字母回退、星标、语义、各页面使用同一组件、提供商详情（简介 / 官网 / 删除）、320 px / 2× |
| `test/provider_store_test.dart` | 目录提供商关联、删除提供商、备份 v1 / v2 与包字段忽略 |
| `test/schema13_store_migration_test.dart`、`test/schema12_store_migration_test.dart` | 迁移与回滚 |
| `test/provider_ui_test.dart`、`test/provider_scale_test.dart` | 选择页、提供商页、300 个提供商规模 |
