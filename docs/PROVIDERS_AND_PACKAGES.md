# 提供商与套餐（Provider / Package）

本文取代 `PROVIDERS_AND_ADAPTERS.md`。面板适配器（SolusVM 1/2、RackNerd ctrl、云账户、观测、关联、API 秘密）整体移除，**保留提供商**，并新增**套餐目录**：每个提供商有各自的套餐列表，新增服务器时可选套餐预填硬件与费用，套餐与服务器双向关联。套餐目录以后由远端 API 提供；当前随应用内置 2 个示例提供商，网络代码一行都没有。

## 1. 领域模型

```
CatalogProvider 1 ── * CatalogPackage          （只读目录，来自内置资源 / 日后远端）
      │ catalogId                  │ package_id + package_snapshot
LocalProvider(providers 表) 1 ── * Server(servers 表) * ── 0..1 套餐
```

| 概念 | 存放 | 说明 |
| --- | --- | --- |
| `CatalogProvider` | 目录（内存） | `id`（稳定短标识）、`name`、`packages`。只读，应用不修改。 |
| `CatalogPackage` | 目录（内存） | `id`、`providerId`、`name`、规格、流量、价格、可选 `region` / `notes`、`isDefault`、`catalogVersion`。 |
| 本地提供商 `ProviderRecord` | SQLite `providers` | 用户的业务归属：`id`、`name`、`revision`、`created_at`，新增可空唯一的 `catalog_id`。用户自建提供商 `catalog_id` 为空。 |
| 服务器 | SQLite `servers` | 现有 `provider_id`；新增可空 `package_id` 与 `package_snapshot`（选择套餐当时的 JSON）。 |

原则：

- **台账是事实来源。** 服务器始终保存自己的硬件与费用；套餐只是“选择当时用来预填”的模板。目录之后改价、改规格、下架，已有服务器的数值不会静默变化。
- **目录提供商要“加入”才成为本地提供商。** 在新增流程里选目录提供商并保存服务器时，才在同一事务内创建 `catalog_id` 非空的本地提供商（取消表单不留痕）；提供商页也可显式“添加”。同一目录提供商只会对应一个本地提供商（唯一索引）。
- **名称冲突不猜测地合并。** 若本地已有同名（不区分大小写 ASCII）且无 `catalog_id` 的用户提供商，加入目录提供商时直接把该提供商关联到目录（它们是同一个，用户已经用同名自己建好了），不重复创建；关联只增加 `catalog_id`，不改名、不移动服务器。
- **本地名称是显示副本。** 用户可重命名本地提供商；`catalog_id` 才是关联依据。目录改名不会改动本地名称。
- 服务器的 `package_id` 非空要求：提供商非空，且该提供商 `catalog_id` 等于快照里的 `providerId`；`package_id` 与 `package_snapshot` 同时为空或同时非空。更换提供商时表单清除套餐（更换后可再选）。
- 服务器旧的 `vendor` 文字保持历史资料，规则不变。

### “默认套餐”的含义

目录里每个**有套餐的**提供商恰有一个 `default: true` 套餐（0 个或多个都使整份目录无效；没有套餐的提供商没有默认）。它只表示：**用户在新增流程中选了该提供商后，套餐选择页默认选中它。**

- 不会存储，也不会替用户自动选定：用户可改选其他套餐或“无套餐”，点“继续”才生效。
- 不影响已有服务器，不参与迁移、备份或排序。
- “无套餐”始终存在，是显式选择，不是默认值。
- 提供商详情里用“默认”标签标出它，仅为信息。

## 2. 目录来源抽象

```dart
abstract interface class ProviderCatalog {
  Future<CatalogSnapshot> load();
}

class CatalogSnapshot {
  final int catalogVersion;      // 发布方递增的整数
  final String? etag;            // 远端来源才有
  final DateTime? generatedAt;
  final List<CatalogProvider> providers;
}
```

