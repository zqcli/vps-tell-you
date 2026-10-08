# 阶段 1–4 验收

日期：2026-10-06 UTC。SDK：Flutter 3.47.6 / Dart 3.13.5。

## 阶段 1 已运行

- `dart format --output=none --set-exit-if-changed lib test`：0 changes，通过
- `flutter analyze`：无问题
- `flutter test`：16 项通过
- `flutter build linux --debug`、`flutter build linux --release`：成功
- `flutter pub get --enforce-lockfile --offline`：成功，固定依赖可复现解析

关键自动回归：

- 真实临时文件 SQLite：新增 / 改价 / 免费金额 / 常用 / 组名持久化，关闭重开保留同一 ID
- 删除分组后活动与归档记录都进入未分组；归档→删组→重开→撤销不丢字段，旧撤销不能重复执行
- 组排序 / 同名拒绝 / 已删除分组的过期表单写入回滚；旧编辑版本不能覆盖新值
- 显式演示数据与重复加载防护；搜索 / 常用 / 分组 / 到期排序及未来 30 天半开边界
- 已提交写入后读取失败仍返回成功结果；列表 / 详情 / 设置 / 分组 / 归档显示重读提示并禁用后续写入。SQLite-backed Widget 回归验证：编辑已提交、详情旧数据提示、再次重读失败、成功恢复及后续编辑
- 较新 schema 和损坏数据库拒绝打开，原文件 / 标记保持，不自动删库重建
- 日期闰年 / 月底 / 日序数，整数金额，未知与 0，非法主机 URL
- Widget：默认空态、保存后详情、编辑取消 / 返回、新增返回不保存、归档确认取消 / 撤销、分组弹窗取消 / 重命名 / 删除
- 390×844、1× 与 2×文字：四 Tab / 列表 / 详情 / 编辑 / 分组无 Flutter 布局异常
- 打开失败可重试，无自动演示或假成功

## 阶段 1 已验证的 Linux 原生 GUI

由独立操作真实 Linux 应用验证，使用隔离的合成 QA 台账：

- 首次启动为空；填写新增草稿后取消，仍为 0 条记录
- 新增 `qa-one` / `testvendor` / `192.0.2.10`，进入已保存详情
- 设置常用；编辑名称后返回，原名保留
- 复制主机地址时界面显示成功提示；未额外读取剪贴板内容
- 搜索无匹配结果；清除搜索后记录重新出现
- 创建 `qa-group` 并将服务器分配到该组
- 在终端停止应用，实际窗口消失；使用同一 SQLite 重新启动，`qa-one` 与常用状态保留
- 最终修正 build 重新启动后：两条合成记录仍在；默认常用优先；切到名称排序时 `a-qa` 排在 `qa-one` 前；常用筛选只保留 `qa-one`
- 分组筛选只显示 `qa-group` 内记录；已过期筛选不匹配未知日期记录，清除筛选恢复列表
- 归档确认取消后详情保留；确认归档后活动数下降；点击撤销恢复原记录（最终 build 已重跑）
- 删除包含服务器的 `qa-group` 后，记录转入未分组，活动数不变；已选旧组筛选自动清除
- 再次归档 `qa-one`，停止应用并核实窗口消失；重启后归档状态保留；从设置的归档列表恢复成功，SQLite 只读复核确认原 ID、地址和常用状态保留，group_id 与 archived_at 均为空

云端窗口管理器将原生窗口设为 1180×812，覆盖代码请求的 430×900。实际宽窗口已验，390×844 / 2×文字仍属于自动 Widget 验证，未冒充窄屏真机截图。

截图保留在验证环境，未随源码发布。独立 Astra 最终源码 review 发现并复审通过“已提交写入但重读失败”的跨页面提示与写入保护修正；最终独立聚合检查通过。

## 阶段 1 发布验证

