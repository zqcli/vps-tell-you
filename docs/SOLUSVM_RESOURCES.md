# SolusVM 1 六项资源导入

## 行为

生产验证、继续导入与手动刷新现在共用一次有界、只读 `action=status` 请求，附带 `ipaddr=true`、`mem=true`、`hdd=true`、`bw=true`、`status=true`。不重复请求 info，不调用管理员接口，不请求电源或配置修改。

导入页展示并要求确认六项资料：IP、hostname、磁盘额度、流量额度、内存容量、vCPU 数量。有效 API 值预填；未提供、全零或无效的配置值必须手动补齐，不能伪造套餐信息。不知道时可以仅保存账户，稍后核实再继续导入。财务仍在导入后的本地编辑页补充，导入不要求金额或到期日期，不把未知价格当免费。

- IP 支持 IPv4/IPv6，拒绝全零未指定地址、zone 后缀和混入非法数据的列表；不会触发连接或主机信任。
- hostname 支持单标签或 FQDN，包括大小写；不拿 hostname/IP 作为稳定远端身份。
- `mem/hdd/bw` 使用经过结构校验的 `total,used,free,percentage` 字节四元组。配额仅取 total；合法 usage=0 保留，绝不改作缺失配额，也不把 free 当配置。
- 可选兼容字段 `vcpu/cpus` 仅接受 1–65536 的整数；两个字段冲突时标未知。不把 cpu 使用率、套餐名或 hostname 推断成核数。
- 流量配额 0 不代表无限。只有用户明确选择“已确认套餐流量不限量”才保存独立的 unlimited 标记；没有猜测服务商的无限量编码。
- 手填单位为 B/MiB/GiB/TiB（1024 进制），十进制输入按整数算术换算，必须精确到整字节；不接受 NaN、指数、负数或超出安全整数范围。

## 本地保存与刷新

schema v7 仅给 servers 添加可空 `resources_json`；旧 v1–v6 数据通过事务升级，不改旧服务器、费用、付款、SSH、云授权、提醒或外观。完整本地资源配置使用一个有类型的值对象并逐项记录导入时 API/手动来源。字段缺失的旧记录继续有效。

API 观测仍独立保存在 cloud_observations 的白名单 JSON。刷新只更新观测，不覆盖用户核对的本地六项值、费用或 SSH。详情分别显示本地资源与带时间的 API 观测；本地编辑可以调整资源并将修改项标为手动。解除关联保留本地配置。

新 V1 导入在控制器与数据库事务中都验证完整配置；账户仅保存不要求六项。旧关联按本地账户隔离的 singleton 去重，不按 IP/hostname 合并。空台账备份格式 v1 兼容增加可选 resources_json：旧备份仍可恢复，新备份保留本地资源，但仍排除云账户、秘密引用、API 观测和 SSH。

## 协议依据及兼容限制

- [SolusVM 官方 Client API](https://docs.solusvm.com/en/solusvm1/api/client/client-overview/)：每 VPS Key/Hash 权限和入口。
- [SolusVM 官方 Client 示例](https://docs.solusvm.com/en/solusvm1/api/client/php-code-examples/)：POST/status 请求。
- [BuyVM 官方兼容 API](https://wiki.buyvm.net/doku.php/clientapi)：资源标志与字节四元组。其 mem/hdd 标注 OpenVZ，不能据此保证所有 KVM 厂商可用。
- [Raycast 扩展实现](https://github.com/raycast/extensions/blob/main/extensions/solusvm-1-client/src/api.ts)和[响应类型](https://github.com/raycast/extensions/blob/main/extensions/solusvm-1-client/src/types.ts)：资源标志、hostname/vmstat。
- [V1 Admin server-information 的 cpus 定义](https://docs.solusvm.com/en/solusvm1/api/admin/virtual-server-functions/virtual-server-information/)与 [SolusVM vCPU 说明](https://docs.solusvm.com/en/solusvm2/quick-start-guide/administration/)仅用于确认可选响应字段的数量语义，不证明 Client API 保证返回这些字段，更不授予管理员权限。实现不会调用 Admin API。

在先前独立 VirMach 只读诊断中，用户本人提交的 info/status 返回相同的 IP、hostname、磁盘与流量，内存全零、无已知 CPU 字段。真实值和凭据不进入仓库。此事实不能保证其他提供商完全兼容；各字段仍逐一验证。

## 验证状态

合成协议、TLS、控制器、数据库迁移/刷新、备份和 390px 大字表单测试覆盖完整 API、缺项补齐、零值、无限流量、单位换算、重复点击和生命周期取消。真实新增流程已在生产 Linux 构建中验证：用户亲自提交只读请求并补填内存/vCPU，API预填的另外四项与本地导入、来源区分、单独重启持久化均通过。费用/SSH仍保持原有边界。最终独立全量571项测试通过；Linux原生测试不等于Android/iOS真机认证，具体记录见 STATUS/ACCEPTANCE。