- 现在：`BuiltinProviderCatalog` 读取随应用打包的 `assets/catalog/providers.json`（`pubspec.yaml` 的 `assets` 已列入），经与远端相同的严格解析器 `CatalogSnapshot.parse` 校验。测试可注入内存 `ProviderCatalog`。
- 日后：另写 `RemoteProviderCatalog implements ProviderCatalog`，内部使用 `CatalogFetcher`（HTTP，条件请求）+ `CatalogCache`（上次成功文档与 ETag，存应用支持目录的文件，不进台账 SQLite，也不进备份）+ 内置目录兜底。界面和控制器只依赖 `ProviderCatalog`，替换实现时无需改动。**现在没有任何网络代码、没有占位 TODO。**
- `LedgerController` 持有 `ProviderCatalog` 与最近一次成功的 `CatalogSnapshot`（`catalog`）。加载失败 → 目录为空并带一次性错误标记；应用其余部分照常工作（可以只用“我的提供商 / 新建提供商 / 无提供商”）。目录加载与台账刷新互相独立，目录失败不会使台账进入“需重读”状态。

### 解析与校验（本地资源与远端文档共用）

- 顶层必须是对象；`schemaVersion` 必须等于支持的版本（目前 1），未来版本被明确拒绝；未知字段被忽略（向前兼容），已知字段类型/范围错误则**整份文档无效**（不做部分采用，避免静默丢套餐）。文档大小上限 1 MiB，提供商 ≤ 200，每个提供商套餐 ≤ 200。
- id 规则：提供商 `^[a-z0-9][a-z0-9-]{0,39}$`；套餐 `^[a-z0-9][a-z0-9._-]{0,63}$`，套餐 id 在整份文档内唯一（约定以提供商 id 作前缀）。重复 id 无效。
- `name` 1–80；`region` ≤ 80；`notes` ≤ 500。
- `vcpu` 1–65536；`ramBytes` / `diskBytes` / `traffic.bytes` 为 1–2^53−1 的整数字节；`traffic.unlimited: true` 时不得有 `bytes`；`traffic.periodMonths` ∈ {1,3,12}，可省略。
- `price.amountMinor` 为 0–`Money.maxMinor` 的整数最小货币单位（0 表示免费），`currency` ∈ {USD,CNY,EUR}，`cycleMonths` ∈ {1,3,6,12,24,36}。不在受支持币种内的套餐使整份文档无效（发布方保证）。规格与价格各自可省略，缺失就是“未知”，预填时对应字段留空。
- 每个有套餐的提供商必须恰好一个 `default: true`。

## 3. 本地存储与 schema v12

- `providers`：新增 `catalog_id TEXT`，局部唯一索引 `providers_catalog_id ON providers(catalog_id) WHERE catalog_id IS NOT NULL`；名称唯一索引改为对全部提供商生效 `providers_name ON providers(name COLLATE NOCASE)`。
- `servers`：新增 `package_id TEXT`、`package_snapshot TEXT`、索引 `servers_package(package_id)`。
- 删除 `cloud_accounts`、`cloud_observations`、`cloud_bindings`，以及全部适配器触发器 / 守卫。
- `LedgerStore.schemaVersion = 12`。新库直接建 v12 结构，不再创建任何 cloud 表。

### 快照与差异提示

`package_snapshot` 是 `{ "snapshotVersion": 1, "catalogVersion": N, "providerId": "...", "id": "...", "name": "...", "vcpu"…, "price"…, … }`，即选择当时的套餐字段（不含 `default`），≤ 4 KiB，仅存本地与备份。

- 套餐页 / 服务器详情用当前目录与快照比较**规格字段**（忽略 `catalogVersion`）：不同 → “目录已更新”提示，并并排展示当前目录值与服务器记录的值；目录里找不到该套餐 → “目录已不再列出此套餐”。目录未加载（失败）时不显示任何差异提示。
- 套餐页对已下架套餐仍可打开：用快照渲染，同样列出关联服务器。
- 提示只是信息；不会自动改服务器。用户想采用新值时，在编辑表单里重新选择套餐（会预填并更新快照）。

### 选择套餐的预填

选择套餐 → 表单预填：硬件（vCPU / 内存 / 磁盘 / 流量 / 流量周期，缺失则留空）、费用（有价格 → 计费类型“预付”、金额、币种、周期；无价格则计费保持原值）、地区（仅当地区为空且套餐有地区）。到期日 / 起始日不预填。所有值照常可编辑，保存的是表单里的值。编辑已有服务器时重新选套餐会先确认“用套餐的值替换硬件与费用”。

