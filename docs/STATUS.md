# 状态

更新：2026-10-06 UTC

## 当前检查点：阶段 2

费用、付款、计算器与 PNG 源码已实现；最终独立 Astra review **APPROVE**，无源码阻塞。当前版本号仍为开发版 0.1.0+1。

- Flutter 3.47.6 stable / Dart 3.13.5
- schema v2，真实 v1 → v2 事务迁移；原台账、分组和归档保留，不虚构历史付款
- 精确原币 / FX 财务、费用概览与下钻、六个月预测、1–3 期续期与独立账户账单、安全撤销
- 独立 / 引用计算器、报价手续费、计算信息复制与白名单 PNG 预览 / 保存
- 无新状态管理、路由、代码生成或业务框架；只增加用于路径回归的现有 platform-interface 直接开发依赖

最终源码聚合检查均通过：

- `dart format --output=none --set-exit-if-changed lib test`：26 文件，0 changes
- `flutter pub get --enforce-lockfile --offline`：通过
- `flutter analyze`：无问题
- `flutter test`：**40 / 40**，含阶段 1 的 16 项回归
- `flutter build linux --release`：最终修正后成功
- `git diff --check`：通过

## Review 与原生复验

独立 review 覆盖迁移、BigInt / FX、日历边界、付款 / 撤销的事务与幂等、修改保护、试算不回写、PNG 白名单与异步取消。审查补充的撤销最终步骤回滚、390px / 2×文字最大金额及报价测试已纳入 CI。

原生 Linux 复验发现并修正：最小环境缺 xdg-user-dir 时无法定位 Downloads / Documents，PNG 现只对不可用目录回退至 application-support/exports；权限 / 写入故障仍保留预览并允许重试，不换位置掩盖。部分字体缺少约等号 / 箭头，统一改为“约” / “至”。最终 release 已实际退出重启，付款 / 撤销 / FX 状态保留；PNG 保存与缺字修正均已原生复验，两份 1080×1408 文件解码和视觉检查通过。完整流程与文件证据见 ACCEPTANCE。

## Git 与 CI 恢复

目标仅 `zqcli/vps-tell-you:dev`，只做普通提交与正常推送，不自动 tag / 强推 / 改其他分支。为避免文档为了记录自身 SHA 再产生递归提交，本文不内嵌当前检查点的自身 SHA；恢复时实时核对：

```sh
git status --short
git branch --show-current
git rev-parse HEAD
git ls-remote origin refs/heads/dev
```

[dev 分支](https://github.com/zqcli/vps-tell-you/tree/dev)与 [Actions](https://github.com/zqcli/vps-tell-you/actions/workflows/ci.yml) 必须指向同一提交才算发布核实，不能拿旧 run 当作本阶段验证。该工作流执行锁文件、format、analyze、全量测试和 Linux release build。

前一已核实基线为阶段 1 文档提交 `a5edaea`；其 [Actions](https://github.com/zqcli/vps-tell-you/actions/runs/37403922185) 已成功。阶段 1 原生台账验收与源码发布记录保留在 ACCEPTANCE。

## 下一步与未运行项

1. 阶段 3：凭据库、SecretStore 与主机信任；不提前实现 SSH / 云 API
2. 后续 CI 维护可更新 checkout action：v4 的 Node20 弃用警告非阻塞
3. Android / iOS 编译、安装与真机权限尚未验证；原生 share sheet 留阶段 6。Linux 通过不代表手机安全存储、SSH、通知或分享通过

详细回归与设备边界见 `docs/ACCEPTANCE.md`。真实密码、私钥、API Token、用户数据库与 QA 数据库均不得提交。
