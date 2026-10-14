# 提供商目录（catalog）

应用内“提供商目录”的数据源：服务商名称、别名、简介、官网和 Logo。**不随应用打包**；应用启动时（至多每 12 小时一次）和用户点“检查更新”时从 GitHub 下载并缓存，下载失败时继续使用缓存，没有缓存时目录为空（仍可选“无”或新建自己的提供商）。

```
catalog/
  README.md                    本文件
  index.json                   由 tool/build_catalog.py 生成，应用只轮询这一个文件，不要手改
  providers/<id>/provider.json 每个提供商的数据（唯一的事实来源）
  providers/<id>/logo.png      Logo
```

## 添加或修改提供商

1. 新建（或修改）`providers/<id>/provider.json` 并放入 `logo.png`。
2. 运行 `python3 tool/build_catalog.py`：校验全部提供商并重新生成 `index.json`（只依赖 Python 标准库）。
3. 提交 `providers/<id>/` 与 `index.json`。CI 会运行 `python3 tool/build_catalog.py --check`，`index.json` 过期时失败。

`<id>` 是稳定短标识，**一旦发布永不更改、永不复用**：用户本地的提供商通过它关联到目录。规则 `[a-z0-9-]{2,40}`，必须与文件夹名一致。

### provider.json

```json
{
  "id": "aliyun",
  "name": {"zh": "阿里云", "en": "Alibaba Cloud"},
  "aliases": ["Aliyun", "Alibaba Cloud", "阿里云"],
  "kind": "cloud",
  "region": "cn",
  "website": "https://www.aliyun.com",
  "description": {"zh": "阿里巴巴集团旗下的云计算服务商。", "en": "Cloud computing services from Alibaba Group."}
}
```

| 字段 | 规则 |
| --- | --- |
| `id` | 见上，与文件夹同名 |
| `name` | `zh` 与 `en` 都必填，1–80 字符，无首尾空白。中文界面显示 `zh`，其他语言显示 `en` |
| `aliases` | 搜索用的别名（含常见简称、英文全称、中文名），至多 20 个。**整个目录内**名称与别名（不区分大小写）不能重复，一个词只指向一个提供商 |
| `kind` | `cloud`（云厂商）或 `vps`（VPS 主机商） |
| `region` | `cn`（以中国大陆为主）或 `global` |
| `website` | `https://` 官网地址 |
| `description` | `zh` ≤ 40 字、`en` ≤ 120 字符，一句话说明它是谁；不写价格、套餐或评价 |

未知字段会被拒绝（防止拼写错误）。

### Logo

- 方形 PNG，**256 × 256**，**≤ 64 KiB**；
- 透明或白色背景（应用把它放在白色圆角底板上，深色模式也一样）；
- 图形居中，四周留约 12 % 边距（约 30 px）；
- 脚本检查 PNG 文件头、尺寸与大小，并写入 `sha256`；应用下载后逐一校验，不符的文件不会被使用。

当前 `aliyun`、`aws`、`racknerd` 三个是**开发用占位数据**（彩色底板加字母，非官方标识），会被真实目录替换。

## 商标说明

目录里出现的名称与 Logo 是其各自权利人的商标，仅用于让用户识别自己使用的服务商（指示性使用），不表示与这些公司存在任何关联、认可或合作。权利人要求移除时，删除对应文件夹并重新生成 `index.json` 即可。请只提交你有权使用的素材。

## index.json

由脚本生成，按 `id` 排序、字段顺序固定，同样的输入总是得到同样的字节：

```json
{
  "schemaVersion": 1,
  "catalogVersion": 3,
  "generatedAt": "2026-10-12T00:00:00Z",
  "providers": [ { "...provider.json 的字段...": "", "logo": {"path": "providers/aliyun/logo.png", "sha256": "…", "bytes": 5123} } ]
}
```

- `catalogVersion`：内容（任何提供商、文字或 Logo）变化时加 1，没有变化时保持不变，`generatedAt` 同时更新。应用不接受比缓存更小的版本。
- 结构不兼容时才会提高 `schemaVersion`；应用拒绝不认识的版本。

## 本地测试

```sh
python3 -m http.server 8000                  # 在仓库根目录
flutter run --dart-define=VPS_CATALOG_BASE=http://<本机地址>:8000/catalog/
```

`VPS_CATALOG_BASE` 会替代内置的两个地址（GitHub raw 与 jsDelivr 镜像）。下载协议、缓存与隐私见 [docs/PROVIDERS.md](../docs/PROVIDERS.md)。
