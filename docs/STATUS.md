# 状态

更新：2026-10-06 UTC

## 当前增量：服务器硬件与云关联整理

基于已发布 `943a916ac823ead6c7a2259a5cc355b896dab6ae`。新增/编辑均可维护六项硬件，手动未知可留空；SolusVM 1 导入保持完整确认。流量单位与月/季/年周期独立，旧记录不猜测周期。详情仅展示本地硬件与简洁云关联入口；服务器侧可从已保存实例关联、更换或解除，本地与远端资料互不覆盖。费用页移除独立账户账单创建入口，保留历史。

schema v8 无损接受旧资源 JSON，阻止不兼容旧客户端打开新资料；迁移不重写旧行。关联事务通过版本与 generation 防冲突/ABA，保留付款撤销与 SSH。交互与数据规则见 [SERVER_MANAGEMENT_UX](SERVER_MANAGEMENT_UX.md)。

- 最终全量 624/624、format 110 文件 / 0 改动、analyze / diff 检查通过。
- 独立 Astra xhigh review APPROVE，87 项关键测试全过；修复旧 v7 自动规格摘要同步并保留用户自定义规格。
- 390px / 2 倍文字流程通过，合成硬件卡截图经实际查看。原生 GUI 因隔离显示 socket 不可用未运行，Android/iOS 真机未运行。
- 生产 `lib/main.dart` Linux release 构建通过。该阶段尚未推送；未操作既有用户 App、钥匙环或真实 API 凭据。

## 前一增量：SolusVM 1 六项资源导入

以阶段 6 本地源码 `422b5c6` 为基线。正式读取使用一次带资源标志的 status 请求；有效 IP、hostname、磁盘/流量额度、内存和 vCPU 自动预填，缺失/全零配置在导入前要求补齐，支持明确不限量流量。财务仍在导入后编辑。

schema v7 添加可空的本地资源 JSON 和来源，API 观测与本地数据分离；刷新/解绑保留本地配置。旧台账事务迁移和旧 v1 JSON 备份继续兼容。细节见 [SOLUSVM_RESOURCES](SOLUSVM_RESOURCES.md)。

- 独立 Astra xhigh review 修正占位 IP/hostname 与懒加载资源表单滚动失效问题；最终 571 项全量测试、format / analyze / diff 检查及 `lib/main.dart` 生产 Linux release 构建通过。
- 2026-10-06 Linux 原生真实新增流程通过：用户亲自点继续导入后，四项 API 资源预填，用户补填 RAM/vCPU，单次本地导入成功；详情与 API/手动来源正确，仅重启隔离测试 App 后六项完整保留。费用仍未知，SSH/主机信任/付款未创建；未新增远端请求或执行电源/配置写入。旧主 App、钥匙环和台账保留，共享秘密引用未清理/解绑/重新授权。
- 该六资源增量已发布于 `943a916ac823ead6c7a2259a5cc355b896dab6ae`；本次服务器交互整理以此为基线。旧阶段 6 APK 不包含六项表单；各次 APK 以对应交付记录为准，Android/iOS 真实设备结果不能由 Linux 代替。

## 基线：阶段 6 移动端候选

基线为已验证的阶段 4 `d9e8d35079a7f41ec0e89332eda4af83f87dc063`，并合入已发布阶段 5 / SSH 输出修正 `b7ab2ca018625a40bfefcd577d035f507c7ac811`（同源本地候选 `be301d3`）；[阶段 5 同 SHA CI #7](https://github.com/zqcli/vps-tell-you/actions/runs/37428264493) 通过。独立提醒/分享模块检查点 `47c6b99c6d467afd6bb2e1ddd655b3f470f6af38` 已复测。当前阶段最终提交 SHA 和远端同 SHA CI 必须由 Git / Actions 实时核对，不沿用早期 CI 作为证明。

- Flutter 3.47.6 / Dart 3.13.5；应用 0.1.0+1，SQLite schema v6
- 每台提醒规则、使用计划、真实通知权限 API、串行重排 / 取消、时区 / 容量 / 覆盖状态；Linux 不排程
- Android / iOS 白名单 PNG 分享接线，取消 / 未知 / 失败保持预览
- 部分范围明文 JSON 台账导出、严格预览与空台账原子恢复；无凭据 / 主机信任 / 云关联恢复，导入后提醒默认关闭
- 持久化系统 / 浅色 / 深色，390px / 大字与合成组件 golden
- Android INTERNET、通知接收器 / 重启恢复、非精确闹钟、图标保留和 desugaring；iOS 通知 delegate 接线

## 当前验证

- 独立 Astra xhigh 全阶段审查通过；修正后的独立全回归 428 / 428、focused 100 / 100、format / analyze / diff check 全通过，Linux release build 已通过
- 最终代码 `4d38572a2047ac0878d385b0548b878a2feeeabe` 合并后 428 / 428 全回归、Linux release 重建和原生流程通过；原生取消 / 保存 / 重启、明文备份空库恢复与 PNG 保存证据见 ACCEPTANCE
- Android 通用测试签名 APK 已在云端本地离线 Gradle 构建并通过独立 Astra xhigh 产物审查：源 `94003d14f980c0b83eeee8ed4b4ba08379ff97df`，49,489,632 字节，SHA-256 `f5ca8ca55b32b2a93aa5b26dd24fb8a80f400f860eca8cb18c046b90e376bd0f`；仅 arm64-v8a / x86_64，未运行手机安装或通知等实测
- 为适应附件大小限制，同一源码另生成并独立核验两个可单独安装的 APK：ARM64 24,674,032 字节、x86_64 26,191,304 字节，精确哈希与版本见 ACCEPTANCE；选择设备对应的一份安装
- 阶段 6 基线验收未使用真实 VPS 或生产 power action；后续用户主动提交的独立 VirMach 只读诊断另见六资源记录，仍未执行电源或配置写入
- iOS 编译 / 签名 / 安装未运行；Android / iOS 实机存储、权限投递、分享、IME / 旋转 / 切网 / 后台仍未验证

## 恢复与下一项

先看 README / 本文件 / ACCEPTANCE → `git status` / 分支 / 远端 → `git rev-parse HEAD` / 远端同 SHA / CI → 锁文件安装、分析、测试和适用平台构建。不要自动删库、改 schema 版本逃避迁移、降低测试断言、自动 tag 或强推。正式签名密钥与真实秘密不得提交。

停止条件是可交接的测试候选和清楚的设备验收清单；未做真机项目不能写成通过。最后原生、APK、review 与 CI 结果补充于下方完成记录。
