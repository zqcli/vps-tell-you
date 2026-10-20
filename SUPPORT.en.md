# Support

[简体中文](SUPPORT.md)

VPS Tell You is a free, open-source app maintained on GitHub. Support is handled in public through GitHub Issues.

## Get help or report a problem

Open an issue: https://github.com/zqcli/vps-tell-you/issues

Please include your app version (Settings › About), your iOS version and device, what you did, and what you expected to happen. Screenshots help. **Don’t post passwords, private keys, host keys you rely on or unredacted backups** in a public issue. Black out server addresses if you prefer.

Security problems: see https://github.com/zqcli/vps-tell-you/security. Where “Report a vulnerability” is offered, use it for a private report. Otherwise open an issue that describes the problem without exploit details or secrets.

## Common questions

**Where is my data?** Only on your device. There is no account and no developer server. See the privacy policy: https://github.com/zqcli/vps-tell-you/blob/dev/PRIVACY.en.md

**The provider directory won’t download.** The app downloads it from GitHub and falls back to the jsDelivr mirror. Check your connection and choose Check for Updates in Settings › Providers. Without a download, the app still works with your own providers.

**I’m not getting expiry reminders.** Allow notifications for the app in iOS Settings and open Settings › Notification Access in the app to check. The system limits how many reminders can be pending (iOS allows 64), and the app only schedules reminders for the next 366 days. Open the app regularly to refresh them.

**I lost a saved password or key.** Secrets are stored only in this device’s Keychain and are never exported or backed up, so the app can’t recover them. Enter the credential again.

**How do I move my ledger to another device?** Use Settings › Ledger Backup & Restore to export a JSON file and import it on the other device. Backups don’t include SSH credentials or host trust, so set those up again. The file is unencrypted: store it safely.

**Can I try SSH without a server?** The built-in demo servers are for exploring the ledger only. SSH, SFTP and TCP checks need a server you control.

## More

- Source code and releases: https://github.com/zqcli/vps-tell-you
- Privacy policy: https://github.com/zqcli/vps-tell-you/blob/dev/PRIVACY.en.md
