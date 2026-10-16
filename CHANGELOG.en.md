# Changelog

<!--
How to add entries (the app shows this file under Settings / About / What’s New):
1. Add a release heading at the top: `## 0.2.0 — 2026-11-01`, or `## 0.2.0 — Unreleased`.
2. Group entries under `### Added`, `### Changed` and `### Removed` as needed
   (they match 新增 / 变更 / 移除 in the Chinese CHANGELOG.md).
3. Start each entry with `- ` and write one user-facing sentence; indent
   continuation lines by two spaces; `**bold**` is available for emphasis.
4. Update CHANGELOG.md as well; when releasing, change kAppVersion in
   lib/core/app_info.dart together with version in pubspec.yaml.
This comment is not shown.
-->

## 0.1.0 — Unreleased

### Added

- **Server ledger**: record name, IPv4 / IPv6 / hostname, purpose, specs and notes; search, groups, favorites, due-date filters and sorting; archived servers can be restored
- **Local first**: data lives in a SQLite database on your device, the ledger starts empty and no account is needed; an unreadable database is never deleted automatically
- **Cost overview**: subtotals in original currencies, known / unknown coverage, provider and group breakdowns, and 30-day and six-month forecasts
- **Payments and renewals**: record payments and renew 1–3 cycles with duplicate-submit protection and safe undo; it only keeps records and never pays a provider
- **Exchange rates and calculator**: manual USD / EUR to CNY reference rates; the remaining-value calculator supports quotes and fees, and can copy text or save a PNG
- **Expiry reminders**: choose how many days ahead each server reminds you; local notifications that never include names, addresses or amounts
- **SSH terminal**: full-screen xterm with password or key login (including encrypted keys), a special-keys row, command snippets and manual reconnect
- **Terminal schemes and smart highlighting**: 4 color schemes, with prompts, IPs, paths and errors colored automatically and the text left untouched
- **SFTP file manager**: browse, upload, download, rename, move and delete, plus a text editor with syntax highlighting
- **Host key verification**: confirm on first connect; a changed key blocks the connection
- **TCP test**: check a single host and port, IPv6 included
- **IPv6**: SSH, SFTP and TCP tests all work with IPv6 addresses
- **Provider directory**: names, logos and descriptions of 76 cloud and VPS providers, searchable when you pick one; you can still create your own
- **Credential storage**: passwords and keys are kept in the system secure storage and need device authentication to view
- **Local backup**: export the ledger as JSON (with a preview of what is included) and restore it into an empty ledger; credentials and host trust are never included
- **Bilingual interface**: Simplified Chinese and English, or follow the system
- **Appearance**: light, dark or follow the system
- **About page**: version, changelog, source code, license and open-source components

### Changed

- The interface was redesigned in an iOS style, with the same components and interactions on iOS and Android
- The provider directory is downloaded from GitHub and cached, and the cache is used offline; the app never uploads your ledger
- The project is open source under the MIT license, free to use and supported only by voluntary donations

### Removed

- Panel adapters: servers are no longer imported or synced from provider panels
- Plans: servers no longer link to a plan, and backups no longer contain plan fields
