# README / wiki 截图与 GIF · Screenshots and GIFs

`docs/images/{zh,en}/` 里的所有图都来自**真实 App 在 iOS 模拟器上的输出**（`xcrun simctl io` 截图 / 录屏，系统字体、状态栏固定为 9:41），不是设计稿或组件测试渲染。数据全部是合成的演示数据：文档保留地址（203.0.113.0/24、198.51.100.0/24、2001:db8::/32）、虚构服务器名，SSH 目标是只绑定 127.0.0.1 的演示服务器，不涉及任何真实凭据或真实服务器。

All images in `docs/images/{zh,en}/` are pixel-real simulator output of the real app with synthetic demo data (documentation-only IPs, invented names, a loopback-only demo SSH server). No real credentials or servers are involved.

## 组成 · Pieces

| 文件 | 作用 |
| --- | --- |
| `integration_test/screenshots_test.dart` | 脚本化巡览（`integration_test`，仅开发依赖，不进发布包）；需要截图 / 录屏时通过本机回环 HTTP 通知宿主 |
| `integration_test/demo_ledger.dart` | 全新演示账本：6 台服务器（BandwagonHost、阿里云、RackNerd、Hetzner、DMIT + 1 个自建提供商）、USD / CNY / EUR 付款历史、到期日分散（hk-01 5 天后到期） |
| `test_driver/integration_test.dart` | `flutter drive` 的标准 driver |
| `tool/make_screenshots.py` | 宿主编排：状态栏覆盖、模拟器语言、演示 SSH 服务、`flutter drive`、`simctl io screenshot / recordVideo` |
| `tool/demo_ssh_server.py` | 基于 `test/support/ssh_fixture/server.py` 的演示 SSH/SFTP 服务：仅回环，**从不执行任何命令**，对 `pwd / ls -lah / uptime / df -h / free -h` 返回固定的合成文本；SFTP 是夹具自带的 chroot 子系统，指向 `/tmp/vps-demo-sftp`（合成文件）。登录：`demo` / `demo-password` |
| `tool/finish_images.py` | 后处理：PNG 缩到 440 px 宽并优化、GIF（360 px 宽、12 fps、≤ 4 MB）、`hero.png`（1600×900） |

## 重新生成 · Regenerate

前提：Flutter 3.47.6、已启动的 iPhone 16 Pro Max 模拟器、网络（提供商目录与 Logo 从 GitHub raw 下载并缓存，巡览会等到 Logo 就绪）、带 `asyncssh` 的 Python（见 `test/support/ssh_fixture/README.md`）。

```sh
export PATH=/path/to/flutter/3.47.6/bin:$PATH
export VPS_SSH_FIXTURE_PYTHON=/path/to/venv/bin/python   # 装有 asyncssh
UDID=<模拟器 UDID>

# 1. 录制（每种语言约 4 分钟；会把模拟器切到该语言并重启一次）
python3 tool/make_screenshots.py --udid $UDID --lang zh --lang en --restore-zh

# 2. 应用图标（hero.png 用）
flutter test tool/app_icon_test.dart                      # -> build/app_icon/rounded.png

# 3. 后处理到 docs/images/
uv run --with pillow --with imageio-ffmpeg python tool/finish_images.py
```

- 单独重拍某几步：`--only servers,detail`（巡览名见 `screenshots_test.dart` 的 `tour(...)`）；`--theme dark` 改初始主题。
- 原始截图 / 视频在 `build/shots/<lang>/raw/`（已被 git 忽略）。
- `terminal.gif` 含首次连接的主机公钥确认，所以它必须在其他信任该演示主机的步骤之前录制；会改动账本的 `add-server` / `renew` 排在最后——不要调整这个顺序。
- 巡览会把所见都当作真实 UI 操作（点击、逐字输入）；只有系统通知权限用一个“已允许”的空实现代替，避免系统弹窗遮挡画面（提醒页内容仍由账本计算）。
- 模拟器的键盘首次引导提示可用 `xcrun simctl spawn $UDID defaults write com.apple.keyboard.preferences DidShowContinuousPathIntroduction -bool true` 关闭。

## 交付规格 · Output

`hero.png` 1600×900；其余 PNG 440 px 宽；GIF 360 px 宽、≤ 4 MB。`docs/images` 总量 ≤ 25 MB。文件名见各语言目录（zh / en 同名）。
