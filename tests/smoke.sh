#!/usr/bin/env bash
set -eu

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
temp=$(mktemp -d)
trap 'rm -rf -- "$temp"' EXIT
export FENV_ROOT="$temp/sdk cache"
unset FENV_VERSION FLUTTER_BUILD_DEFINITIONS
mkdir -p "$temp/project/subdir" "$temp/tools"
export PATH="$repo/bin:$temp/tools:$PATH"

printf '#!/bin/bash\necho system-flutter\n' > "$temp/tools/flutter"
chmod +x "$temp/tools/flutter"

make_repository() {
  local flavor=$1 version=$2 source=$temp/$1
  git init -q "$source"
  git -C "$source" config user.name 'fenv test'
  git -C "$source" config user.email 'fenv@example.invalid'
  mkdir -p "$source/bin"
  cat > "$source/bin/flutter" <<'MOCK'
#!/usr/bin/env bash
set -e
if [[ ${1:-} == --version ]]; then
  [[ $CI == true && $2 == --suppress-analytics ]]
  git rev-parse --verify HEAD >/dev/null
  printf 'setup\n' >> "$SETUPS"
  [[ ${FAIL_SETUP:-0} == 0 ]]
  sleep 1
  printf '%s\n' initialized > bin/cache-ready
else
  printf '%s\n' "$0:$*"
fi
MOCK
  cat > "$source/bin/dart" <<'MOCK'
#!/usr/bin/env bash
set -e
[[ -f ${0%/*}/cache-ready ]]
printf '%s\n' "$0:$*"
MOCK
  chmod +x "$source/bin/flutter" "$source/bin/dart"
  git -C "$source" add bin
  git -C "$source" commit -qm "$version"
  git -C "$source" tag -am "$version" "$version"
  printf '%s\tfile://%s\t%s\n' "$version" "$source" "$(git -C "$source" rev-parse HEAD)"
}

export SETUPS="$temp/setups"
upstream=3.29.3
ohos=3.41.10-ohos-1.0.1
mkdir -p "$temp/definitions"
{
  make_repository upstream "$upstream"
  make_repository ohos "$ohos"
} > "$temp/definitions/versions.tsv"

# Block Git entirely while checking that listing works with either catalog.
cat > "$temp/tools/git" <<'MOCK'
#!/usr/bin/env bash
printf 'git called during offline listing\n' > "$SETUPS"
exit 1
MOCK
chmod +x "$temp/tools/git"
fenv install --list > "$temp/list"
fenv install --list-all > "$temp/list-all"
for list in list list-all; do
  listed=$(awk -F '\t' '$1 == "3.7.12-ohos" || $1 == "3.29.3" || $1 == "3.49.0-0.1.pre" || $1 == "3.50.0+ohos-0.0.1-pre"' "$temp/$list")
  expected=$'3.7.12-ohos\tCPF-Flutter\n3.29.3\tFlutter'
  if [[ $list == list-all ]]; then
    expected+=$'\n3.49.0-0.1.pre\tFlutter\n3.50.0+ohos-0.0.1-pre\tCPF-Flutter'
  fi
  [[ $listed == "$expected" ]]
done
for mode in --list --list-all; do
  for source in flutter ohos; do
    case "$source" in
      flutter) provider=Flutter ;;
      ohos) provider=CPF-Flutter ;;
    esac
    fenv install "$mode" --source "$source" > "$temp/filtered"
    awk -F '\t' -v provider="$provider" '$2 == provider' "$temp/${mode#--}" > "$temp/expected"
    cmp "$temp/expected" "$temp/filtered"
  done
done
if fenv install --list --source unknown 2>"$temp/error"; then exit 1; fi
grep -q 'unknown source: unknown' "$temp/error"
export FLUTTER_BUILD_DEFINITIONS="$temp/definitions"
expected_list=$(printf '%s\tfile://%s/upstream\n%s\tfile://%s/ohos\n' "$upstream" "$temp" "$ohos" "$temp")
[[ $(flutter-build --list) == "$expected_list" ]]
[[ ! -e $FENV_ROOT && ! -e $SETUPS ]]
mkdir -p "$temp/latest-definitions"
cat > "$temp/latest-definitions/versions.tsv" <<'CATALOG'
3.10.2	https://github.com/flutter/flutter.git
4.0.0-0.1.pre	https://github.com/flutter/flutter.git
3.9.2	https://github.com/flutter/flutter.git
3.10.2+ohos-1.0.10	https://gitcode.com/CPF-Flutter/flutter_flutter.git
3.10.2+ohos-1.0.9	https://gitcode.com/CPF-Flutter/flutter_flutter.git
4.0.0+ohos-0.0.1-pre	https://gitcode.com/CPF-Flutter/flutter_flutter.git
CATALOG
(
  export FENV_ROOT="$temp/latest-root" FLUTTER_BUILD_DEFINITIONS="$temp/latest-definitions"
  for version in 3.10.2 3.10.2+ohos-1.0.10; do
    mkdir -p "$FENV_ROOT/versions/$version/bin"
    cp "$temp/tools/flutter" "$FENV_ROOT/versions/$version/bin/flutter"
    cp "$temp/tools/flutter" "$FENV_ROOT/versions/$version/bin/dart"
  done
  [[ $(fenv install latest) == 'Flutter 3.10.2 is already installed' ]]
  [[ $(fenv install latest --source ohos) == 'Flutter 3.10.2+ohos-1.0.10 is already installed' ]]
  [[ $(fenv latest) == 3.10.2 ]]
  [[ $(fenv latest --source ohos) == 3.10.2+ohos-1.0.10 ]]
  export FENV_ROOT="$temp/latest-config"
  mkdir "$temp/latest-project"
  cd "$temp/latest-project"
  for scope in local global; do
    fenv "$scope" latest --source ohos
    [[ $(fenv "$scope") == 3.10.2+ohos-1.0.10 ]]
    fenv "$scope" latest
    [[ $(fenv "$scope") == 3.10.2 ]]
  done
  [[ $(cat .flutter-version) == 3.10.2 && $(cat "$FENV_ROOT/version") == 3.10.2 ]]
  [[ ! -e "$FENV_ROOT/versions" ]]
  : > "$FLUTTER_BUILD_DEFINITIONS/versions.tsv"
  if fenv install latest --source ohos 2>"$temp/error"; then exit 1; fi
  grep -q 'no stable versions for ohos' "$temp/error"
  for scope in local global; do
    if fenv "$scope" latest --source ohos 2>"$temp/error"; then exit 1; fi
    grep -q 'no stable versions for ohos' "$temp/error"
    [[ $(fenv "$scope") == 3.10.2 ]]
  done
)
[[ ! -e $SETUPS ]]
rm "$temp/tools/git"

eval "$(fenv init bash)"
[[ $(flutter) == system-flutter ]]
fenv global "$upstream"
cd "$temp/project"
fenv local "$ohos"
cd subdir
[[ $(fenv version) == "$ohos (set by $temp/project/.flutter-version)" ]]
[[ $(FENV_VERSION=system flutter) == system-flutter ]]
if flutter 2>"$temp/error"; then exit 1; fi
grep -q "Run: fenv install $ohos" "$temp/error"
if FAIL_SETUP=1 fenv install; then exit 1; fi
[[ ! -e "$FENV_ROOT/versions/$ohos" ]]
[[ ! -d "$FENV_ROOT/versions/.$ohos.lock" ]]

# A moved tag must fail before running setup.
original_commit=$(git -C "$temp/ohos" rev-parse HEAD)
git -C "$temp/ohos" commit --allow-empty -qm 'moved tag'
git -C "$temp/ohos" tag -f "$ohos" >/dev/null
: > "$SETUPS"
if fenv install 2>"$temp/error"; then exit 1; fi
grep -q 'resolved to .* expected' "$temp/error"
[[ ! -s $SETUPS && ! -e "$FENV_ROOT/versions/$ohos" ]]
git -C "$temp/ohos" tag -fam "$ohos" "$ohos" "$original_commit" >/dev/null

fenv install &
first=$!
fenv install &
second=$!
wait "$first"
wait "$second"
[[ $(cat "$SETUPS") == setup ]]
[[ $(fenv prefix) == "$FENV_ROOT/versions/$ohos" ]]
[[ $(fenv which dart) == "$FENV_ROOT/versions/$ohos/bin/dart" ]]
[[ $(git -C "$(fenv prefix)" remote get-url origin) == "file://$temp/ohos" ]]
[[ $(flutter doctor 'one arg') == "$FENV_ROOT/versions/$ohos/bin/flutter:doctor one arg" ]]
[[ $(dart --version) == "$FENV_ROOT/versions/$ohos/bin/dart:--version" ]]

flutter-build "$upstream" "$FENV_ROOT/versions/$upstream"
[[ $(FENV_VERSION=$upstream fenv exec flutter test) == "$FENV_ROOT/versions/$upstream/bin/flutter:test" ]]
[[ $(fenv versions) == "  $upstream"$'\n'"* $ohos" ]]
if fenv install 3.31.0 2>"$temp/error"; then exit 1; fi
grep -q 'unavailable in the local definitions' "$temp/error"
if command -v zsh >/dev/null; then
  export ohos upstream
  zsh -fc '
    eval "$(fenv init zsh)"
    [[ $(dart --version) == "$FENV_ROOT/versions/$ohos/bin/dart:--version" ]] || exit 1
    fenv shell "$upstream" && [[ $(fenv shell) == "$upstream" ]] || exit 1
    fenv shell --unset && [[ -z ${FENV_VERSION-} ]] || exit 1
    compdef() { :; }
    compadd() { printf "%s\n" "$@"; }
    eval "$(fenv completions zsh)"
    words=(fenv install latest --source "")
    CURRENT=5
    [[ $(_fenv_completion) == "$(printf "%s\n" -- flutter ohos)" ]]
  '
fi
[[ $(fenv root) == "$FENV_ROOT" ]]
[[ $(fenv prefix "$upstream") == "$FENV_ROOT/versions/$upstream" ]]
[[ $(fenv --version) == "fenv $(cat "$repo/libexec/fenv-version")" ]]
fenv shell "$upstream"
[[ $(fenv shell) == "$upstream" && $(fenv prefix) == "$FENV_ROOT/versions/$upstream" ]]
if fenv shell ../bad; then exit 1; fi
[[ $FENV_VERSION == "$upstream" ]]
fenv shell --unset
[[ -z ${FENV_VERSION-} && $(fenv prefix) == "$FENV_ROOT/versions/$ohos" ]]

eval "$(fenv completions bash)"
COMP_WORDS=(fenv install latest --source o)
COMP_CWORD=4
_fenv_completion
[[ ${COMPREPLY[*]} == ohos ]]
COMP_WORDS=(fenv uninstall 3.)
COMP_CWORD=2
_fenv_completion
[[ ${COMPREPLY[*]} == "$upstream $ohos" ]]

if fenv uninstall "$ohos" </dev/null 2>"$temp/error"; then exit 1; fi
grep -q 'requires confirmation' "$temp/error"
[[ -d "$FENV_ROOT/versions/$ohos" ]]
fenv uninstall --force "$ohos" 2>"$temp/error"
grep -q 'selected by .*\.flutter-version' "$temp/error"
[[ ! -e "$FENV_ROOT/versions/$ohos" ]]
[[ $(fenv version) == "$ohos (set by $temp/project/.flutter-version)" ]]
fenv uninstall --force "$upstream" 2>"$temp/error"
grep -Fq "selected by $FENV_ROOT/version" "$temp/error"
[[ $(fenv global) == "$upstream" ]]
fenv global --unset
[[ ! -e "$FENV_ROOT/version" ]]
if fenv uninstall --force system; then exit 1; fi
printf 'Smoke tests passed\n'
