# 状态

更新：2026-10-06 UTC

## 当前检查点：阶段 5

SolusVM 1 / 2 只读账户闭环已实现，本地验收完成。执行环境重建后，从已核实的远端阶段4 `d9e8d35079a7f41ec0e89332eda4af83f87dc063` 恢复，并重新 review / 测试；不复用丢失环境的通过结果。最终发布 SHA 与同 SHA CI 仍须从 Git / Actions 实时核对。

- Flutter 3.47.6 stable / Dart 3.13.5；开发版 0.1.0+1
- SQLite schema v5；v4 → v5 仅新增云账户、API 观测与关联，保留台账 / 费用 / 付款 / SSH / 主机信任 / 片段
- V1 单 VPS Key/Hash，仅读取 status；V2 用户 Token，仅 GET account / projects / project servers
- 严格 HTTPS / 主机名验证、自定义端口、拒绝重定向、分页与响应限制、取消与整体超时；不含 API 电源或写入接口
- 验证 → 选择导入 / 仅保存 → 继续导入 / 刷新 → 重新授权 / 解绑；独立账户允许同 endpoint 多连接
- V2 用户 / 项目 / 实例 ID 与 UUID 身份约束；V1 无稳定远端 ID，换凭据需明确解除旧关联再重新选择
- 秘密只进原生安全存储，先写新秘密 / 验证读回 / 提交引用 / 再清理旧秘密；durable cleanup 与云/SSH共享活动引用保护
- API 观测独立于手工资料 / 费用 / SSH；失败或缺失保留旧时间与观测，不冒充新鲜关机
- 持久化 generation / revision 与 UI 取消共同阻止迟到结果复活关联；Back / 后台 / 双击 / 2× 字号有回归
- 新复审修复：资料重读成功清除已解决的旧错误提示；不清除等待期间到来的新错误

## 本次新验收

- 全量 **335 / 335** 测试通过，串行运行，包含最新 SSH EOF / 输出排空修复
- format：0 changes；analyze：无问题；offline enforced lockfile / diff check 通过
- clean Linux production `lib/main.dart` release 构建通过，独立 fixture target 不进入生产入口
- 独立 Astra 复审通过；154 项相关测试覆盖协议/TLS、持久化、控制器、widget、安全/片段与额外菜单重复点击
- 原生 Linux：真实 NativeSecretStore、隔离临时 GNOME Keyring、私有 D-Bus 与本地 HTTPS 合成面板；验证两页清单、选择导入、重启后读取已存授权、继续导入去重、解绑保留2条台账
- 最终 SQLite：账户 / API 观测 / 关联 / 待清理引用均0，服务器2；无合成秘密标记。测试进程全部退出，临时钥匙环及TLS私钥已删除
- 390px / 2× 字号、V1 重绑、失败授权、保存失败、后台、Back 动画中迟到结果等由实际checkout的widget/协议回归验证

协议依据与边界见 `docs/SOLUSVM.md`；逐项记录见 `docs/ACCEPTANCE.md`。本次证据日志目录为 `../recovery-stage5/assembly-evidence/`，原生截图与安全清理记录为 `../vps-qa-stage5/`。源代码另有完整历史 Git bundle 备份，不包含真实秘密。

## SSH 修正

已整合重新实现并独立复审的双层 EOF 修复：先排空会话输出，再关闭；native socket 在库完成已排队数据包处理后通知 EOF。源修复提交为 `4d4e7c27fb13a89d58739c9d878c48868a135708`，在本阶段作为普通 cherry-pick 提交整合。8轮真实 fixture 尾部64KiB / UTF-8 / stderr 与取消丢弃回归通过。旧环境的未发布提交不当作现存对象。

## 发布与恢复

只正常推送 `zqcli/vps-tell-you:dev`；提交使用 `type(scope): description`。不创建 tag、不强推、不改其他分支。发布后必须核实远端精确 SHA 和该 SHA 的 CI，而非前一提交的绿色结果。

```sh
git status --short
git branch --show-current
git rev-parse HEAD
```

[dev](https://github.com/zqcli/vps-tell-you/tree/dev) / [Actions](https://github.com/zqcli/vps-tell-you/actions/workflows/ci.yml)。当前没有 shell Git 凭据时使用已授权 GitHub connector 正常更新 dev；不新建 PAT，也不提取浏览器凭据。最终 SHA 以实时检查为准，避免文档自身 SHA 的递归提交。

## 下一阶段与明确未验项

1. 阶段6：提醒 / 分享 / 备份 / 外观与移动适配；仅在阶段5发布门通过后整合
2. iOS / Android 安装、签名、Keychain / Keystore、Face ID / PIN、IME、旋转、切网、后台、通知和原生分享仍待真机
3. VirMach 仅按用户确认的 SolusVM 1 模板准备；实际 Client API 开放、权限、证书、字段与兼容性未连接验证。真实凭据只能由用户在原生应用自行输入
4. 本次没有生产面板请求、真实 VPS 电源操作、云资源销毁或厂商支付
5. Linux / fixture / widget 通过不能替代手机验收；后台不承诺常驻连接或实时监控
