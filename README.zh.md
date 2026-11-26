# fenv

[English](README.md)

fenv 是面向 macOS 和 Linux 的 Flutter SDK 版本管理工具。项目可以各自锁定版本，日常仍然直接运行 `flutter` 和 `dart`。支持 Flutter 官方版和 [CPF-Flutter 鸿蒙版](https://gitcode.com/CPF-Flutter/flutter_flutter)。

## 安装

需要 Bash、Git 和 Flutter 所需的主机依赖。在源码目录运行：

```sh
bash install.sh
```

安装器将 fenv 装到 `~/.fenv`，并根据 `SHELL` 识别 Bash 或 zsh。Bash 初始化写入 `~/.bashrc` 和登录配置，zsh 初始化写入 `~/.zprofile` 或 `$ZDOTDIR/.zprofile`。初始化也会启用 Tab 补全。

| 选项 | 用途 |
| --- | --- |
| `--shell bash` 或 `--shell zsh` | 指定要配置的 Shell。 |
| `--no-init` | 安装工具，并打印可手动执行的初始化命令。 |
| `--repo <git-url>` | 从指定的 fenv Git 仓库安装。 |
| `FENV_ROOT=/path/to/fenv` | 指定安装与数据目录。 |

安装完成后打开新的登录终端，或执行安装器打印的初始化命令。更新 fenv 时，从更新后的源码目录重新运行安装器即可，已有 SDK 和版本配置会保留。

## 使用

### 安装 SDK 并锁定项目版本

```sh
fenv install 3.29.3
cd /path/to/flutter-project
fenv local 3.29.3
flutter --version
dart --version
```

把 `.flutter-version` 提交到 Git，团队成员就能共享同一个具体版本。之后在项目目录直接运行 `fenv install`，即可安装选中的版本。

### 查看版本列表与选择最新稳定版

```sh
fenv install --list
fenv install --list-all
fenv install --list --source flutter
fenv install --list-all --source ohos
fenv install latest
fenv install latest --source ohos
```

列表离线读取随工具分发的版本目录。`--list` 显示稳定版，`--list-all` 同时显示预发布版。列表按版本号排序，第二列显示来源。接管道或重定向时，两列用 Tab 分隔。

`latest` 默认选择本地目录中的 Flutter 官方最新稳定版，使用 `--source ohos` 可切换到 CPF-Flutter。`fenv local latest` 和 `fenv global latest` 接受相同的来源参数，并写入解析出的具体版本号。

### 使用鸿蒙 Flutter

```sh
fenv install --list --source ohos
fenv install 3.41.10-ohos-1.0.1
fenv local 3.41.10-ohos-1.0.1
flutter --version
```

官方 SDK 和鸿蒙 SDK 可以同时安装。把完整的鸿蒙标签写入 `.flutter-version` 即可选中对应 SDK。构建 HAP 时，按 [CPF-Flutter 项目文档](https://gitcode.com/CPF-Flutter/flutter_flutter) 配置鸿蒙工具链。

## 工作原理

`fenv init` 将两个 shim 加入 `PATH`。每次运行 `flutter` 或 `dart`，shim 都会解析当前版本并执行对应 SDK 中的命令。版本按以下优先级选择：

1. `FENV_VERSION` 环境变量，可用 `fenv shell` 设置。
2. 从当前目录向上找到的最近一份 `.flutter-version`。
3. 由 `fenv global` 设置的用户默认版本。
4. `system`，即使用常规 `PATH` 中找到的命令。

`fenv install` 将安装交给 `flutter-build`。它克隆本地目录记录的 Git 标签，校验提交，再由 Flutter 下载适合主机的二进制产物。初始化成功后，SDK 才会移入 `$(fenv root)/versions`。

## 命令参考

| 命令 | 用途 |
| --- | --- |
| `fenv install [version]` | 安装指定版本、`latest`，或在省略参数时安装当前选中的版本。 |
| `fenv uninstall [--force] <version>` | 卸载由 fenv 管理的 SDK。脚本可用 `--force` 跳过确认。 |
| `fenv local [version]` | 查看或设置项目版本。用 `--unset` 清除。 |
| `fenv global [version]` | 查看或设置用户默认版本。用 `--unset` 清除。 |
| `fenv shell [version]` | 查看或设置当前终端的版本覆盖。用 `--unset` 清除。 |
| `fenv version` / `fenv versions` | 查看当前版本与配置来源，或列出已安装 SDK。 |
| `fenv latest [--source flutter\|ohos]` | 输出本地目录中的最新稳定版。 |
| `fenv which <flutter\|dart>` | 显示实际运行的可执行文件路径。 |
| `fenv root` / `fenv prefix [version]` | 显示 fenv 数据目录或 SDK 目录。可用 `prefix` 获取 IDE 所需的 SDK 路径。 |
| `fenv exec <command> [...]` | 将选中的 SDK 加入 `PATH` 后执行命令，可用于 CI。 |
| `fenv init <bash\|zsh>` / `fenv completions <bash\|zsh>` | 输出 Shell 初始化或补全代码。 |
| `fenv --version` / `fenv help` | 查看 fenv 自身版本或命令帮助。 |

## 开发

运行 `bash tests/smoke.sh` 执行本地回归测试。[安装验证工作流](.github/workflows/install.yml) 在 macOS 和 Linux 上安装 fenv 与两种来源的 SDK，并检查版本输出。

版本定义存放于 `share/flutter-build/versions.tsv`。更新定义时，从两个仓库获取 Git 标签后执行：

```sh
git ls-remote --tags https://github.com/flutter/flutter.git > /tmp/flutter-tags.txt
git ls-remote --tags https://gitcode.com/CPF-Flutter/flutter_flutter.git > /tmp/flutter-ohos-tags.txt
tools/update-definitions /tmp/flutter-tags.txt /tmp/flutter-ohos-tags.txt
```

每条定义记录标签、仓库 URL 和提交 SHA。用 `FLUTTER_BUILD_DEFINITIONS` 可以指定存放自定义 `versions.tsv` 的目录。
