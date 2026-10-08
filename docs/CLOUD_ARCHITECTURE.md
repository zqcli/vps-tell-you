# 面板接入的共享结构

这层共享的是协议能力，不把销售厂商、面板产品、凭据形状或远端身份混为一谈。SolusVM 1 和 RackNerd ctrl 复用 Key/Hash 与单 VPS 读取流程，仍使用独立 wire protocol；SolusVM 2 保留账户清单和分页流程。

## 职责划分

| 类型 / 文件 | 职责 |
| --- | --- |
| `CloudProvider` / `cloud_models.dart` | 稳定持久化标识，以及单实例 / 账户清单身份语义 |
| `KeyHashCredentials` / `cloud_models.dart` | 共享 Key/Hash 字段与校验；具体 V1/RackNerd 凭据仍是不同类型 |
| `CloudProviderDefinition` / `cloud_provider_definition.dart` | 集中固定的适配器工厂、凭据输入/类型校验/存储编解码、输入地址规则、产品名和本地化说明 |
| `_SingleVpsAdapter` / `solusvm_adapter.dart` | 模板方法：独立会话、单次16 KiB读取、API状态校验、资源投影、最终取消检查、匿名快照 |
| `SolusVm1Adapter`、`RackNerdAdapter` | 实现固定请求与各自字段解析 hook，不探测、不回退、不重发凭据 |
| `_ReadSession` | 所有面板共用的严格 TLS、拒绝重定向、流式大小限制、请求/全局预算和取消隔离 |
| `_clientInstance` | 单 VPS API 共用的地址/hostname、字节四元组、状态冲突与秘密反射过滤 |
| `SolusVm2Adapter` | 独立的 account → projects → servers 分页及身份投影，同样组合 `_ReadSession` |
| `CloudController` | 生命周期、验证/保存/刷新协调、秘密读写及错误边界；不再维护厂商工厂和 codec 分支 |
| `LedgerStore` / `cloud_account.dart` | SQLite 事务、稳定身份、revision/generation 围栏、重授权解绑及资料保护 |

```text
CloudCredentials
├── KeyHashCredentials
│   ├── SolusVm1Credentials
│   └── RackNerdCredentials
└── SolusVm2Credentials

CloudAdapter
├── _SingleVpsAdapter<C extends KeyHashCredentials>
│   ├── SolusVm1Adapter  → multipart / status / XML
│   └── RackNerdAdapter  → form / info / JSON
└── SolusVm2Adapter      → Bearer / GET / paginated JSON
```

## 共享边界

- definition 是封闭、不可变的规则对象，不保存用户凭据、controller、HTTP client 或 session。产品映射只有一个穷尽入口 `CloudProviderDefinition.of(provider)`，没有运行时插件注册。
- 表单凭据形状由 `credentialKind` 决定，不能从 `isSingleInstance` 推断。后者只负责远端身份、资源补全和重授权语义。
- 共用 Key/Hash 父类不允许跨厂商混用凭据。创建 adapter 或编码前仍验证具体类型；V1 的 Key/Hash 不能作为 RackNerd 凭据传入，反之亦然。
- XML 与 JSON 解析器及白名单不合并。V1 可读取明确的 `vcpu/cpus` 扩展，RackNerd 不会因为共用投影就接受未经确认的 CPU 字段。
- 保持既有时序：V1 在 XML 解析前取观察时间；RackNerd 在 JSON 和成功字段校验后取时。每次成功只取一次 UTC 时间，`observedAt` 与 `completedAt` 相同。
- UI 与首次验证共用 definition 的输入地址解析；刷新已存地址仍要求严格 origin，不因为允许用户粘贴已知路径就放宽持久化地址。
- 本地化回调在显示时使用当前 `AppLocalizations`，不缓存翻译结果、不引用 Widget。切语言仍保留草稿，也不重发请求。

## 新增面板时

1. 先确认协议和身份：请求/响应、认证、资源单位、稳定ID及错误语义。兼容接口不代表相同产品。
2. 如果确实是同类匿名 Key/Hash 单VPS API，可复用 `KeyHashCredentials` 与 `_SingleVpsAdapter`，只提供具体凭据类型、固定请求和严格字段解析。不要为了共用而把不同分页或身份协议塞进模板。
3. 在 `CloudProviderDefinition` 集中声明工厂、凭据与地址规则、展示说明。控制器和通用表单无需新增厂商 switch；继续保留 `CloudAdapterFactory` / `clientFactory` 注入点供测试使用。
4. 新的持久化 provider 仍须显式更新稳定 enum、必要的数据库 CHECK 迁移及双语 ARB。这不是“注册后无需数据库设计”的插件框架。
5. 使用独立合成样例测试精确 wire protocol、凭据交叉拒绝、旧 envelope、地址边界、TLS/取消/预算、资源和身份保护。测试预期不要从 definition 自己的配置派生。

## 本次兼容约束

本次为保持行为的重构：schema 仍为 **10**，秘密 envelope 仍为 **version 1**，`solusVm1` / `solusVm2` / `rackNerd` 标识及其字段不变，JSON备份仍v1。旧 adapter import、公开构造、typed credentials/endpoint 和依赖注入保持可用；不要求旧连接重新授权，不迁移或重写用户秘密。

没有新增依赖、网络动作或授权范围。协议依据与安全合同见 [SOLUSVM](SOLUSVM.md)，验证结果见 [ACCEPTANCE](ACCEPTANCE.md)。
