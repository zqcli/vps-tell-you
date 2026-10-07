# RackNerd ctrl 接入

## 使用方式

从「从面板账户导入」或「设置 / 面板账户」新增连接，选择 **RackNerd ctrl**。填写：

- 面板地址：`https://ctrl.racknerd.com`，也接受精确的 `https://ctrl.racknerd.com/api/client/command.php`；末尾不要加句号、查询参数或凭据。完整 API 路径会被明确规范为 origin，并显示最终地址。
- API Key / API Hash：该 VPS 的客户端 API 凭据，不是网页登录密码、管理员凭据或 SolusVM 2 Token；需先在面板启用 API。
- 验证后核对六项资源。API 未返回的 CPU 核数需要手动核实补填；没有核实前可以仅保存面板连接，稍后继续导入。

不要把已有 SolusVM 1 连接静默改成新类型。不同协议另建连接；旧连接与台账仍保留，是否解除旧关联由用户决定。

## 为什么不修改 SolusVM 1

2026-10-08（UTC+8）用户提供面板内 API 文档，并授权有限的真实只读诊断。确认该入口显示为 `ctrl.`，实际响应存在以下差异：

| 项目 | 现有 SolusVM 1 合同 | RackNerd ctrl 实测 |
| --- | --- | --- |
| `status` XML | 顶层字段片段或 `<response>` | XML 声明和 `<ctrl>` 根节点 |
| 资源读取 | `status` 加资源标志 | `status` 仅给状态，`info` 加资源标志给资源 |
| 新适配器表示 | 保留 multipart / XML | form-urlencoded / 显式 `rdtype=json` |

因此旧 XML 解析器将 RackNerd 响应判为协议不符，即使放宽包装，也不能从其 `status` 取得资源。新类型独立选择正确协议，不改变其他厂商的 V1 请求或解析，也不自动探测、重试或切换协议。

**可以确认的是 RackNerd ctrl 提供了 SolusVM 1 风格的兼容客户端接口；不能仅凭路径和 Key/Hash 认定其底层就是 SolusVM 1，也没有依据归为 SolusVM 2。** 本应用使用可验证的接口名称和合同，不猜测服务端实现。

## 只读合同与数据边界

只执行一个 `POST /api/client/command.php`：

```text
Content-Type: application/x-www-form-urlencoded
key / hash
action=info
rdtype=json
status=true
ipaddr=true
bw=true
hdd=true
mem=true
```

凭据使用结构化 form 编码，保留 `+ / & =` 等字符原义，绝不放入 URL。保留平台 TLS/主机名验证、禁止重定向及既有超时/取消预算。无 `boot`、`reboot`、`shutdown` 等 API 电源方法。

响应最多 16 KiB。JSON 检查深度、节点数、重复键及字段类型；HTTP 200 的 `status=error` 仍为失败，错误信息不回显远端正文。只投影经过验证的状态、IP、hostname 和资源：`mem/hdd/bw` 为 `total_bytes,used_bytes,free_bytes,percent`，额度取 total。零额度不代表无限；CPU 不从 OS、模板或套餐名推断。

每组凭据仅对应一个匿名 VPS，无伪造远端 ID。凭据保存在原生安全存储；SQLite 只保留不透明引用。重新授权必须明确确认解除旧云关联，旧服务器、费用、付款和 SSH 保留；刷新不覆盖用户维护的本地字段。

schema v10 扩展云账户类型约束，真实 v9 升级在事务内迁移完整云外键关系，失败回滚。台账 JSON 备份仍为 v1，不增加云账户、关联或秘密。

## 验证范围

- 合成协议、真实 loopback TLS、取消/超时、秘密反射、原 V1/V2 精确合同回归。
- 真正的旧 v9 DDL 与已有账户/观测/关联的迁移、重开、晚期失败回滚，以及原台账/付款/SSH 保留。
- 真 adapter → controller → 双语 UI 的补 CPU、仅保存再导入、重新授权与离线本地关联回归。
- 主会话使用生产 `RackNerdAdapter` 和默认 TLS 客户端真实读取一次 `info`，取得有效 IP、hostname、内存、磁盘、流量；CPU 保持未知。真实凭据和响应未写入源码、合成 fixture 或提交。
- iOS 26.2 模拟器重新编译并原位更新，schema 9 → 10，已有四条演示记录保留。未替用户把真实 RackNerd 账户写入模拟器；真实安全存储保存、补填后点击导入仍须用户确认操作。

完整测试结果、既有主题 golden 差异和模拟器记录见 [ACCEPTANCE](ACCEPTANCE.md)。不将只读验证或模拟器启动等同于真机权限、通知、后台及安全存储全部验收。
