# 许可证与第三方组件

本项目以 **MIT** 发布（仓库根目录 `LICENSE`，`Copyright (c) 2026 zqcli and contributors`）。应用内「设置 / 关于 / 许可证」显示同一份文本（`LICENSE` 作为资源随应用打包）。

第三方组件保留各自的许可证。提供商目录（`catalog/`）里的名称和 Logo 属于各自所有者的商标或版权，仅用于识别，与其所有者没有隶属或背书关系。

## 直接依赖的许可证核对

逐个读取 `.dart_tool/package_config.json` 里每个包 `rootUri` 下的 `LICENSE` 文件核对（版本见 `pubspec.yaml`）。全部为宽松许可证，可与 MIT 项目一起分发。

| 包 | 许可证 |
| --- | --- |
| flutter / flutter_localizations（Flutter SDK） | BSD-3-Clause |
| intl, path, crypto, http | BSD-3-Clause（Dart project authors） |
| path_provider, file_selector, local_auth, local_auth_android, local_auth_darwin | BSD-3-Clause（Flutter Authors） |
| share_plus | BSD-3-Clause |
| flutter_secure_storage | BSD-3-Clause |
| flutter_local_notifications | BSD-3-Clause |
| sqflite, sqflite_common_ffi | BSD-2-Clause |
| timezone | BSD-2-Clause |
| dartssh2 | MIT |
| xterm | MIT |
| xml | MIT |
| flutter_timezone | Apache-2.0 |
| 开发依赖：flutter_lints, path_provider_platform_interface | BSD-3-Clause |
| 字体 DejaVu Sans Mono 2.37（`assets/fonts/`） | Bitstream Vera / DejaVu 许可证（见 `assets/fonts/LICENSE-DejaVu.txt`） |

间接依赖的许可证文本由 Flutter 的 `LicenseRegistry` 在应用内「开源组件 / 全部许可证」中列出；DejaVu 在启动时注册。

## 应用内入口

- 「关于」页：版本、更新记录、源代码链接（点按复制）、许可证、开源组件。
- 精选列表来自 `lib/settings/open_source_page.dart` 的 `kOpenSourceComponents`。新增或升级直接依赖时请同步该列表和上表。
