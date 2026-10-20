# Privacy Policy

Effective date: 2026-10-20 · Applies to VPS Tell You 0.6.0 and later · [简体中文](PRIVACY.md)

VPS Tell You is a free, open-source app for keeping track of your own VPS servers. It keeps everything on your device. This policy explains what the app stores, which network connections it makes, and who can see what.

## In short

- Your ledger, notes and settings stay on your device. The developer has no server, no account system and no way to see them.
- The app contains no analytics, advertising, tracking or crash-reporting code.
- The app makes two kinds of network connections: an automatic download of a public provider list, and the SSH, SFTP and TCP connections you start yourself.

## What is stored on your device

- **The ledger.** Servers, providers, groups, payments, notes, manual exchange rates and settings are stored in a local SQLite database in the app’s private storage. Exchange rates are values you enter; the app does not fetch live rates.
- **SSH settings.** Host, port, username and the proxy you choose are stored in the same database.
- **Secrets.** SSH passwords, private keys, key passphrases and proxy passwords are stored in the iOS Keychain. They are set to be available only while the device is unlocked, only on this device, and are not synced through iCloud Keychain. They are never written to the ledger database, backups or logs.
- **Face ID, Touch ID and passcode.** Device verification only controls whether the app shows a saved password on screen. iOS performs the check and tells the app whether it succeeded; the app never receives biometric data. The verification does not gate connections: when you connect, the app reads the saved credential from the Keychain directly.
- **Directory cache.** The downloaded provider list and logos are cached locally so the app works offline.
- **Files you download.** SFTP downloads are saved in the app’s Documents folder, under “SFTP Downloads”. You can see them in the Files app, under On My iPhone (or iPad) › VPS Tell You.

## Network connections

### 1. The public provider directory (automatic)

The app downloads a public list of VPS providers (names, short descriptions and logos) from the project’s repository:

- Primary: `raw.githubusercontent.com` (GitHub)
- Mirror, used when the primary can’t be reached: `cdn.jsdelivr.net` (jsDelivr)

The app checks when you open it, if the last successful check is more than 12 hours old, and whenever you choose Check for Updates. You can turn the launch check off in Settings › Providers › Update on Launch. If you do, the app only contacts these hosts when you check manually.

These requests are plain HTTPS downloads. The app sends no ledger data, account, cookie, advertising identifier or device identifier. As with any web request, the servers that answer it receive technical information such as your IP address, the time, the requested path and a generic HTTP client user agent, and may log it under their own policies. The developer doesn’t operate these services and doesn’t receive their logs. See:

- GitHub: https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement
- jsDelivr: https://www.jsdelivr.com/terms/privacy-policy

### 2. Connections you start (SSH, SFTP, TCP, proxies)

When you open a terminal or SFTP session, or run a TCP check, the app connects directly to the address you entered, or through the SOCKS5, HTTP or HTTPS proxy you chose. The server receives what you type or transfer, and the credentials you configured for it. A proxy sees the destination address and port of each connection and the proxy credentials you gave. These connections go only where you point them. The developer is not involved and receives nothing.

### 3. Nothing else

The app has no developer server and no push-notification server. It doesn’t send analytics, crash reports or telemetry anywhere.

## Notifications

Expiry reminders are local notifications scheduled on your device. They show a generic title and the due date; they don’t include server names, addresses or prices. Notification permission is optional and can be changed in iOS Settings.

## Exports and backups

- **JSON backups** are plain, unencrypted text. They contain server names, providers, addresses, notes, groups, amounts, dates, payments and exchange rates. They exclude SSH credentials, private keys, proxies and trusted host keys. A backup goes only where you send it, and that app or service has its own privacy practices. Don’t publish a backup, and don’t paste notes that hold secrets.
- **Images** of cost calculations are created on your device and shared through the iOS share sheet to the destination you choose.
- **Device backups.** iOS may include the app’s data in iCloud or computer backups of your device, depending on your device settings. Secrets kept as this-device-only Keychain items don’t move to a new device.

## Retention and deletion

Your data stays on your device until you delete it. You can delete payment records, groups, custom providers, snippets, saved credentials, proxies and trusted hosts inside the app. A server record can be archived but isn’t removed individually. Delete files in SFTP Downloads from the Files app. Deleting the app removes the ledger database, the cache and the downloaded files. iOS may keep Keychain items after an app is deleted. To remove saved passwords and keys for certain, delete the credentials in the app before you uninstall it. Because the developer holds none of your data, there is nothing for the developer to export or erase for you.

## Children

VPS Tell You is a tool for people who manage servers and is not directed at children. The developer collects no personal data from anyone, including children.

## Changes

If this policy changes, the new version is published in the project repository with a new effective date, and the updated text ships with the app. Earlier versions are available in the repository history.

## Contact

Questions about this policy: open an issue at https://github.com/zqcli/vps-tell-you/issues. Please don’t post passwords, keys or unredacted backups in a public issue.

Security problems: see https://github.com/zqcli/vps-tell-you/security. Where “Report a vulnerability” is offered, use it for a private report. Otherwise open an issue that describes the problem without exploit details or secrets.

Public copy of this policy: https://github.com/zqcli/vps-tell-you/blob/dev/PRIVACY.en.md