## 4. 迁移 v11 → v12（以及更早版本）

`onUpgrade` 本身在 sqflite 的版本变更事务内运行；任一步骤抛错则整体回滚，库保持原版本，**绝不重建或清空**。对任意 `oldVersion < 12` 执行同一个 `_migrateToCatalogSchema`（旧版本链 v2–v9 的建表步骤保持不变；v5 起不再创建 cloud 表，因为它们马上会被删除）：

1. **秘密引用入队。** 若 `cloud_accounts` 存在，把每个 `secret_ref` 在同一事务内 `INSERT OR IGNORE` 进已有的 `secret_cleanup`。设备安全存储里的 API 秘密由现有清理机制删除（凭据页的“重试清理”，迁移与启动都不读取钥匙环）。`secret_cleanup` 对仍被 `credentials` 引用的 ref 有防护，不会误删 SSH 凭据。
2. **删除适配器结构。** 先删除 `providers` 守卫触发器（含建在 `servers` 上、引用 cloud 表的 `server_provider_update`），再依次删除 `cloud_bindings`、`cloud_observations`、`cloud_accounts`。`servers`、`payments`、`service_periods`、`ssh_configurations`、`credentials`、`host_trust`、`reminder_rules` 不受影响，也不删除任何服务器。
3. **提供商中性化。** 
   - 没有 `providers` 表（v10 本地 RackNerd 分支及更早）：创建表，增加 `servers.provider_id`，并按已知的 `vendor` 文字（不含 `服务商待填写` 占位，不区分 ASCII 大小写）为服务器建立提供商，与 v11 对旧库的做法一致。
   - 已有 `providers`（含 `needs_review` 列）：没有任何服务器的“待确认”提供商（来自适配器别名）删除；仍有服务器的保留并标为已确认，重名时追加 ` (2)`、` (3)`…（总长 ≤ 80）。`needs_review` 列保留但不再使用（SQLite 老版本无法安全 `DROP COLUMN`）；`auth_scope` / `pinned_server_id` 随 cloud 表消失。
   - 随后建立 `providers_name` 唯一索引并删除 `confirmed_provider_name`。
4. 新增 `providers.catalog_id`、`servers.package_id`、`servers.package_snapshot` 及索引；所有现有行取空值。
5. **清除 API 标记。** 对每个 `resources_json`，删除 `apiFields` 键，其余值逐字保留；`ServerResources` 不再写该键，读取时容忍并忽略它。不改 `revision` / `updated_at`。无法解析的 JSON 保持原样（读取路径本来就会报错），不因此阻断迁移。
6. `PRAGMA foreign_key_check` 必须为空，否则回滚。

验证：从字节级的真实 v11 DDL 夹具（含适配器实例、观测、绑定、守卫触发器、待确认提供商、`apiFields`）升级；断言服务器 / 付款 / SSH / 凭据逐字保留、秘密入队、cloud 表与触发器不存在、FK 检查干净、故障时回滚且 `user_version` 仍为 11。

## 5. 备份 JSON v2

- 写出方升到 **v2**：新增顶层 `providers`（`id`、`name`、`catalog_id`、`created_at`），服务器行新增 `provider_id`、`package_id`、`package_snapshot`（均可空，v2 必须出现）。这样恢复后提供商与套餐关联不丢。
- 读取方接受 **v1 与 v2**：v1 沿用原严格校验，没有 `providers`，服务器无提供商 / 套餐（与此前一致）；v2 对新增字段同样严格：提供商名称 1–80 且已 trim、大小写不重复、`catalog_id` 合法且不重复、`provider_id` 必须存在、套餐 id 与快照成对出现且快照通过 `CatalogPackage` 快照校验并与提供商的 `catalog_id` 一致。未知版本（>2）明确拒绝。
- 仍然**未加密、部分范围**，只恢复到空台账。v2 备份含提供商时，目标已有提供商 → 冲突（避免名称 / catalog_id 冲突）。适配器实例、观测、关联、secretRef 不会也从未导出。预览计数增加提供商数量。
- 目录本身（套餐列表）不在备份里；恢复后目录仍来自应用。

## 6. 界面流程（iOS 风格，Material 图标）

