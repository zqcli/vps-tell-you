# SolusVM 只读协议与身份边界

协议基线核对：2026-10-06。测试使用合成数据与临时本地 HTTPS 服务，不包含生产凭据或真实面板响应。

## 读取范围

- SolusVM 1：每组 Client API Key/Hash 仅对应单台 VPS；仅 multipart POST `/api/client/command.php`，字段恰为 `key`、`hash`、`action=status`。凭据只在请求体中。
- V1 XML：读取 `status/statusmsg`。成功且 `online/offline` 映射开/关；其他成功文本为未知。API error 为通用读取拒绝，不凭错误文本断言授权撤销。未有官方依据的 IP、名称、规格、远端稳定 ID 保持未知，不能借用管理员接口。
- SolusVM 2：Bearer Token 仅在 Authorization header；只允许 GET `/api/v1/account`、`/api/v1/projects?page=N`、`/api/v1/projects/{positive-id}/servers?page=N`。项目 ID 来自验证后的项目列表。共享项目不会因所有者不同被隐藏。不调用全局 `/servers`、电源、写入、token 或管理员发现接口。
- V2 显式 DTO 仅投影 ID/UUID、项目、名称、地址、规格、位置、镜像名、开关状态与暂停标记。RAM 是 bytes，disk 是 GiB；`real_status` 存在时优先，未知不得用 status 补成开机。账单、账户邮件、billing token、VNC 密码与登录链接、SSH 信息不进入 DTO。

## 网络与解析

- 仅接受 HTTPS origin，保留合法自定义端口，拒绝 userinfo、query、fragment、未知路径与 dot-segment。V1 已知 `/home.php` 可显式规范为 origin，表单须让用户看到最终地址。不会自动换域名、端口或猜测 API。
- 严格使用平台证书/主机名验证；默认 client 无证书绕过。测试只为本地临时证书显式建立私有 trust context。
- 一律拒绝重定向。分页链接必须同 HTTPS origin、同有效端口、同 collection path，仅 page 参数、严格下一页；验证后重建请求。分页环、重复/跨项目 ID、矛盾 meta、过大清单返回失败，不发布部分库存。
- 默认每请求 15 秒、整体读取 90 秒、200 次请求、10,000 条项目/实例、每响应 1 MiB、总响应 16 MiB。V1 XML 独立收紧为 16 KiB，且在实体解码前生效；禁用 DTD/处理指令、限定嵌套/节点。JSON 深度与节点数有限制。
- 取消/超时关闭本次独立 client；迟到响应被消费/取消，不发布成功。错误仅有固定本地文案，不透传 body、URI、异常或秘密。不自动重试。

## 关联与后续验收

V1 没有官方稳定身份，连接由本地 ID 隔离；换 Key/Hash 不能推断仍是原 VPS。V2 身份必须包含本地账户、已验证远端账号、项目及实例 ID，UUID 用于额外一致性检查。不能按 endpoint、名称或 IP 合并。状态更新与手工台账/费用/SSH 字段分离；失败保留原观察时间，绝不假作新鲜关机。

用户提供的 VirMach 面板 `https://vps.virmach.com/home.php` 按用户确认的 SolusVM 1 模板处理。实际 API 开放、权限、响应和证书仍待用户在原生应用自行输入凭据验收，尚未连接或验证兼容性。不能在聊天或开发环境索取真实秘密。

## 官方依据

- V1 per-VPS Client API：https://docs.solusvm.com/en/solusvm1/api/client/client-overview/
- V1 POST/status 示例：https://docs.solusvm.com/en/solusvm1/api/client/php-code-examples/
- V2 API 文档：https://docs.solusvm.com/en/solusvm2/api-reference/api/
- V2 OpenAPI schema：https://installer.dev.solusvm.com/admin-docs.json
- V2 官方 SDK 分页：https://github.com/solusio/solus-go-sdk/blob/master/projectServers_gen.go

官方 V1 Functions 链接缺失，未验证的可选信息开关不采用。V2 schema 不保证任何具体服务商 CLIENT/custom role 的权限；403 不触发管理员 fallback。本 App 只使用读取能力，不代表用户 Token 本身是只读授权。
