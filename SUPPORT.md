# 支持

[English](SUPPORT.en.md)

VPS Tell You 是在 GitHub 上维护的免费开源应用，支持通过 GitHub Issues 公开处理。

## 获取帮助或反馈问题

提交 issue：https://github.com/zqcli/vps-tell-you/issues

请附上应用版本（设置 › 关于）、iOS 版本和设备型号、你的操作步骤以及期望的结果，截图会有帮助。**请勿在公开 issue 中粘贴密码、私钥、你所依赖的主机公钥或未脱敏的备份**；服务器地址也可以自行遮盖。

安全问题：见 https://github.com/zqcli/vps-tell-you/security 。如果页面提供“Report a vulnerability”，请用它私下报告；否则请提交 issue，只描述问题，不要包含利用细节或秘密。

## 常见问题

**我的数据在哪里？** 只在你的设备上。没有账号，也没有开发者服务器。详见隐私政策：https://github.com/zqcli/vps-tell-you/blob/dev/PRIVACY.md

**提供商目录下载不了。** 应用从 GitHub 下载，失败时会改用 jsDelivr 镜像。请检查网络，并在“设置 › 提供商管理”中点按“检查更新”。没有下载目录时，应用仍可使用你自己添加的提供商。

**收不到到期提醒。** 请在 iOS 设置中允许应用通知，并在应用的“设置 › 通知权限”中查看状态。系统限制可同时排队的提醒数量（iOS 最多 64 条），应用也只安排未来 366 天内的提醒。请定期打开应用以更新提醒。

**忘了已保存的密码或密钥。** 秘密只保存在本机钥匙串，不会导出或备份，应用无法找回，请重新输入凭据。

**怎样把台账迁移到另一台设备？** 在“设置 › 台账备份与恢复”导出 JSON 文件，再在另一台设备导入。备份不含 SSH 凭据和主机公钥信任，需要重新设置。文件未加密，请妥善保存。

**没有服务器能试用 SSH 吗？** 内置的演示服务器只用于浏览台账。SSH、SFTP 和 TCP 检测需要你自己的服务器。

## 更多

- 源代码与发布：https://github.com/zqcli/vps-tell-you
- 隐私政策：https://github.com/zqcli/vps-tell-you/blob/dev/PRIVACY.md