- **新增服务器**：服务器页“添加”直接进入服务器表单，不再有单独的选择提供商 / 选择套餐页。表单里“提供商”是一行下拉菜单（锚在该行下方）：“不指定”；“我的提供商”（本地提供商，含已添加的目录提供商，带套餐数）；“目录提供商”（尚未添加的目录提供商，带套餐数）；最后一项“新建提供商…”（弹出名称对话框，只在保存服务器时与服务器同一事务写入，取消表单不留下提供商）。选择目录提供商时，只有保存时才创建 / 关联本地提供商。有套餐列表的提供商才显示“套餐”下拉：“无套餐”+ 各套餐（名称、价格与规格），新增服务器时默认套餐预选并预填硬件与价格（已手动填写时先确认再替换；改选无套餐保留已填值）。编辑服务器用同样两行，更换套餐仍先确认。从提供商页 / 套餐页“添加服务器”同样直接进表单并预选。
- **提供商页**：我的提供商（含关联服务器数）+ 尚未添加的目录提供商；详情：套餐（目录提供商）与服务器。新建与重命名沿用现有行为（目前没有删除提供商的入口）。
- **套餐页**：规格、价格、默认标签、“目录已更新 / 已下架”提示、关联服务器列表（点进服务器详情）。
- **服务器详情**：“提供商与套餐”分区取代适配器行：提供商行（进提供商详情）、套餐行（进套餐页；无套餐显示“无”），更换通过编辑表单。
- 服务器列表副标题可显示套餐名。

## 7. 日后的远端 API 合同

`GET {base}/v1/catalog/providers.json`，`Accept: application/json`，HTTPS only。

```json
{
  "schemaVersion": 1,
  "catalogVersion": 7,
  "generatedAt": "2026-10-11T08:00:00Z",
  "providers": [
    {
      "id": "example-cloud",
      "name": "Example Cloud",
      "packages": [
        {
          "id": "example-cloud-starter",
          "name": "Starter",
          "default": true,
          "vcpu": 1,
          "ramBytes": 1073741824,
          "diskBytes": 21474836480,
          "traffic": { "bytes": 1099511627776, "unlimited": false, "periodMonths": 1 },
          "price": { "amountMinor": 500, "currency": "USD", "cycleMonths": 1 },
          "region": "Example Region",
          "notes": "Synthetic example."
        }
      ]
    }
  ]
}
```

- **版本**：`schemaVersion` 管结构；`catalogVersion` 为发布方递增整数，单调不减，用于日志与快照记录，不用于差异判断（差异按字段值）。
- **缓存**：响应带强 `ETag`；客户端保存上次成功文档与 ETag，之后发送 `If-None-Match`；`304` 沿用缓存。`Cache-Control: max-age` 作新鲜期（缺省 24 小时）。过期后先用缓存、后台刷新（stale-while-revalidate）。
- **失败**：网络错误、非 2xx、超大、解析 / 校验失败 → 保留旧缓存（无缓存则用内置目录）；校验失败的文档不覆盖缓存。`catalogVersion` 小于缓存版本的文档被拒绝（防回滚攻击 / 错配 CDN）。不跟随跨 origin 重定向，不发送任何台账数据或标识符，请求无 cookie / 凭据。
- 可选的按提供商分片（`/v1/catalog/providers/{id}.json`）使用同一提供商对象结构，不需要改变本地模型。

## 8. 删除的内容

适配器类型与 SolusVM / RackNerd 协议、实例（`cloud_accounts` 的“适配器实例”语义）、观测、服务器关联、授权范围与单设备 pin、六资源导入预览、API 来源标记、面板 TLS fixture 与相关界面 / 文案 / 测试，以及 `SOLUSVM*.md`、`RACKNERD.md`。提供商本身（名称、服务器归属、费用统计中的厂商分布）保留。

历史说明：2026-10 之前应用曾通过 SolusVM 1/2 与 RackNerd ctrl 的只读客户端 API 读取面板资源，三种协议各自独立、仅读取，且 API 秘密只存设备安全存储。该能力已按产品决定整体移除；协议细节可在 git 历史中的 `docs/SOLUSVM.md` / `docs/RACKNERD.md` 查阅。
