# fenv

[简体中文](README.zh.md)

fenv manages multiple Flutter SDK versions on macOS and Linux. Pin a version per project and run `flutter` and `dart` as usual. fenv supports both upstream Flutter and the [CPF-Flutter OpenHarmony fork](https://gitcode.com/CPF-Flutter/flutter_flutter).

fenv follows the design of [pyenv](https://github.com/pyenv/pyenv), [rbenv](https://github.com/rbenv/rbenv), and [nodenv](https://github.com/nodenv/nodenv). Keep several SDK versions installed side by side, record the exact version in a project file, and let lightweight shims on `PATH` select it when a command runs. A user default covers projects without a version file, and a shell override lets you try another version for one session. Installation supplies the SDKs that version selection can use.

## Installation

Install fenv from the [Homebrew tap](https://github.com/gavinliu/homebrew-tap):

```sh
brew install gavinliu/tap/fenv
```

fenv stores SDKs and user settings in `~/.fenv` by default.

### Set up your shell

Add the initialization command for your shell to your shell environment configuration.

**zsh**

```zsh
eval "$(fenv init zsh)"
```

**Bash**

```bash
eval "$(fenv init bash)"
```

Open a new terminal and run `fenv --version` to verify the setup.

### Update fenv

Upgrade fenv through Homebrew:

```sh
brew upgrade gavinliu/tap/fenv
```

## Usage

### Install an SDK and pin a project

```sh
fenv install 3.29.3
cd /path/to/flutter-project
fenv local 3.29.3
flutter --version
dart --version
```

Commit `.flutter-version` to share the exact SDK version with your team. With that file in place, running `fenv install` from the project installs the selected version.

### List releases and select the latest stable version

```sh
fenv install --list
fenv install --list-all
fenv install --list --source flutter
fenv install --list-all --source ohos
fenv install latest
fenv install latest --source ohos
```

The lists read the bundled catalog offline. `--list` shows stable releases and `--list-all` includes prereleases. The output is sorted by version and shows the source in the second column. Piped or redirected output uses tabs between the columns.

`latest` resolves to the newest stable upstream Flutter version in the local catalog by default. Add `--source ohos` for CPF-Flutter. `fenv local latest` and `fenv global latest` accept the same source option and save the resolved version number.

### Use Flutter for OpenHarmony

```sh
fenv install --list --source ohos
fenv install 3.41.10-ohos-1.0.1
fenv local 3.41.10-ohos-1.0.1
flutter --version
```

Upstream and OpenHarmony SDKs can coexist. Use the full tag in `.flutter-version` to select the OpenHarmony SDK. To build HAP packages, follow the OpenHarmony tooling setup in the [CPF-Flutter documentation](https://gitcode.com/CPF-Flutter/flutter_flutter).

## How it works

`fenv init` puts two shims on `PATH`. Each invocation of `flutter` or `dart` resolves the active SDK and runs its executable. Version selection follows this order:

1. `FENV_VERSION`, which can be set with `fenv shell`.
2. The nearest `.flutter-version` found in the current directory or its parents.
3. The user default set by `fenv global`.
4. `system`, which uses the existing command on `PATH`.

`fenv install` delegates to `flutter-build`. It clones the tag recorded in the local catalog, verifies the expected commit, and lets Flutter download the binaries for the host. It moves the SDK into `$(fenv root)/versions` after initialization succeeds.

## Command reference

| Command | Purpose |
| --- | --- |
| `fenv install [version]` | Install an explicit version, `latest`, or the selected version when omitted. |
| `fenv uninstall [--force] <version>` | Remove a managed SDK. Use `--force` to skip confirmation in scripts. |
| `fenv local [version]` | Read or set the project version. Use `--unset` to clear it. |
| `fenv global [version]` | Read or set the user default. Use `--unset` to clear it. |
| `fenv shell [version]` | Read or set the current shell override. Use `--unset` to clear it. |
| `fenv version` / `fenv versions` | Show the active version and how it was selected, or list installed SDKs. |
| `fenv latest [--source flutter\|ohos]` | Print the latest stable version in the local catalog. |
| `fenv which <flutter\|dart>` | Print the executable that will run. |
| `fenv root` / `fenv prefix [version]` | Print the fenv data directory or the SDK directory. Use `prefix` to locate an SDK for an IDE. |
| `fenv exec <command> [...]` | Run a command with the selected SDK on `PATH`, including in CI. |
| `fenv init <bash\|zsh>` / `fenv completions <bash\|zsh>` | Print shell initialization or completion code. |
| `fenv --version` / `fenv help` | Show the fenv version or CLI help. |

## Development

Run `bash tests/smoke.sh` for local regression tests. The [installation workflow](.github/workflows/install.yml) checks fenv and both SDK sources on macOS and Linux by installing them and checking version output.

Version definitions live in `share/flutter-build/versions.tsv`. To regenerate them, fetch the upstream tags and run:

```sh
git ls-remote --tags https://github.com/flutter/flutter.git > /tmp/flutter-tags.txt
git ls-remote --tags https://gitcode.com/CPF-Flutter/flutter_flutter.git > /tmp/flutter-ohos-tags.txt
tools/update-definitions /tmp/flutter-tags.txt /tmp/flutter-ohos-tags.txt
```

Each definition records a tag, a Git repository URL, and a commit SHA. Set `FLUTTER_BUILD_DEFINITIONS` to use a directory containing a custom `versions.tsv`.