- 源码提交 `2bd509ddccb749f88a5314212e4dd3b239907749` 已正常推送至 `zqcli/vps-tell-you:dev`；`git ls-remote` 与本地 SHA 一致
- 同一源码 SHA 的 [GitHub Actions #1](https://github.com/zqcli/vps-tell-you/actions/runs/37403531097) 已成功：Linux 依赖、锁文件、format、analyze、16 项测试与 release build；总时长 3m 2s
- 非阻塞警告：checkout v4 的 Node20 运行时被 GitHub runner 替换为 Node24；后续可更新 action
- 此后补充发布文档的提交不改变源码；当前分支最终 SHA / CI 应从 Git 与 Actions 实时核实

## 阶段 1 当时未运行的手机与后续能力

Android / iOS 安装、重启持久化、Android release；iOS Xcode 构建 / 签名；原生安全存储、SSH、API、通知投递、PNG 分享。当前阶段未实现这些能力，未把占位说明算通过。

截图与日志由执行环境保留，仅记录已核实结果；不提交任何用户真实台账或秘密。


## 阶段 2 自动回归（2026-10-06 UTC）

- 真实 v1 fixture 升级为 v2、关闭重开保留 ID / 分组 / 归档 / 字段；只建立可推断期间，不虚构付款或 FX
- 月底原锚点、闰年与 365/366 天、到期当天 0、未来完整期、100 年试算界限
- BigInt 精确比例 / FX，0.10 + 0.20、先合计后舍入、最大金额乘汇率不溢出、原币小计与缺 FX 覆盖率
- 未来 30 天半开边界、近 30 天实付、本月起跨年六桶；图表与下钻共用事件
- 提前多周期付款、同 key 并发 / 重开重试、竞争 key、版本冲突 / 无效输入；SQLite 最后更新故障时付款 / 期间 / 到期日一起回滚
- 安全撤销仅还原到期日与本次期间；撤销 key 不复活，后续编辑冲突不覆盖新值；撤销最终更新故障也整体回滚
- 账户账单独立计一次、归档保留付款、分组不复制账户款；改价 / FX 不污染原币历史付款或已知期间
- 控制器原子发布财务数据；提交已成功而重读失败不诱导重复保存
- 付款确认 / 未来日 / 取消 / 重复点击；FX 取消 / 保存和分布下钻；引用试算不回写，复制白名单不含源记录信息
- 390×844、2×文字下费用 / 付款 / 计算器可滚动；最大金额与 FX 的结果和报价无溢出
- 真实 PNG 编码解码、唯一文件保存、关闭后迟到生成不重弹、保存失败预览保留可重试
- 平台保存位置依次 Downloads / Documents / application-support 的 exports；目录不可用可回退，权限查找与选定目录写入错误不能换位置掩盖

此矩阵与阶段 1 回归一起执行。最终命令结果、独立 review 和实际 Linux 复验见 STATUS；以下原生项不以 Widget 或空白字体 golden 替代。

## 阶段 2 已验证的 Linux 原生 GUI

真实 release bundle，隔离合成 QA 数据库由阶段 1 v1 台账复制而来；原始 fixture 保留。窗口实际 1180×812，未把 Widget 窄屏测试当作手机真机。执行日期为 2026-10-06 UTC，原生桌面本地日期为 2026-10-05，日期验证按该设备本地日期判断。

- v1 → v2 启动后两条旧记录、ID、常用状态保留；只读 SQLite 核实 schema 2
- qa-one 年付 36.50 USD，原期 2026-01-01 至 2027-01-01；实际支付 60.00 USD 续两期后新到期日 2029-01-01。恰好一笔付款 / 三个明确期间，保留当前未用期，显示剩余价值 81.80 USD，不以实付 60.00 替换续费价
- 付款未来日期拒绝、改周期后要求重新确认；付款提交后详情 / 付款列表 / 费用总览一致
- 引用试算把续费价改为最大值，保留已知未来期间；退出后真实数据库续费价仍为 3650 分，到期日不变。复制结果成功提示已观察，未额外读取剪贴板
- 独立账户账单 qa-account 12.34 CNY 只保存一次，不生成服务器期间；总范围为两笔，原币 USD 60.00 与 CNY 12.34 分列；缺 FX 覆盖 1 / 2
- FX 草稿 USD=7 取消后重新打开仍为空；保存后显示真实手动日期，原币实付未变。月参考 21.29 CNY、剩余 572.60 CNY、近 30 天实付 432.34 CNY 与明细一致
- 月费用明细、testvendor 厂商下钻、未分组分布、2027 年 1 月续费下钻及 2026-10 至 2027-03 六桶正确；未知项未被当作免费
- 撤销确认取消不改变付款；确认撤销后标记为已撤销，删除本次两期并还原 2027-01-01，到期日 / 期间 / 实付由只读 SQLite 复核一致，账户账单仍保留
- 真正停止应用并核实窗口消失，再用同一数据库启动最终 release。两条记录、撤销后的期限、账户实付和 FX 日期保留。最终界面显示“约” / “至”，无缺字方框
- 最终独立试算使用最大 EUR 续费金额、缺 EUR FX 和两个未来期；真实 PNG 预览与保存成功。完整保存文件已解码并逐项视觉核实中文、长金额、缺汇率说明、未来期与免责声明，无裁剪，无源服务器身份信息
- 连续保存得到两个不同目录的真实 PNG，均为 **1080×1408、171010 bytes**，不覆盖已有文件。首份 SHA-256：`6d501d6ce86e32c0cb6c03df63e69bd1dcbef7719f077501d13b09396353e9b9`

截图、PNG 与合成数据库保留于执行环境，不随源码提交。最终自动验证日志为阶段 2 独立 review 与 release build 日志；所有命令可由 README 重现。源码和文档形成单一 dev 检查点，当前 SHA / CI 以 Git 和 Actions 实时核对为准，避免为了把自身 SHA 写回文档而递归提交。

## 阶段 2 平台边界

原生手机 share sheet、Android / iOS 编译与安装均未运行。付款只记本地已支付事实，不产生真实交易。真实秘密、SSH / API、通知与设备生物认证仍属于后续阶段；本阶段未将这些占位算作成功。


## 阶段 3 自动回归（2026-10-06 UTC）

最终 104 项测试全部通过，包含前两阶段 40 项回归。独立 Astra review APPROVE，并独立重跑 format / lockfile / analyze / tests / diff check；最终 Linux release 构建通过。

- 真实 v2 / v1 升级和关闭重开，保留服务器 / 财务 / ID；SQLite 只存安全元数据、公钥和引用
- SecretStore 写入失败、读回不一致、SQL 提交失败、成功后读取失败、部分写入、迟到写入、清理失败、恢复重试与引用保护
- 多个 SSH 引用、替换 / 解除 / 删除影响，用户名独立且默认值必须显式采用，归档记录仍计入影响
- 合成 RSA、Ed25519、加密 OpenSSH、P-256 / 384 / 521 fixtures：格式、错误口令、完整解析、指纹、私钥 / 公钥配对、本地 sign/verify 和 KDF 工作量限制
- 主机规范化、host + port、算法 / 完整公钥；首次核验、拒绝、变化阻断、明确 reverify、取消不调用认证，旧信任删除重建后的 ABA 防护
- 认证取消 / 失败 / 无能力不读取秘密；20 秒隐藏、后台隐藏、返回动画 / 路由覆盖 / 延迟元数据读取中取消，迟到文件选择不复活秘密
- 系统文件选择取消；表单保存失败保留可重试状态，错误不包含注入的秘密；删除默认不勾选
- 390×844 / 2×文字覆盖安全相关九个页面，无 Flutter overflow
- Android resetOnError=false、数据备份 / 设备迁移排除、认证 Activity / 主题 / FLAG_SECURE 与 iOS Keychain 配置仅静态源码审查

## 阶段 3 已验证的 Linux 原生 GUI 与安全存储

使用独立合成 QA 台账和经批准的临时 GNOME Keyring，真实 release bundle，窗口 1180×812。只使用保留地址和不会赋予实际访问的测试密钥。没有用户真实凭据、SSH / API 请求或生产资源。

- 实际 flutter_secure_storage / NativeSecretStore：写入、读回、覆盖、新应用进程读回、删除、缺失全部通过。无 Secret Service 明确失败；专用测试 keyring Locked=true 且无交互解锁服务时写入返回 KeyringLocked。两者均无 reset / 明文 fallback
- v2 → v3 原生启动保留两台服务器、两笔付款和一个服务期；host-trust generation 列存在
- 真正新增密码，SQLite 只出现元数据和新 secret reference；搜索无匹配 / 默认用户名及密钥分类正确
- 密码详情默认隐藏，Linux 点击设备验证明确提示不支持并保持隐藏；脏编辑放弃后原名保留
- 系统文件选择器取消保留名称 / 用户名草稿；导入加密 Ed25519，错误口令明确失败，正确合成口令保存并得到预期完整 SHA-256 指纹
- qa-one 明确保留 admin，a-qa 明确采用 ubuntu；两台引用同一密码。SSH 地址与台账分离，不覆写手工 host
- 更新密码和默认用户名 root 后，两台实际用户名仍为 admin / ubuntu；secret reference 更新，清理队列 0
- 删除共享密码时展示两台影响；明确替换为私钥后，两台引用一起切换，用户名 / 台账 / 付款保留，旧秘密清理队列 0
- 主机首次核验拒绝后 SQLite 无 pin；确认保存 Ed25519 后，录入不同 ECDSA 完整公钥明确显示变化阻断和新旧完整指纹。拒绝不覆盖；点击独立重新核实并确认后才更新 pin / revision
- 真正退出应用并核实窗口消失；最终 release 重启后凭据元数据 / 两个引用 / ECDSA 完整主机信任及时间保留。全公钥展开无裁剪
- 最终精确源码 release 再启动后，在无 Secret Service 的原生 UI 保存密码明确失败，凭据数保持 0，仅保留可恢复的不透明清理记录；没有明文回退。重启后最后一项测试私钥的删除 / 解除也保留两台用户名与账务
- QA SQLite 与普通运行日志未发现测试密码、更新密码、加密私钥口令或 PRIVATE KEY 头。此检查不宣称清除了运行时输入或 Dart 内存

测试结束已停止专用 keyring daemon 并移除临时钥匙环 / HOME 和复制的导入文件，保留无秘密的 QA 台账、日志与截图。

隔离测试 bus 有意不激活普通桌面服务，文件选择器产生的 dconf 服务不可用警告不影响导入；未为此修改系统设置。截图、运行日志和 QA 数据库仅保留于执行环境，不随源码发布。真实 secure-store 证据来自插件 release probe 与 app 原生操作，mock 合同测试未冒充原生验证。

## 阶段 3 尚未验证

Android / iOS 构建 / 签名 / 真机安装，Keychain / Keystore / 权限与备份恢复、Face ID / PIN / enrollment / lockout、手机后台及锁屏。Linux 的 keyring 锁定测试不能替代设备认证。当前没有真实 SSH 协议握手 / 身份认证；其主机-key 回调接入与端到端取消测试留阶段 4。Linux 不支持敏感内容设备认证查看，不能伪造验证成功。Dart 不保证全内存擦除，应用级设备认证也不等于每个秘密由生物认证密码学绑定。


## 阶段 4 协议 / Widget / 安全回归（2026-10-06 UTC）

本阶段全部网络验证仅限独立 AsyncSSH loopback fixture 与合成密钥。该 fixture 不调用 shell、不执行任何 exec、不配置系统账户 / authorized_keys / SSH agent。电源确认采用 spy，不重启或关闭任何机器。

- 独立 AsyncSSH 2.22.0：密码成功 / 错误；加密 Ed25519 与未加密密钥；Ed25519 / RSA SHA2 / ECDSA 主机密钥的完整公钥绑定
- 首次核验保持零认证字节、拒绝、已有正确 pin 无额外提示、changed pin 阻断、重新核实 CAS；新目标、取消 / dispose / verification timeout 后的旧弹窗不可认证
- 私钥导入默认不存 passphrase，明确 opt-in 兼容保存口令；未保存口令正确 / 错误 / null / empty / cancelled / timed-out、每次重连重新询问、无持久化 / 日志 / draft / remote 泄漏
- 密钥元数据与私钥不匹配、原生 envelope 畸形、秘密读取失败、凭据更新 / 迟到读取 / isolate 解析取消都 fail closed
- 独立 review 代理破坏真实握手签名但保留完好公钥：用户核验回调为零、认证为零，不能因捕获到公钥而跳过签名
- PTY 类型 / 初始尺寸 / resize / UTF-8 分片 / stderr / 双向字节；socket 退出、取消、握手 / 认证超时、手动重连无输入重放
- 最后 64 KiB stdout + UTF-8 尾部 + stderr 随 channel / transport 关闭仍完整保留；额外重复 5 次通过
- 有界公钥观察器：逐字节 / 不同分块，前置 banner，畸形 framing / padding / key length，aggregate / frame / key / candidate 大小限制，GEX 与 RSA signature-to-wire-type，NEWKEYS 后停止
- TCP 真实 IPv4 与 IPv6 loopback 成功、refused，零应用载荷；synthetic timeout / cancel / late connect task / late socket，换目标与后台清理
- 片段 SQLite v4 CRUD / 重启读回、CR / LF / NUL / 控制字符完整保存、revision 冲突、v3 迁移保留安全 / 财务資料；完整转义预览避免 bidi 掩盖字节
- Widget Send 明确显示目标与完整内容，append Enter 需 opt-in；插入 / 编辑 / 取消 / 换目标 / 重连发送零字节；超长草稿受限
- Power 两次确认、完整 escaped target 输入、重复提交 / 断线 / stale generation 不能再派发；无真实 power action
- 私钥文件选择与专用粘贴入口保留 PEM 换行；内容隐藏、选择取消 / 迟到剪贴板与文件结果安全失效；导入 passphrase 默认不存 / 明确 opt-in 均经过界面测试
- transient passphrase obscureText、禁自动填充 / 联想 / IME personalized learning，提交 / 取消 / 系统返回 / 后台 / 换目标清空；dialog 失效无法继续
- xterm DECCKM cursor mode 的上游字段错误使用小型公共 handler 修正，special-key 控制字节与应用模式均覆盖；无自制 ANSI 解析
- 390×844 / 2×文字终端、quick connect、片段、TCP 界面无布局异常；重复 pre-frame connect callback 只创建一个终端

最终代码独立 Astra review APPROVE；format 60 文件 / 0 changes、analyze 无问题、全量 193 / 193、diff check、enforced offline lockfile、Linux release build 全通过。原生 UI 最终结果见下节；精确发布结果以 Git / Actions 核验。阶段 1–3 的手机未运行项继续有效；本阶段不把桌面通过换算成移动设备通过。


## 阶段 4 原生 Linux 最终验收

真实 release 和生产 NativeSecretStore，合成临时钥匙环；fixture 在桌面进程同一 loopback 命名空间运行。初次把 fixture 启动于 shell 工具所在独立命名空间时，native 127.0.0.1 连接明确失败；随后在原生 app 同侧启动相同只监听 loopback 的 fixture，未放宽监听或防火墙。

- NativeSecretStore 保存加密私钥但不存 passphrase；真实进程重启仍提示本次私钥解密口令
- 隐藏输入的错误口令 / 取消均失败并保持零网络连接；重新连接弹窗为空
- 第一次完整主机身份拒绝：fixture 只有 connection / closed，无 auth_begin / password / public_key
- 独立核对 fixture 完整 Ed25519 公钥后确认：真实 public_key valid、PTY xterm-256color、80×24 开启并 resize 到 91×21，xterm 中文“你好”和 stderr 正确显示
- 插入含 LF / CR / Ctrl+C / literal backslash 的片段后与 Send 取消后，fixture input 事件为零；预览显示完整转义字节与唯一目标，append Enter 默认未选
- 明确 Send 一次后 fixture 恰好收到 22 字节原文，无额外 Enter；草稿清空。Ctrl+C 和上箭头分别精确为 0x03 和 ESC [ A
- 原生发现箭头标签缺字，已换为 Material icons + tooltip / semantic labels；输入行为未改，终端 Widget 23 / 23 与最终 release build 通过

最终收尾已通过：

- clean release 重建，确认字体 subset 含四个箭头 codepoint，真实窗口截图可见四方向 Material icons，tooltip / semantic label 正确
- 原生 fixture 同 endpoint 改为 ECDSA：changed-pin 警告无忽略并连接入口；拒绝保持零 auth；独立重新核实完整公钥后才保存新 pin 并发送密码认证
- 密码 valid / authenticated / PTY 成功；真正进程重启后正确 pin 持久，登录无需重复 host prompt；未存口令的加密密钥仍须每次询问
- Native 键盘字母 / Enter 精确发送；Back 返回立即 session_closed / closed，无隐藏旧会话
- TCP UI 对 loopback SSH 端口连接成功、相邻关闭端口被拒绝，准确显示本机来源 / 完成时间 / 目标；修改端口立即清除上次结果
- 停止真实应用、专用 fixture 和 keyring daemon；临时 keyring home / data 移除，扫描运行日志及 QA SQLite 无合成密码、passphrase 或私钥标头

证据位于本次验收环境 `vps-qa-stage4`：`screenshots/unsaved-key-prompt.jpg`、`host-before-auth.jpg`、`changed-host-blocked.jpg`、`full-byte-send-preview.jpg`、`final-native-terminal-icons.jpg`、`tcp-success.jpg` / `tcp-refused.jpg`；`logs/desktop-ssh-server.jsonl`、`clean-release-build.log` 与 `native-app.log`。截图 / 临时钥匙环不随源码提交。

窗口管理器仍采用 1180×812；390px / 2×字体验收是 Widget 测试，未冒充手机真机。Android / iOS IME / 旋转 / 切网 / 后台、真实 VPS 与实际电源执行继续未运行。

## 阶段 4 CI 断线清理回归修正

首次阶段提交 `cc6785a612ce7a6bf2d165dfd70070478d1bd7ad` 的 [CI #5](https://github.com/zqcli/vps-tell-you/actions/runs/37414098447) 在 disconnect / reconnect 用例失败：192 项通过，1 项出现未处理的 Broken pipe。随后本地重复同一测试也重现，未将其视为偶然超时或放宽断言。

Dart 的 Socket.close 返回与 done 相同的 Future；dartssh2 在远端 EOF 后未等待其 transport.close，导致先前已由 done 观察的写错误在 cleanup 再次传播。原生 adapter 现在仅在 close 清理时捕获 SocketException 并 destroy；原始 done / sink / flush 错误仍保持可观察，未添加全局错误吞掉或自动重连。

新增 5 项确定性 close / done / write / flush / SSHClient EOF 回归和 12 次真实 loopback TCP reset / reconnect / 不重放检查。修正后全量 199 / 199 通过，format 61 文件 / 0 changes、analyze、diff check、Linux release build 通过，并重新独立 review。最终同 SHA CI 必须另行核实，不以失败的 #5 代替完成。


## 阶段 5：恢复后的新验收（2026-10-06 UTC）

本次重新从已验证的远端 d9e8d35 基线应用带断言恢复补丁，没有跳过不匹配的代码。下面均为恢复后实际checkout的新执行结果，旧环境日志不充当新证据。

### 自动与独立复审

- 335 / 335 全量测试通过；包括最新 SSH 输出排空 / native EOF 队列修正
- format 0 changes、analyze无问题、offline --enforce-lockfile、git diff --check通过
- clean production `flutter build linux --release --target lib/main.dart`通过；测试fixture入口单独构建并复制，不进入生产main
- 独立Astra复审无阻塞项；154项相关测试通过（包含额外scratch账户菜单重复点击回归），随后全量335通过
- 协议81项：V1 multipart status-only、rootless XML/错误/未知、DTD/重复/嵌套/16KiB限制；V2 account/project/server只读allowlist、规格单位、投影、分页/跨origin/端口/循环/矛盾metadata；401/403/429、坏JSON/XML、超时/取消/响应大小和整体预算
- 真实loopback TLS：默认拒绝自签，受信测试证书仍拒绝错误主机名；重定向目标零请求；body stall、取消与chunked上界有效；不设置badCertificateCallback
- schema v1–v4迁移保留旧数据；同endpoint多连接、同远端ID跨账户隔离、UUID变化阻断、IP/名称变化不改身份、重复/归档导入去重
- 失败重新授权保留旧秘密与关联；新秘密写入/读回/DB提交/清理失败与跨云/SSH cleanup races有回归；秘密不进SQLite/错误
- V1明确detach/rebind，旧台账与账务/SSH保留；V2不同远端账户拒绝；解绑/更新generation后旧请求不能恢复关联
- widget：390px / 2×字号、masked输入、/home.php规范地址显示、失败/取消/Back动画/后台清理、保存后重读失败不重复提交、模板/设置入口防重复导航，验证/保存防重复提交，账户菜单重复点击回归通过
- 新复审指出并修复 metadata reload成功后旧错误残留，新增回归并纳入335全量

### 原生 Linux 合成闭环

使用真实NativeSecretStore、用户已批准范围内的独立临时GNOME Keyring与私有D-Bus。官方Debian包只解包到workspace QA prefix，不修改系统PAM/autostart、既有钥匙环或真实凭据。HTTPS fixture只绑定localhost，测试入口只接受该host/port，私有测试CA只在fixture factory中生效。

实际UI验证：默认空数据 → 选择SolusVM2 → masked合成Token与HTTPS自定义端口 → account/project/两页server清单 → 选第一台保存 → 关闭进程 → 重启恢复台账 → 从原生存储读回授权继续导入 → 首台显示“已关联”且不可重复选择 → 仅新增第二台 → 明确确认解绑 → 账户/观测/关联/待清理引用为0，2条台账保留。

SQLite不含SYNTHETIC_秘密标记。测试app、fixture与专用keyring进程全部退出；临时keyring home、TLS key/cert已删除。没有生产API、正常钥匙环读取、密码/Token索取、资源销毁或真实电源命令。

证据：`../recovery-stage5/assembly-evidence/final-aggregate.log`、`final-analyze.log`、`final-format.log`、`clean-production-build.log`；`../vps-qa-stage5/logs/native-db-assertions.json`、`native-cleanup-check.json`、`https-fixture.jsonl`；截图`restart-dedup.jpg`与`unbound-account.jpg`。发布前整理非秘密证据归档与完整Git bundle。

### 尚未验证

真实服务商/用户面板版本、API开放/权限、真实字段和证书，VirMach实际兼容性；iOS/Android构建、签名、安装、安全存储/设备认证、键盘/IME/旋转/后台/切网、提醒/分享。桌面与合成协议通过不代表上述项目通过。最终dev发布与同SHA CI须单独核实。


## 阶段 6 云端候选验证（2026-10-06 UTC）

首次完整阶段 6 聚合：421 / 421 通过，format / analyze / diff check 与 Linux release build 通过。使用临时 SQLite、只监听 loopback 的 SSH/HTTPS fixtures 和合成资料，无用户秘密或真实服务商请求。

- 31 个提醒纯逻辑 / PNG boundary 回归：日历 / 月底 / 闰年、23 / 25 小时日、30 分钟跳变、跨午夜 gap、fold 单次、不补发、整天跳过、容量全局排序 / 未覆盖、ID 稳定、停止续用仍核对、分享取消 / 未知 / 并发 / 错误
- schema v6 与旧 v1–v5 升级；规则触发器、持久化 revision / archive 冲突、外观；变更 / 禁用 / 归档 / 恢复 / 时区后的重排，迟到 native 返回不能越过新任务
- 原生插件 Dart 通道合同：Android 实际权限 / 渠道读取、inexactAllowWhileIdle、无精确闹钟请求；iOS 初始化权限全部关闭，仅显式请求后再次读取；Linux不初始化通知插件
- 提醒 / 外观 widget：返回取消不写库、显式保存、拒绝权限规则仍保留、真实 App ThemeMode 更新、前台时区重排；390px / 2×字深浅色无溢出
- 白名单备份：负向版本 / 类型 / 金额 / 日期 / ID / FK / 大小矩阵、保存前预览、事务内空台账再检查、半途注入失败回滚、void / 幂等 / 费用历史及稳定 ID、私密表和备注排除、还原提醒关闭；21 个备份专用测试和独立 peer 安全 review 通过
- 深浅色独立对比度、16 个实际页面 × 390px × 正常 / 2×字、固定深色终端、取消 / Back / 键盘清理；两个合成组件 golden。现有 UI 72 项回归通过
- PNG 分享真实 renderer 字节与插件方法通道，双击只打开一次、关闭后迟到结果、新图片不被旧结果覆盖；系统选择不伪称送达，Linux 不显示移动分享入口

Astra 全阶段 review、修正后的最终聚合、原生 Linux 流程、Android 通用 APK 和远端 CI 仍按后续完成记录追加，不将此条首次通过冒充后续精确 SHA 的验证。

### 设备交接未运行项

Android / iOS 实机安装重启、设备安全存储/设备认证、真实通知允许拒绝/渠道/重启/时区/节电、原生分享/取消和文件选择；SSH 手机键盘 / IME / 旋转 / 切网 / 后台；真实 SolusVM 面板版本/权限/证书；iOS Xcode 编译、签名与安装。测试签名 APK 的生成不是生产签名，更不是上述设备项目通过。


### 阶段 6 独立源码审查与修正后复验

独立 Astra xhigh review APPROVE。修正深色备份冲突文字的对比度、提醒保存期间 Back 触发二次 pop、保存完成误移除较新导航，以及待处理通知在下一帧盖过更新点击的竞态。新增 7 个独立回归覆盖冷启动 / 热通知、旧 / 已归档目标、保存 / 刷新阻塞队列与最后目标、dispose、Back、中途新导航和错误文字对比度。

独立全回归 428 / 428、focused 100 / 100、analyze、format、diff check 通过。原生 Linux 另发现底部四 Tab 语义未显式标为启用，已补 enabled 语义与 widget flagsCollection 断言；不改变点击行为。其余平台操作结果仍见最终完成记录，未完成项不计为通过。

### 阶段 6 最终 Linux 原生验收

最终源码 `4d38572a2047ac0878d385b0548b878a2feeeabe` 合入已发布阶段 5 的同源树后，全量 428 / 428、format 97 文件 / 0 changes、analyze、diff check 与生产 Linux release 重建通过。实际生产入口 `lib/main.dart`，隔离 HOME / XDG 目录和不激活服务的私有 D-Bus；不用用户台账、真实秘密、钥匙环或 VPS。窗口实际为 1180×812，390px / 2×字号仍属于自动 Widget 验证。

原生桌面闭环：

- 首次空态，明确选择演示数据后才加入 4 条保留地址的合成记录
- 保存深色外观；提醒更改后取消不写入，重新更改并保存为 30 / 7 / 3 / 1 天、到期不再使用、09:00；关闭进程并确认窗口消失，重启后深色与规则仍在。只读 SQLite 核实 schema 6 和 revision 1
- Linux 显示“不支持定时通知，未排程”，演示记录明确不连接 / 不排程；四个底部导航在真实可访问性树中为启用状态
- 原生文件保存导出 2,784 字节 JSON：4 台服务器、1 个分组、0 笔付款、2 个服务期；读取导出结构，无私密表、备注或提醒 / 偏好数据
- 原生文件选择同一备份，非空台账恢复按钮禁用、冲突文字在深色下可读
- 新隔离空台账选择备份，确认对话框先取消，SQLite 仍为 0 台；再次明确确认后，服务器 ID 与备份完全相同，4 台 / 1 组 / 2 期间恢复。所有提醒 enabled=0，外观仍为 system；凭据、SSH 配置、主机信任、云账户、关联、观测均为 0
- 独立 $49.99 USD 年付试算实际生成白名单 PNG，预览后保存到隔离应用目录；再次解码为 1080×1352、154,164 字节，SHA-256 `b213b1ac161b3574c628f15c9ef87339ff59bbd7739412e239156795ebaa23ca`。界面显示真实路径，没有把保存说成相册或分享送达；Linux 无移动分享按钮
- 完成后关闭 QA 应用并确认窗口退出。没有运行真实电源命令、联系生产 API 或发送导出给第三方

非秘密证据保留于验收环境 `vps-qa-stage6`：`native-restore-evidence.json`、`native-png-evidence.json`、`png-saved.png`、`screenshots/native-dark.png`、`screenshots/restore-conflict.png`、`screenshots/restarted-dark.png` 与 `logs/native-app.log`。私有 D-Bus 缺少 dconf 服务的警告为隔离环境现象，文件选择 / 保存已实测成功；这些文件和测试数据库不提交到源码。

此处 Linux 验收完成时 Android 本地 Gradle 曾被执行审批取消；最终恢复构建和产物核验见下一节。iOS 构建和所有上列手机实测仍未运行；Linux 文件选择 / 保存不作为手机通知投递或系统分享通过的证明。

构建准备另加一项独立 Astra xhigh 审查通过的 Gradle 限定：清除 Flutter 默认 ABI filters，只保留 `arm64-v8a` 和 `x86_64`，避免原生依赖混入只有部分库的 32 位目录。该改动只影响 Android 打包目标，Dart / Linux 源码未变；最终 APK ABI 清单核验见下一节。

### 阶段 6 Android 测试 APK 产物核验

构建源码 `94003d14f980c0b83eeee8ed4b4ba08379ff97df`，已包含上述 ABI 限定。最终交接文档的后续提交不改变该 APK 的应用或平台源码。补齐已批准的官方依赖后，云端本地离线 Gradle `assembleRelease` 成功（464 个任务）；没有启用 Android GitHub Actions 作业。

- 文件：`vps-tell-you-0.1.0-arm64-x86_64-test.apk`，49,489,632 字节
- SHA-256：`f5ca8ca55b32b2a93aa5b26dd24fb8a80f400f860eca8cb18c046b90e376bd0f`
- 包名 `com.vpstellyou.vps_tell_you`，versionName `0.1.0` / versionCode `1`，minSdk 24 / targetSdk 36，非 debuggable
- apksigner 核验 Android Debug RSA 2048、v2 签名；这是 release 模式的测试签名包，不是生产签名或商店发布
- 仅 `arm64-v8a` 与 `x86_64`；每种均完整包含 app / Flutter / dartjni / sqlite3 四个原生库，没有 32 位 x86 或 armeabi-v7a 残片；ZIP 与 ELF 的 16 KB 对齐检查通过
- 最终 DEX 包含定时通知 / 重启接收器，通知图标保留；权限为 INTERNET、POST_NOTIFICATIONS、RECEIVE_BOOT_COMPLETED、USE_BIOMETRIC、USE_FINGERPRINT、VIBRATE 和应用范围的签名接收器权限，无精确闹钟 / 全屏通知 / 外部存储权限
- 独立 Astra xhigh 对最终 APK 核验 APPROVED；证据 `stage6-apk-evidence/apk-validation.json`、`apksigner-verify.txt`、`zipalign--c.txt`、`build-offline.log`

未安装到模拟器或实体机，未验证手机通知投递、权限提示、Keystore / 设备认证、文件选择 / 分享、SSH 键盘 / IME / 旋转 / 后台 / 切网；这些仍按上方设备交接清单执行。APK 可供用户安装测试，不将静态产物核验写成手机验收通过。

### 同源分架构附件

通用 APK 超过聊天附件大小限制，因此保留通用产物，并从同一 `94003d1` 源码通过官方按 ABI 打包生成两份可独立安装的 APK。没有修改应用源码；仅在本次 Gradle 调用的 `androidComponents.finalizeDsl` 中清除通用包 ABI filters，让 Flutter 的 `split-per-abi` / `android-arm64,android-x64` 控制两种产物。调用专用脚本和离线构建证据随交接资料保留，不改变默认通用包配置。

- `vps-tell-you-0.1.0-arm64-v8a-test.apk`：24,674,032 字节，versionCode 2001，SHA-256 `4f705c5cbc38adb913a20b909b233039920170b5e59f58a8ba625cf9b9a2c3a8`
- `vps-tell-you-0.1.0-x86_64-test.apk`：26,191,304 字节，versionCode 4001，SHA-256 `c319ff9f7781990131f0b789dc917d64a6d2e16f9dab944b1dd4b870868c00e8`

两份 versionName 均为 0.1.0，minSdk 24 / targetSdk 36，与通用包同一测试签名。对应 native libraries、DEX 和 assets 字节与通用包一致；各自只含目标 ABI，独立 Astra xhigh 产物审查通过。ARM64 用于对应手机 / 平板，x86_64 用于对应模拟器；不支持 32 位 x86。两份均未运行设备安装或功能测试。更换签名的后续构建无法直接覆盖安装；卸载前先导出台账，并注意该备份不包含凭据、主机信任等已列明内容。

实际聊天交付使用每种架构一个普通 ZIP 压缩包，包含原始已签名 APK 和说明，先解压再安装。ZIP 仅为适应附件大小限制；解压后的 APK 哈希与上述核验值完全一致，没有重新编译或修改 APK。


## SolusVM 1 六项资源导入增量（2026-10-06 UTC）

- 独立 Astra xhigh 复审与最终 571 项全量测试通过，包括本地 SSH fixture；format/analyze/diff 检查通过。
- 生产 Linux release 使用 `lib/main.dart` 构建通过；不是诊断入口。
- 覆盖一次 enriched status 请求、XML/TLS/取消、IPv4/IPv6/hostname、字节四元组、0 使用量/缺失配额、可选核数冲突、六项补填、明确无限流量、精确单位转换、来源标记、v6→v7 迁移、旧/新备份、刷新与解绑保留、重复提交和后台过期。
- 复审复现并修正：资源表单滚出懒加载列表后状态丢失导致编辑保存无响应。单台 V1 导入和本地编辑改为有界完整表单，V2 大清单保留懒加载。测试包含 390px / 2× 大字、直接滚到底导入、资源编辑后滚到费用/备注保存、隐藏无效值阻断及来回滚动保留。
- 原生真实新增流程通过：用户本人触发一次带资源标志的只读读取，四项有效 API 资源自动预填、RAM/vCPU 由用户补填；勾选单实例后仅本地导入成功。详情逐项显示 API/手动来源；只重启新版隔离测试 App 后所有六项和来源保留，无重复服务器。只读 SQLite 核对 schema7，账户/服务器/观测/关联各1，SSH/主机信任/付款/服务期/清理队列均0，费用类型仍未知、金额及日期为空。原账户、钥匙环、主 App 和旧台账保持不变；本阶段未由代理发起额外凭据请求、远端电源或配置操作。真实资源值仅存私有测试证据，不进入仓库。
- 此增量未推送，未更新 Android APK。Android/iOS 设备存储、安装与移动端交互仍需设备单独验收。


## 服务器硬件与云关联整理验收（2026-10-06 UTC）

- 基线 canonical dev `943a916ac823ead6c7a2259a5cc355b896dab6ae`，独立工作区实现，不修改既有用户测试 App / 钥匙环
- 新增/编辑六硬件字段：手动未知、六项完整、非法值、单位/周期独立、新建默认月提示、旧记录周期未知、滚动往返、取消、重复保存、保存后 SQLite 关闭重开
- 基本资料与硬件编辑入口区分，编辑硬件直接定位同一表单；主机地址/SSH 不随硬件编辑改变
- schema v7→v8 旧服务器行逐字保留；旧八字段 JSON、部分新硬件及季度流量通过备份/恢复；不接受附带私人未知字段
- 本地关联 / 换绑 / 单台解绑、确认取消、已占用不可覆盖、旧页/跨账户 ABA/临时账户删除 ABA、取消事务、保存后重读失败、0 secret 读写删除 / 0 adapter调用
- 关联不变更服务器 revision，不破坏既有安全付款撤销；硬件、SSH、费用、付款、账户、授权均保留
- API 详情字段不再显示；后台观测刷新失败仍保留旧观测，不写本地硬件
- 费用/续费/付款记录页无独立账单创建入口；服务器付款与已有独立账单历史仍可见
- 390px / 2 倍文字交互检查，无布局异常；精确硬件字节显示不因单位换算四舍五入
- 最终 format 110 文件 / 0 改动、analyze、diff 检查通过；全量 624/624 通过（含 loopback 合成 SSH/TLS fixture）
- 独立 Astra xhigh review APPROVE，独立 focused 87/87 与 analyze/format/diff 通过；旧 v7 自动规格更新问题已修并新增两条独立回归
- 合成硬件卡 PNG 用真实中文字型绘制并实际查看；仅为组件视觉证据，不冒充原生 GUI 或手机真机
- 单独原生 Xorg 显示无法创建本地 socket，原生 GUI 未运行；Android/iOS 构建/安装及真机能力在本增量未验证
- 本次没有真实厂商 API 请求、没有电源或远端配置写入，未修改 RackNerd 协议兼容
- 生产 `lib/main.dart` Linux release 构建通过；编译产物未接入旧用户台账或运行窗口。


## 紧凑容量表单验收（2026-10-06 UTC）

- 基线 canonical dev `17e41171ea473e43c6126f1e640c0bdb7129c4bd`，独立源码分支；只调整共享资源表单布局，schema v8 与转换/校验/保存语义不变。
- 内存、磁盘容量框与单位同排，流量容量框、单位及周期同排。长标签、API/手动来源、1024进制说明和错误文本在行外完整换行。
- 新增14项矩阵：320/360/390px × 1×/2×文字 × 手动/导入，加disabled与长错误；同排坐标、可点区域、完整单位单行、月/季/年/未设置、最大精确字节、小数转换、不限量前后值保留均通过。
- 独立Astra新增4项：错误后清空/更改单位恢复；导入缺流量→不限量→取消→精确B恢复；错误读屏标签/hint/invalid→valid；编辑中缩放仍保留controller、光标、容量/单位/周期。
- 独立review APPROVE，focused 45/45与真实中文/图标字体14/14通过；已查看正常套餐与未知/错误截图。原有新增/编辑/导入/滚动/取消/SQLite关闭重开回归仍通过。
- 最终全量642/642（含仅loopback的合成SSH/TLS fixture），format 112文件无改动、analyze、diff检查及生产Linux release通过。早期并发运行的工具争用/fixture启动超时未计入通过；最终以低并发完整重跑为准。
- 2×大字的周期框为完整容纳“未设置”可能更高，仍与容量和单位处于同一水平行，不截断该选项；正常1×紧凑。
- 本阶段未启动既有用户App、读取或改动用户台账/钥匙环、调用真实厂商API。Android/iOS构建、安装与手机实测未运行，云电脑预览结果另记。


## 同行表单与完整填写体验验收（2026-10-06 UTC）

- 承接容量同行检查点820656e；币种、付款周期和计费方式采用标签与选择器同排，不限量改为有完整整行触区的switch。金额保留精确原币值，旁列币种和周期含义。
- 独立Astra xhigh完成具体旅程与源码review，APPROVE；51项独立批跑、8项真实CJK/MaterialIcons旅程通过。最后四字选项优化保留字号与触区，320px/2×下完整单行，重新目视审核通过。
- 新增19项：9项布局/真实字体/日期与小视口/新建引导；8项独立历史锁定、金额最大值、免费与未知、取消、重复保存、首错、读屏、按量费用及长选项；2项V1未选择引导及错误定位。
- 保留已记付款与期间的锁定边界；改币种/金额不改写历史付款，0与未知不同，按量模式无预付日期/周期。草稿切换和取消保留原有行为，保存只提交一次。
- 保存合并基本/费用/硬件校验并按视觉顺序定位错误；所有输入保留，日期先后错误落字段。V1返回实例只定位，未代勾选/保存且没有额外adapter调用。
- 地址关闭自动纠错，日期/多行备注/下一项键盘类型已组件检查；手机输入法实际手感仍未验证，不将小视口组件验证称为真机键盘测试。
- 最终全量661/661（单并发，包括合成localhost SSH/TLS）、format 115文件/0改动、analyze和diff检查通过；生产Linux release在独立目录串行构建成功。早期编译器退出/环境挂载错误未计为通过，最终以完整重跑为准；当前运行的上一版预览二进制未覆盖。
- Android/iOS构建、安装与新APK均未运行。本次未触及真实用户台账、钥匙环、厂商API或现有窗口；云电脑预览交由主会话协调，结果另记。


## 费用与日期按组同行验收（2026-10-06 UTC）

- 基于未发布的73f7b8d继续，依最新明确要求调整计费方式浮动标签，预付费金额/币种/周期三列，开始/结束日期两列。按量和费用未知不引入新的财务控件或保存语义。
- 独立Astra xhigh review APPROVE；标准25项和真实字体25项完整通过。320/360/390、1×/2×，逐字符日期边界、光标物理像素对齐、软换行不改ISO值、重排/Next、全宽错误及读屏、完整周期含义、免费/未知/按量、历史付款锁定通过。
- 周期浮动标签的320×2省略已修，金额仍可标准横向编辑滚动且全值摘要完整可见。日期错误分别标注开始/结束，不省略解决说明。
- 日期、正常金额、最大精度、错误和周期弹出菜单截图已实际检查；菜单最多合理换行，不是一字一行，所有周期可读可点。
- 真实字体测试使用一次加载的Noto第0face子集；777个支持字符轮廓和advance与原字体逐一相同，保留layout features与hinting。字体子集只用于证据，不进入生产App；默认测试字体路径不变。早期宿主compiler被SIGKILL的运行未计入通过，后续标准工具完整25项通过，无SDK替换或结果过滤。
- 最终全量669/669（52个文件、单并发，合成localhost SSH/TLS），format 116文件/0改动、analyze及diff检查通过；锁文件离线解析与独立目录生产Linux release成功。全量最终退出码0；早期OOM/SIGKILL未计通过，保留本任务临时缓存到磁盘并使用官方compiler的1024 MB堆上限后完整重跑，无跳过、断言弱化或SDK修改。
- 当前运行的73f7b8d预览bundle未覆盖，libapp.so哈希复核不变；用户台账/钥匙环/SSH未操作。新预览交主会话协调；不构建新APK或进行手机真机验收。


# 全屏 SSH 与周期内容宽度候选（2026-10-07）

源基线：已发布 `fada6cf16d4003d7f11bfb44976d5205df76b755`。最终候选commit/tree见本轮Git与交接manifest；不把本地构建当作推送/CI/手机验收。

## 本轮已通过

- Astra max独立UX/code review APPROVE；最终27项真实字体与本地PTY回归，最终截图与生产文件SHA绑定。
- 全量715/715（56个测试文件，单worker），所有阶段保留原始退出码0；format123文件0改动，analyze零问题，git diff --check，锁文件离线解析，生产Linux release。
- 周期新12项+既有25项：标准37/37、真实Noto字体37/37；320/360/390和2×字体、半年/多年/旧18个月、独立菜单一行完整文字、48px点击范围、焦点、历史付款锁定、精度与完整摘要。
- 终端320×568、390×844、844×390各1×/2×，1200px宽屏解除限宽并在退出后恢复；键盘inset改变PTY行列，无外层终端页面滚动。
- 真实TextInputClient：普通文本、中文组合/提交、软退格、done回车与底栏Enter、一次性Ctrl；关闭未完成中文组合后按钮/正文重新打开输入，方向键正常；可见IME中点正文不丢组合。
- 长按/拖动选择复制与历史滚动不写SSH；命令/片段/菜单与硬件粘贴仅入草稿；替换与发送须确认，默认不加Enter；模态期间旧快捷键callback不写入，但ANSI DSR应答保持。
- 真实独立AsyncSSH仅loopback fixture：软键盘字节→实际SSH channel→合成回显；窗口resize到达真实PTY。fixture不执行shell/exec，不创建OS账户或访问真实VPS。
- 私钥口令、主机信任、断线/换目标、返回重复激活、后台清理与单机电源原有门禁回归。短横屏、大字、键盘占位下口令/发送/电源确认可滚动。
- DejaVu Sans Mono 2.37 Book/Bold：两个未修改字体677,408字节；已验证哈希、许可、ASCII/框线相同advance、0/O/1/l/I不同glyph，禁用编码连字/kerning，中文双cell真实截图。生产FontManifest登记正确，打包TTF哈希与源码一致。

生产Linux libapp.so SHA-256：`3bdd9f31496a634cfeec93dff7180814ea04f9b2f7f5e79359c860e560ee2d62`。构建后仅补完成文档，生产源码/字体/平台输入文件SHA复核不变；该bundle不再重编覆盖运行中的预览。

## 本轮边界与设备验收

- Android/iOS新构建、签名、安装、真实设备键盘/IME/旋转/切网/后台、真实VPS兼容性均未在本轮执行。用户之前测试过的APK属于上一源码版本。
- 下一轮手机优先核对：中文候选未提交时收起/重开键盘；正文点按；键盘Enter的newline/done差异；方向/Tab/Ctrl；横屏键盘遮挡；长按选择；断网/后台重连不重放。底栏Enter是明确回车入口。
- xterm4既有CPR坐标回复兼容性问题未在UI轮扩写ANSI逻辑；本轮以DSR验证模态期间协议通路，不能据此宣称所有TUI/emoji/脚本已兼容。中文fallback具体字体由设备提供。
- 无真实用户SSH/API、真实秘密/钥匙环、用户数据库或窗口操作，无APK、远端提交/分支/tag或强推。云预览的独立资料与本地演示由主会话另外安排。


# 键盘可视输入与就地发送候选（2026-10-07）

源基线：已发布 `9eb94af2e8697c94cae4d5e0ae8afa0590651771`，tree `295f63ed8e5bd92ec2de81f0de32561991094768`。独立目录构建，不覆盖已运行 bundle；最终候选 commit/tree 由本轮 Git 与交接记录核对。

## 交互与安全检查

- 独立 Astra max review 通过23/23：双按钮分别发送精确原文或原文加单个 CR，包含中文 UTF-8、空白、现有换行和控制字符；额外对话框/回车勾选已移除，完整目标与转义提示留在发送区。发送不表示远端执行完成；现有换行可能在不追加 CR 时执行。
- 同步/异步混合重复点击、已关闭/退出动画中的旧 callback、断线/换目标/重连与剪贴板迟到结果均不重放输入；草稿按选区插入，重复粘贴可继续编辑，草稿变化不被迟到读取覆盖。系统剪贴板仅在用户动作时读取，不日志/持久化内容。
- 实际 TerminalView 光标矩形位于键盘上方的有效 viewport；320/390/844px、1×/2×、键盘连续 inset、横竖旋转和历史→显式键盘返回覆盖。发现并修复旧 history 标志导致光标仍在遮挡区域的问题，不能以 PTY 行数改变代替光标检查。
- 发送成功后在下一帧恢复终端输入，已可见 IME 可继续输入；软键盘/正文重开、中文组合/退格/Enter、一次性 Ctrl 及特殊键维持原有回归。
- 真实 loopback AsyncSSH PTY 核对原文与原文加单个 CR 的接收 UTF-8 字节；这里只回显合成数据，不运行 shell/exec，不触发真实用户 SSH。
- 另7/7独立 Linux Flutter-engine 检查：已聚焦后滚到历史的首可见行在被动 inset/旋转/新输出中保持；alternate-screen 合成 TUI；bracketed-paste 模式下 Ctrl V 仍只到草稿；空/不可写/断线禁用；写入抛错保留原文、就地错误且10秒后仍无自动重试；短横屏大字按钮可达。
- 使用 App 打包的真实 DejaVu 常规/粗体以及真实 CJK/图标字体查看截图。为控制编译内存，测试可用 Noto 第0 face 子集；790个映射字符轮廓与 advance 逐一等于原字体，生产字体未修改。截图为 Flutter engine 渲染，空白 inset 区不代表实际系统键盘画面。

## 验证范围与待设备确认

- 本轮 Linux 原生 GTK/X11 独立显示服务尝试因本地 socket 限制失败，未改用共享桌面或 TCP 绕过；GTK 原生焦点、系统剪贴板、真实 Android/iOS 输入法动画/组合/系统收起/物理旋转尚未实测。不得把 Linux engine 模拟或 release 构建成功当作这些项目通过。
- 主机信任、加密私钥口令与单机电源原有确认保留；无密钥存储、数据库 schema、远端命令自动执行或网络权限变更。无真实用户 SSH/API、台账或钥匙环动作，不创建新 APK，不自行推送；独立预览另由主会话安排。

## 最终检查结果

- 全量745/745、59个测试文件四批顺序运行：168/139/301/137，每批原始退出码0。清单与实际加载文件逐项比对，全部测试文件恰好覆盖一次，无测试筛选或跳过。
- format126文件零变化、analyze无问题、diff检查、锁文件离线解析、生产 `lib/main.dart` 的 Linux release 均通过。
- 早期完整单进程在385项后官方 frontend 被宿主 SIGKILL；该轮已终止，不计通过。最终分批仅限制官方 compiler 的768 MB堆并重启进程，使用磁盘 TMPDIR；未修改 SDK、过滤结果或削弱断言。
- 构建后只补完成文档，147个生产源码/字体/平台/锁文件输入的 SHA-256 与构建前完全一致。打包的两款 DejaVu TTF 仍与源码一致。

生产 Linux `libapp.so` SHA-256：`9058fe6179fc177c3f12f072b85b273c97851919dc9deafb6092d07dfc0943cd`。该 bundle 冻结用于后续独立预览，不重编覆盖运行窗口。


# 命令面板顺序整理（2026-10-07）

承接尚未发布的键盘候选 `5e38710ff4242dfc207e80c6c00fc662aceaf0cb`；最终发布仍需核对 dev 上的实际 commit/tree，不把本地候选当成远端版本。

- 生产只调整 `TerminalCommandSheet` 的布局：常用命令、插入片段、分隔线、可编辑草稿与就近粘贴、完整目标、条件性控制字符/失败提示、回车说明、两个发送动作。片段入口保持原名称，与既有帮助文案一致。
- Ctrl V、命令入口、剪贴板读取/草稿插入、发送/追加CR、会话世代与异步防护方法完全未改；不新增模式、折叠、焦点行为、发送预览或自动执行。
- 独立 Astra max 8/8 真实字体回归通过：320×568、390×844、844×390各1×/2×，有/无键盘 inset，实际拖动到按钮并点击，完整目标、提示顺序、48px触区、失败后编辑与不自动重试通过。320px大字/键盘场景需滚动到各动作；不承诺全部正文或两个按钮始终同时可见。
- 正常空草稿/pwd、危险字节、大字与短屏截图已实际查看；测试使用合成内存 SSH/剪贴板，不操作原生系统剪贴板、用户窗口、秘密或真实 SSH/API。GTK 原生及手机 IME 边界沿用前一阶段说明。

## 最终全量回归

- 全量753/753、60个文件全部通过；前三批45文件608项，最后15文件逐文件145项，每个成功进程退出码0。与完整文件清单逐项比对，所有文件在有效结果中恰好覆盖一次，无筛选或跳过。
- format127文件零变化、analyze无问题、离线锁文件解析与diff检查通过；此前环境缓存/内存中断不计通过。受共享内存约束，使用原官方compiler的768 MB堆限制、预编译的资源launcher与分批进程，不改SDK或测试断言。

- 生产 Linux release 最终退出码0；构建后147个生产源码/字体/平台/锁文件输入 SHA-256 与构建前一致。早期 kernel 构建异常不计通过，成功重跑使用同一生产代码。
- 生产 `libapp.so` SHA-256：`d8eb8ab0d2aed2fda1a910d62355ed3d2ed800c037c1901967db58e759ee5d13`。独立新目录产物冻结，未覆盖现有用户App或演示bundle；本阶段不创建APK。


## 全界面中文文案审查（2026-10-07）

基线：已发布 `132cd8e5f3b95d2422ec01635cb453232de8f15e`。范围、术语和逐模块审定见 [UI_COPY_REVIEW](UI_COPY_REVIEW.md)。

- 独立 Astra max：APPROVE，静态检查全部 diff、回归与说明，并目视抽查22张真实CJK截图。审查提出的错误导航、续费撤销承诺、导入选择状态、终端复制失败及BufferRange值比较均修复后复审通过。
- `flutter pub get --enforce-lockfile --offline`：通过。
- `dart format --output=none --set-exit-if-changed lib test`：129文件、0变化。
- `flutter analyze --no-pub`：No issues found。
- `git diff --check`：通过。
- 完整测试：**777/777，61文件，无遗漏、重复或跳过**。八批每批退出码0：105、67、74、90、221、74、81、65。最终代码未在聚合验证中途再修改；源码哈希核对一致。
- 新增22项文案/19页逐段布局与估值边界测试；另新增API凭据丢失提示和终端复制失败→保留选区→重试成功测试。既有授权、主机核验、网络隔离、发送字节、付款与数据回滚断言保留。
- 真实NotoCJK字体额外验证：文案审查22项及命令面板8项，覆盖320px/2倍、正常/短视口、IME和完整目标可达性。截图为隔离Widget/engine渲染，不是用户桌面或移动端真机截图。
- `flutter build linux --release --no-pub`：通过，产物为本轮独立checkout的生产bundle。没有启动应用或替换已运行bundle。
- 编译器使用官方snapshot，测试堆上限1024 MiB、单worker、磁盘TMPDIR，Linux单worker；早期768 MiB冷编译不足及过时文案断言失败均未计入最终通过结果。未通过修改SDK、过滤失败、跳过用例或弱化断言取得成功。
- 仍为schema v8、开发测试版0.1.0，无英文locale、语言设置、新依赖或真实服务连接。Android/iOS安装、原生IME、权限与系统分享仍需既定真机验证。


## 英文 i18n 与语言设置（2026-10-07 UTC）

基线：已发布 `9be096fcc1ffbca5136ead81c6acc660cc2175f9`，tree `60328b74492d9c50ee82b1adee2f40f2a2d2a64a`。使用方式、系统回退、数据边界与开发维护见 [LOCALIZATION](LOCALIZATION.md)。

- 使用 Flutter 官方 `flutter_localizations` / `intl` / `gen-l10n`，简体中文与英文各 **1356 条**完整对应消息。保留审定中文和精确风险含义，涵盖页面、表单、错误、空态、按钮、提示、无障碍、原生验证可配置文字、提醒、计算文本及 PNG。
- 设置提供「简体中文 / English / 跟随系统」，保存成功立即切换并在重新打开后保留；新安装、旧用户和无效存储值默认中文。跟随系统依设备偏好匹配中文/英文，中文变体统一简体，均不支持时回退英文。
- 切换保留路由、表单/终端草稿、输入与选择，不重新加载面板账户、不重新验证身份、不重连或重放 SSH。已显示的错误、已打开的菜单/日期时间与确认窗口、排队提示在显示时解析当前语言；有历史验证错误的表单只重做本地验证。
- 「Send」仍发送精确原文；「Send and execute」仅追加一个 CR。电源双确认保留完整风险正文、精确目标输入与一次性操作。英文窄屏短标题/按钮与流量周期关闭态短标签改善大字可读性；流量完整名称留在菜单、语义与 tooltip，数值/单位/单行结构不变。
- ISO 日期、24 小时时间、整数分金额、原币代码、月数、日历周期与序列化不因语言改变。计算分享捕获不可变语言快照；用户资料、命令、SSH 输出和协议标识原样保留。
- schema v9 只向 `app_settings` 添加 `language` 偏好，默认 `zh`；v1–v8 迁移、账务/凭据与 JSON 备份 v1 保持兼容。语言不进入备份白名单；恢复不覆盖设备偏好。提醒语言更新仍走既有串行重排，ID/日期/隐私和权限边界不变。

### 最终检查

- 独立 Astra max 最终 review **APPROVE**，代码、视觉与完整验证材料均无未解决 blocker；旧提示/菜单即时翻译、时间选择器、临时 SSH 目标标题和极窄英文电源/周期问题均修复后复查。
- 完整 **919/919，71 个文件**；相较基线新增142项。九批顺序运行：100、99、117、57、85、51、247、75、88，每个外层 Flutter CLI 退出码0。完整文件清单与日志的实际加载文件逐项相等，无遗漏、重复或跳过。
- `flutter pub get --enforce-lockfile --offline`、format **144文件 / 0变化**、`flutter analyze --no-pub` 零问题、`git diff --check` 均通过。
- 最终代码额外复跑 **66 + 14 项真实字体验证**，两个外层退出码均0；覆盖19页双语320px/2倍、四类横屏表单、语言选择、安全对话框、英文两步电源确认与命令面板。另83项最终小修定向回归包含四个流量周期、选中态语义、打开菜单即时切换和旧周期几何断言。
- 测试字体为 Noto Sans CJK SC 第2 face 的专用子集；775个映射字符的轮廓与 advance 逐一等于原字体，ASCII与英文弯引号均保留。截图来自隔离 Flutter engine，使用合成资料；生产字体未修改。英文界面中的合成中文名称属于原始用户数据，不随语言翻译。
- 旧测试的直接 `Text` 子节点 cast 与硬编码英语 Back tooltip 假设已更新为检查实际渲染文字/真实可点击返回按钮；完整文字、几何、触区、导航层级与一次性操作断言全部保留。较早失败轮单独保留，不计入上述结果；修复后从头重跑完整清单。
- 使用未修改的官方 frontend，测试通过受支持的 starter 参数限制1024 MiB堆、单worker和磁盘TMPDIR。日志中的 frontend `-15` 是测试结束后官方 `ResidentCompiler.shutdown()` 主动清理；最终成功以每批 `All tests passed` 及外层退出码0共同核实，不把真实中断或失败计为通过。
- `flutter build linux --release --no-pub` 单worker成功，退出码0；155个生产输入与101个测试输入的 SHA-256 在最终测试/构建后完全相同。两款打包 DejaVu TTF 与源码逐字节相同。

生产 Linux `libapp.so` SHA-256：`b91cf8a2b98d0a1b7357929fdd3a0cdd90402aec29b786d6b17f372effb6ec00`。独立目录产物冻结，没有启动或覆盖已有 App / 演示 bundle。

### 尚未验证的设备边界

本轮没有 Android/iOS 构建、签名、安装升级或真机 IME / 原生认证 / 系统分享 / 通知实际送达验证。系统自有权限窗口由 OS 语言管理，iOS 包内加入英文与简体中文 Face ID 用途说明，不承诺应用内语言覆盖 OS 自有文字。真实用户数据库、API、SSH、原生剪贴板和钥匙环均未访问；网络测试只使用既有合成 loopback fixture。本地提交、完整 Git bundle 与验证资料交主会话协调发布和预览，不将本轮 Linux 成功当作远端 CI 或手机结果。


## macOS iOS 模拟器编译（2026-10-07 UTC）

源码基线：`61cacb36dc5528de5c6d15e631970a1fc42dd0c7`，`dev` 分支，接手时工作区及暂存区干净。

### 环境与已通过项

- Intel x86_64，macOS 15.7.3 / 24G419；Xcode 26.2 / 17C52；iOS 26.2 / 23C54 模拟器运行时。
- 本机原 SDK 为 Flutter 3.41.2 / Dart 3.11.0，不满足项目约束。由官方 Flutter Git 仓库的 `3.47.6` tag 独立安装 SDK 至 `/Users/zzq/Develops/flutter/3.47.6`，framework `5fc346839b5d0eef006ed8404392afb4dfae428d`、Dart 3.13.5；未覆盖原 SDK 或修改全局 PATH。
- `flutter pub get --enforce-lockfile`：退出码 0，`pubspec.lock` 未变化。
- `flutter analyze`：退出码 0，No issues found。
- `flutter test test/widget_test.dart test/locale_preference_test.dart --concurrency=1`：退出码 0，**12/12** 通过，覆盖空台账、新增/取消、重读恢复、归档撤销、390px / 2 倍文字、分组与持久化语言切换。没有在本次接手中重跑全部测试，也不将 Widget 测试当作模拟器实际界面验证。
- `flutter build ios --simulator --debug --no-codesign`：退出码 0，Xcode build 68.3 秒；保留既有 Swift Package Manager 配置，无需新增 Podfile 或改 deployment target。
- 产物 `build/ios/iphonesimulator/Runner.app`；Info.plist 确认 bundle ID `com.vpstellyou.vpsTellYou`、版本 `0.1.0`、build `1`，`file Runner` 确认 x86_64 / arm64 双架构。仅为 Debug 模拟器包，不是签名真机或发布候选。

### 前次未完成：模拟器启动与实际预览

目标设备：iPhone 17 Pro，ID `223AB863-E585-4BF6-8777-5A90F000CB3A`。`simctl` 可列出设备和运行时，但启动多次超时，设备仍为 Shutdown，尚未安装或运行应用，也没有模拟器截图。

2026-10-07 21:50:49（UTC+8）本机统一日志确认：

```text
Failed to create an IOAccelDevice... IOServiceOpen returned kIOReturn(0xE00002C7)
SimRenderServer/MetalDeviceDescriptor.swift:40: Fatal error: Attempt to initialize MetalDeviceDescriptor on a host that doesn't support Metal
```

同期 kernel 记录 `stalling for detach from AMDRadeonX6000_AMDNavi23GraphicsAccelerator`。崩溃报告为本机 `~/Library/Logs/DiagnosticReports/SimRenderServer-2026-10-07-215049.ips`，进程为 Apple `SimRenderServer`，不是 App。已确认 CoreSimulator 从 PID 1058 重启至 PID 94225；22:14:46（UTC+8）新 `SimRenderServer` 仍出现同一 Metal 初始化崩溃。证据指向宿主 GPU / Metal 链路异常，但底层驱动故障的具体原因尚未证明。

未删除/重建模拟器、未清除应用数据或降低项目约束，未改业务源码、未访问真实用户台账、秘密、SSH 或 API。没有自动重启 Mac。当时的下一步是先恢复本机 GPU / Metal 状态，再运行模拟器；后续结果如下，不将前次编译成功写成前次安装或预览通过。

### 重启后实际安装与启动（2026-10-08，UTC+8）

用户自行重启 Mac 后，于 06:27–06:29 继续验证，代码基于 `ca2c2b8`，工作区及暂存区干净。保留相同的 Xcode 26.2、Flutter 3.47.6 / Dart 3.13.5、iOS 26.2 / 23C54 和上述 iPhone 17 Pro 设备 ID，未切换渲染模式。

- 独立 Swift 原生检测显式链接 CoreGraphics，`MTLCopyAllDevices()` 返回 **1** 个设备，`MTLCreateSystemDefaultDevice()` 非 nil，`makeCommandQueue()` 成功。重启前相同检测为 0 / nil，说明 Metal 设备访问已恢复。
- `xcrun simctl boot … --arch=x86_64` 和 `bootstatus … -b` 均退出码 0，启动约 **15 秒**；打开真实 Simulator 窗口。
- `flutter pub get --enforce-lockfile` 与 `flutter build ios --simulator --debug --no-codesign --no-pub` 均退出码 0，Xcode build **10.4 秒**。产物仍为 `build/ios/iphonesimulator/Runner.app`，bundle ID `com.vpstellyou.vpsTellYou`，版本 0.1.0+1。
- `simctl install` 和 `simctl launch` 均成功，启动进程 PID 2395，后续进程查询仍在运行；Simulator 状态为 Booted。
- `simctl io … screenshot` 成功，真实截图 **1206×2622**，已实际查看：中文空台账首页、添加 / 面板导入 / 演示入口、服务器 / 费用 / 工具 / 设置导航项显示正常，没有台账打开失败或 Flutter 错误页面。未点击演示加载、未录入任何服务器或秘密。
- 截图与启动日志留在被 Git 忽略的 `build/ios-simulator-preview/`：`home.png`、`stdout.log`、`stderr.log`。stderr 有一条系统 restoration marker 警告，未阻止首页显示；启动后的定向日志查询未发现 `SimRenderServer` 的 Metal fatal / IOAccelDevice 错误。

本次未修改业务源码或锁文件，仅更新运行记录；未重复执行上次通过的 Widget 测试。App 和模拟器保留供用户操作。以上只证明构建、安装、启动和首屏显示，不代表四 Tab 点击、写入持久化、真实 SSH / API、Keychain / Face ID、通知、系统分享、后台或真机验收通过。

同一 Xcode / iOS / App 在恢复 Metal 后正常启动，排除了“必须降级这些版本才能启动本项目”的判断；此前的直接阻碍是宿主当时无法提供 Metal 设备。驱动异常的底层诱因仍未确定，不将一次重启恢复解释为已永久修复。


## RackNerd ctrl 独立面板与回归（2026-10-08，UTC+8）

基于 `1a7b35e`。用户提供该 VPS 客户端 API 文档并授权诊断；只调用 `status` / `info`，没有电源、SSH 或远端配置写入。真实凭据仅用于主会话进程内诊断，不交给 Team、不保存到代码、fixture、数据库或提交；真实响应只在内存解析，输出限协议结构及非敏感验证结果。

### 根因及实现

- 真实 multipart `status` 响应为 XML 声明加 `<ctrl>` 根节点，只有 status/statusmsg/vmstat；现有 V1 只接受字段片段或 `<response>`，因此正确拒绝不匹配的协议。form `info` 才返回 IP、hostname 和三个资源四元组；`rdtype=json` 得到顶层字符串字段 JSON。
- 新增稳定 `CloudProvider.rackNerd`、独立 Key/Hash 凭据及 adapter，固定一次 form-urlencoded POST `action=info` / `rdtype=json` / 五资源标志。旧 V1 请求与 XML 校验、V2 请求与分页校验未改；共享的资源投影保持地址/字节/零值/秘密反射语义。
- 保留默认严格 TLS、禁止重定向、超时取消与预算；RackNerd 响应限制16 KiB / 16层 / 2048节点，拒绝重复JSON键和嵌套权威字段。HTTP200 API错误不变成成功；未提供CPU和稳定ID时不猜测。
- schema10 在升级事务内复制完整账户/观测/关联图、保留FK开启、按依赖顺序重建云表约束；不动服务器/账务/SSH/偏好/秘密。真实v9表结构及晚期失败回滚、旧数据重开、非云schema不变均有测试。V1/RackNerd匿名重授权仍需明确解绑确认。
- 双语新增入口、Key/Hash表单、已规范化目标地址、六资源补填与仅保存流程。完整API路径只允许RackNerd专用的精确`/api/client/command.php`，不接收尾句号、query或任意路径。设置和面板页公共标题改为通用面板文案，不再误称只支持SolusVM。

### 实际验证

- 四成员 Team 均使用用户指定模型 `cus-resp/gpt-6.1-sol:xhigh`，分工为核心协议/控制器、无损迁移、UI、本轮独立审查。独立审查无未解决高风险问题；所有成员仅使用合成或loopback资料。
- Flutter **3.47.6 / Dart 3.13.5**；官方gen-l10n通过，`dart format --output=none --set-exit-if-changed lib test` **149文件 / 0变化**，`flutter analyze --no-pub` 无问题，`git diff --check`通过。
- 主会话最终全量：`VPS_SSH_FIXTURE_PYTHON="$PWD/.ssh-test-venv/bin/python" flutter test --no-pub --concurrency=4 --reporter expanded`，**1007通过、2失败，退出码1**，约78秒。覆盖原V1/V2、RackNerd、TLS、安全存储合成合同、SQLite迁移、账务/备份/SSH、双语UI；没有跳过主题测试来声称全绿。完整日志在本机`build/racknerd-final-test.log`。
- 两项失败是原`test/mobile_theme_test.dart`的浅/深色golden，均为**1.87% / 3287px**差异。Team在独立`git archive HEAD`基线`1a7b35e`、同SDK和同Mac环境复现相同失败；主会话也核验实际PNG字节相同：light SHA-256 `d813d6a32fb4c54ce6dd794421a656e01c07341d19c5688b0e76ae685bb7d4ed`，dark `6883eb39f84cdc5534098b0968c19210aee8a58684686c052dbac367093f23fd`。没有修改golden、主题源码或弱化断言；基线证据在本机`/tmp/vps-rack-baseline.cJjL0f/`，本轮失败图片保留在build下，不提交。
- 主会话额外使用**生产RackNerdAdapter / 默认HTTP客户端及证书验证**读取真实面板一次，独立检查**1/1通过**：匿名单实例、IP、hostname、内存、磁盘、流量有效，CPU/远端实例ID为空。未调用保存账户或导入，没有把真实凭据写入应用安全存储。
- 最终`flutter build ios --simulator --debug --no-codesign --no-pub`退出码0，Xcode构建**10.8秒**。原位安装/启动iPhone17Pro iOS26.2，未卸载清数据；SQLite只读核对schema9→10、原4条演示记录保留、`foreign_key_check`为空。最终启动PID6472，模拟器与App保持运行。
- 本机原生截图和启动日志在`build/racknerd-verification/`，首页正常；没有代替用户点击真实RackNerd账户保存、输入未知CPU或导入。真实读取成功、合成完整导入回归和模拟器运行是分别验证的，不合并宣称真实VPS已导入。

### 剩余边界

RackNerd ctrl是已核对的接口标识，不能仅凭兼容路径判断底层一定是SolusVM1或2。新类型的真机安全存储保存、通知/分享/后台仍需设备验收；既有主题golden的跨环境一致性问题单独保留，不属于本轮RackNerd协议回归。没有推送、发布或任何真实VPS电源操作。
