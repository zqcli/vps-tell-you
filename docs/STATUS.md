# 状态

更新：2026-10-06 UTC

## 当前检查点：阶段 4

真实 SSH / TCP / 命令片段与单机电源确认已实现。阶段 3 的最后已发布提交为 `3452ff704cf1b4576f95fa41647ac3d097c08474`，对应 [成功 CI](https://github.com/zqcli/vps-tell-you/actions/runs/37410873046)。本阶段精确发布 SHA / CI 从下述 Git / Actions 实时核对，不把阶段 3 的 CI 当成本阶段结果。

- Flutter 3.47.6 stable / Dart 3.13.5；开发版 0.1.0+1
- SQLite schema v4；v1 / v2 / v3 升级保留台账、财务、安全资料，只新增片段表
- dartssh2 4.1.0 + xterm 4.0.0，真实原生 socket / 握手 / 密码与密钥认证 / PTY / resize / 特殊键
- 完整主机公钥绑定库已校验签名的 SHA-256，首次拒绝 / changed pin / stale prompt / 取消均阻止认证；不关闭验证
- 加密私钥导入默认不存解密口令，可明确选择保存。未保存每次连接单独输入；错误 / 取消 / 超时 / 迟到答复 / 换目标不会发起连接或认证
- 临时口令与登录密码分别标注；本机解密后才连 socket，口令不写 DB / 日志 / 草稿 / 远端。重新连接不记忆临时口令
- SSH 快速连接与服务器详情使用同一终端流程；演示记录禁连；退出 / 后台 / 换目标清理，手动重连不重放输入
- 单目标 TCP：本机来源 / 完成时间 / IPv4 / IPv6，取消与旧请求隔离；不将端口连通声称为开机或业务健康
- 片段 SQLite CRUD 与完整转义预览，插入只到独立未发送草稿；Send 再核对完整目标 / 内容 / 可选 Enter
- 单机 SSH 重启 / 关机两阶段确认、typed target、每会话至多一次，不支持开机 / API power。测试用 spy，不实际执行电源命令

## 自动验证

- 独立 AsyncSSH loopback fixture，合成用户名 / 密码 / 私钥，全程不调用 OS shell / exec、不配置 OS 账户或 authorized_keys
- 真实协议密码好 / 坏、加密私钥已存 / 未存口令、wrong / cancel / timeout / reconnect、Ed25519 / RSA / ECDSA host key、PTY / resize / split UTF-8 / stderr / final-output-before-close、认证门禁、失效 pin / credential、socket 清理
- 独立 review 对完好公钥 + 损坏 KEX 签名使用本地代理验证：不进入用户核验回调，认证为零
- 本地观察器碎片 / 畸形 / 大小限制 / GEX / NEWKEYS / RSA 签名算法与公钥类型边界
- 片段 CR / LF / NUL / bidi 保存往返、CAS / v3→v4；真实 IPv4 / IPv6 loopback TCP、refused 与 synthetic timeout / cancel / stale socket
- Widget：草稿插入 / 取消 / 换目标 / 重连无发送，完整 Send，双击导航 / Send / power 防重复，加密私钥导入默认 / opt-in、隐藏口令清理，390px / 2× 字号

最终源码 format：60 文件 / 0 changes；analyze 无问题；全量 193 / 193 测试通过；enforced offline lockfile / diff check / Linux release 全通过。独立 Astra review APPROVE，最后箭头图标修正后重跑并复审通过。发布 SHA / CI 在阶段收尾后核实。测试依赖与命令见 README / test/support/ssh_fixture/README.md；依赖缺失显式失败，不静默跳过。

## Native Linux 状态

真实 release / NativeSecretStore 使用隔离临时 GNOME Keyring + 私有 D-Bus，仅合成 fixture。正常钥匙环、PAM、autostart、真实凭据从未访问或修改。

已验：未存口令的加密私钥每次单独询问；错误 / 取消无 socket；进程重启后仍重新询问；首次 host reject 只有连接 / 关闭、零认证；独立核对完整公钥后真正 Ed25519 签名登录，xterm 显示分片 UTF-8 中文 / stderr；PTY / resize 记录正确；片段插入与 Send 取消零字节，确认后精确一次发送 22 字节 CR / LF / control 内容；Ctrl+C / Arrow 上行字节正确。

原生箭头缺字改为 Material icons；清理增量构建遗留的旧字体 subset 后，clean release 的四方向图标已截图核实。额外通过密码真实登录、changed host 拒绝及独立重新核实、进程重启复用正确 pin、终端直接键盘 / Back 退出 socket 清理、TCP 成功 / 拒绝 / 改目标立即清旧结果。验收结束停止 app / SSH fixture / 专用 keyring，移除临时钥匙环；日志和 SQLite 不含合成秘密。截图 / fixture 日志保留在隔离验收目录；没有执行电源操作。

## 发布约束与恢复

目标仅 `zqcli/vps-tell-you:dev`，正常推送；提交 `type(scope): description`。无 tag / force / 其他分支。实现 → 测试 → 独立 Astra review → 修正重跑 → 文档 → 正常 dev push → 精确远端 SHA + 同 SHA CI。

```sh
git status --short
git branch --show-current
git rev-parse HEAD
git ls-remote origin refs/heads/dev
```

[dev](https://github.com/zqcli/vps-tell-you/tree/dev) 与 [Actions](https://github.com/zqcli/vps-tell-you/actions/workflows/ci.yml) 必须是同一提交；避免文档自身 SHA 的递归提交，最终 SHA 以实时检查为准。CI 包含 Linux 依赖、固定 Python SSH fixture、锁文件、format、analyze、全部测试、Linux release。

## 下一步与未运行项

1. 本阶段本地验收完成，正常 dev 发布后核实同 SHA CI 并暂停；下一阶段为 SolusVM 1/2 只读闭环
2. Android / iOS 编译、签名、安装、Keystore / Keychain、Face ID / PIN、真实键盘 / IME / 旋转 / 切网 / 后台均未验证
3. 用户真实 VPS 兼容性、sudo / shutdown 权限和实际重启 / 关机未测试，不在云端使用真实凭据
4. native share sheet / 提醒仍为阶段 6；Linux / widget 通过不能替代真机
5. xterm 光标键小型兼容修正及 dartssh2 完整公钥观察边界须在升级依赖时重新核验
6. CI checkout v4 Node20 被 runner 提升 Node24 的既有警告非阻塞

秘密和临时 keyring 不提交。完整历史验收见 `docs/ACCEPTANCE.md`。
