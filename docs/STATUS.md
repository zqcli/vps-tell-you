# 状态

更新：2026-10-06 UTC

## 当前检查点：阶段 3

凭据库、原生 SecretStore、SSH 配置与完整主机信任已实现。独立 Astra review **APPROVE**，源码无剩余阻塞。开发版仍为 0.1.0+1。

- Flutter 3.47.6 stable / Dart 3.13.5
- schema v3；v1 → v2 → v3 / v2 → v3 事务迁移，保留台账与财务资料
- 密码 / 私钥导入编辑搜索，关联查看、替换 / 解除与删除影响确认
- 先写入并校验新秘密、再提交引用、最后清理旧秘密；部分 / 迟到失败可恢复，无明文 fallback
- SSH 配置和台账分别保存；每台用户名独立，采用凭据默认值须明确确认
- 完整主机公钥与 host + port 信任；首次核验、拒绝、变化阻断、重新核实，版本和 generation 防止旧弹窗覆盖新信任
- 设备验证后密码短时显示；取消、离开 / 覆盖页面、后台、超时均隐藏，Linux 无设备认证时拒绝

## 最终源码聚合检查

- enforced offline lockfile：通过
- format：39 文件、0 changes
- analyze：无问题
- `flutter test`：**104 / 104**，含阶段 1–2 的 40 项回归
- Linux release build：最终源码通过
- diff check：通过

独立 review 额外补充 9 个回归；已修复私钥与公钥不一致却能导入、返回动画 / 覆盖页面 / 延迟元数据读取后的敏感查看、迟到文件选择、主机信任删除重建后的旧版本覆盖、首次核验 attempt 无法继续等问题；另外验证了迟到 native write 与清理的正确串行顺序。所有修正后重跑聚合通过。

## Linux 原生验证

实际 release app 与真实 flutter_secure_storage 插件；仅合成 fixtures。经明确授权，官方 GNOME Keyring 运行在隔离的临时 HOME / XDG 与专用 D-Bus，不修改正常钥匙环、PAM 或 autostart，不接收真实凭据。

- 原生存储写 / 读 / 覆盖、应用进程重启读回、删除 / 缺失通过
- 无 Secret Service 时拒绝写入；隔离 keyring Locked=true 且无解锁提示服务时返回 KeyringLocked，没有 reset / 明文回退
- 原生 UI：密码新增 / 修改 / 取消 / 搜索 / 分类；加密 Ed25519 系统文件选择器取消、错口令拒绝、正确口令保存
- 两台连接共用凭据，明确采用 / 拒绝默认用户名；更新密码或删除并替换引用都保留各自用户名
- 首次主机核验拒绝不保存；保存后变化显示阻断，拒绝保留旧 pin，明确独立重新核实后才替换
- 真正退出和重启最终 release，凭据元数据、两个引用及完整主机信任保留；v2 → v3 保留旧财务资料
- 最终源码原生无服务 UI 保存明确失败，凭据数不增加；测试结束清除临时钥匙环并停止专用 daemon
- 合成秘密不出现在 QA SQLite 或普通运行日志；截图与日志见验收记录。没有进行真实 SSH / 网络认证

## Git 与 CI 恢复

目标仅 `zqcli/vps-tell-you:dev`，普通提交和正常推送。后续提交用 `type(scope): description`。不自动 tag、强推或修改其他分支。

为避免文档记录自身 SHA 的递归提交，当前阶段 SHA / CI 以实时检查为准：

```sh
git status --short
git branch --show-current
git rev-parse HEAD
git ls-remote origin refs/heads/dev
```

[dev](https://github.com/zqcli/vps-tell-you/tree/dev) 与 [Actions](https://github.com/zqcli/vps-tell-you/actions/workflows/ci.yml) 必须是同一提交。工作流包含 libsecret 构建依赖、锁文件、format、analyze、全量测试和 Linux release。

前一已核实阶段 2：`65e000be14864015a3951487cbb1f2c281ef62b1`，对应 [成功 CI](https://github.com/zqcli/vps-tell-you/actions/runs/37407304072)。本阶段发布后的准确提交与 CI 需从 Git / Actions 核对，不能复用阶段 2 结果。

## 下一步与未运行项

1. 阶段 4：真实 SSH / TCP / 片段 / 单机电源；必须接入 HostVerificationAttempt，不绕过首次 / changed-key / 取消门禁
2. Android / iOS 仅完成安全配置源码；编译 / 签名 / 安装、Keychain / Keystore、Face ID / PIN、后台 / 锁屏 / 备份恢复均未验证
3. native share sheet / 通知仍留阶段 6；Linux 通过不能替代手机验收
4. CI checkout v4 Node20 弃用警告为已知非阻塞问题

详细矩阵见 `docs/ACCEPTANCE.md`。真实密码、私钥、API Token、用户数据库、QA keyring 均不得提交。已提交的 `.fixture` 密钥仅为测试生成，从未配置到任何账户 / SSH 服务，不具备实际访问权限。
