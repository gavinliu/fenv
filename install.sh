#!/usr/bin/env bash
set -eu

usage() {
  printf '%s\n' 'Usage: install.sh [--shell bash|zsh] [--no-init] [--repo <git-url>]'
}

die() {
  printf 'fenv installer: %s\n' "$*" >&2
  exit 1
}

shell=${SHELL:-}
shell=${shell##*/}
configure=1
repository=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --shell)
      [[ $# -ge 2 ]] || die '--shell requires bash or zsh'
      shell=$2
      [[ $shell == bash || $shell == zsh ]] || die '--shell requires bash or zsh'
      shift 2
      ;;
    --no-init)
      configure=0
      shift
      ;;
    --repo)
      [[ $# -ge 2 && -n $2 ]] || die '--repo requires a Git URL'
      repository=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *) usage >&2; die "unknown option: $1" ;;
  esac
done

checkout=
pending=
trap '
  if [[ -n $pending ]]; then rm -f -- "$pending" || :; fi
  if [[ -n $checkout ]]; then rm -rf -- "$checkout" || :; fi
' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

if [[ -n $repository ]]; then
  checkout=$(mktemp -d)
  git clone --depth 1 -- "$repository" "$checkout/fenv"
  source_dir=$checkout/fenv
elif [[ -n ${BASH_SOURCE[0]:-} ]]; then
  source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
else
  die 'run install.sh from a checkout or supply --repo <git-url>'
fi

# Copy only the distribution files. SDKs and user configuration live alongside them.
files=(
  bin/fenv bin/flutter-build
  libexec/fenv-common libexec/fenv-completion libexec/fenv-sdk-lock
  libexec/fenv-shell libexec/fenv-uninstall
  completions/bash completions/zsh shims/flutter shims/dart
  share/flutter-build/versions.tsv libexec/fenv-version README.md README.zh.md
)
for file in "${files[@]}"; do
  [[ -f $source_dir/$file ]] || die "source is missing $file: $source_dir"
done

target=${FENV_ROOT:-$HOME/.fenv}
mkdir -p -- "$target"
target=$(cd -- "$target" && pwd -P)
if [[ $target != "$source_dir" ]]; then
  for file in "${files[@]}"; do
    destination=$target/$file
    mkdir -p -- "${destination%/*}"
    [[ ! -d $destination ]] || die "install path is a directory: $destination"
    pending=$(mktemp "${destination%/*}/.fenv-install.XXXXXX")
    cp -p -- "$source_dir/$file" "$pending"
    mv -f -- "$pending" "$destination"
    pending=
  done
fi

print_init() {
  local shell_version=BASH_VERSION
  if [[ $1 == zsh ]]; then shell_version=ZSH_VERSION; fi
  printf 'if [ -n "${%s:-}" ]; then if [ -z "${FENV_ROOT:-}" ]; then export FENV_ROOT=%q; fi; eval "$(%q init %s)"; fi\n' \
    "$shell_version" "$target" "$target/bin/fenv" "$1"
}

configure_profile() {
  local profile=$1 line=$2
  if [[ -f $profile ]] && grep -Fqx -- "$line" "$profile"; then
    return
  fi
  printf '\n# fenv initialization\n%s\n' "$line" >> "$profile"
  printf 'Configured %s\n' "$profile"
}

printf 'Installed fenv in %s\n' "$target"
if [[ $configure == 0 || ( $shell != bash && $shell != zsh ) ]]; then
  printf 'Run the initialization line for your shell:\n'
  print_init bash
  print_init zsh
  exit 0
fi

line=$(print_init "$shell")
case "$shell" in
  bash)
    configure_profile "$HOME/.bashrc" "$line"
    # Login Bash reads the first existing file in this order.
    login_profile=$HOME/.bash_profile
    for profile in "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; do
      if [[ -f $profile ]]; then
        login_profile=$profile
        break
      fi
    done
    configure_profile "$login_profile" "$line"
    ;;
  zsh)
    configure_profile "${ZDOTDIR:-$HOME}/.zprofile" "$line"
    ;;
esac
printf 'Open a new %s terminal, or run:\n%s\n' "$shell" "$line"
