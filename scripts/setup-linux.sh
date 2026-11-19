#!/usr/bin/env bash
#
# Installs the toolchain needed to run every Linux CI gate (`make check`)
# into a user-writable directory. No root required. Linux x86_64 only.
#
# Usage: scripts/setup-linux.sh [component...]
#   Components: flutter jdk android ktlint swiftlint (default: all)
#
# A component is skipped when the pinned version is already installed in
# KLAVIYO_TOOLS_DIR, or is found outside it: on PATH, at JAVA_HOME (jdk), or at
# ANDROID_HOME / ANDROID_SDK_ROOT (android). When an outside copy is used, any
# other version of that component in KLAVIYO_TOOLS_DIR is removed.
#
# Env:
#   KLAVIYO_TOOLS_DIR (default: $HOME/.cache/klaviyo-flutter-sdk-tools)
#   GITHUB_PATH       when set (GitHub Actions), installed bin dirs (tools, flutter, jdk) are appended to it
#
# After running, load the toolchain into the current shell with:
#   source "$KLAVIYO_TOOLS_DIR/env.sh"
# The Makefile picks up the tools directory automatically.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_DIR="${KLAVIYO_TOOLS_DIR:-$HOME/.cache/klaviyo-flutter-sdk-tools}"

FLUTTER_VERSION="$(sed -n 's/.*"flutter": *"\([^"]*\)".*/\1/p' "$REPO_ROOT/.fvmrc")"
# sha256 of flutter_linux_<version>-stable.tar.xz, from
# https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json
declare -A FLUTTER_SHA256S=(
  ["3.38.7"]="2d72de31119ccba1421391aa9ab53891a3e4905987a13f8272766ad78e3bbf93"
  ["3.47.9"]="25ed8c3c29d51a7353f2a944310b478af8214920639524b19c50a19e6c044c5a"
)
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

JDK_URL="https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.21%2B9/OpenJDK17U-jdk_x64_linux_hotspot_17.0.21_9.tar.gz"
JDK_SHA256="8b9b611d917e3dfd8419d3566b5949226f69b052fed7e109c1368add1dfe8711"

ANDROID_CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip"
ANDROID_CMDLINE_TOOLS_SHA256="7ec965280a073311c339e571cd5de778b9975026cfcbe79f2b1cdcb1e15317ee"
# Mirrors flutter.ndkVersion from the Flutter Gradle plugin.
ANDROID_NDK_VERSION="28.2.13676358"
ANDROID_PACKAGES=("platform-tools" "platforms;android-36" "build-tools;36.0.0" "ndk;$ANDROID_NDK_VERSION")

KTLINT_VERSION="1.8.0"
KTLINT_URL="https://github.com/pinterest/ktlint/releases/download/${KTLINT_VERSION}/ktlint"
KTLINT_SHA256="a3fd620207d5c40da6ca789b95e7f823c54e854b7fade7f613e91096a3706d75"

SWIFTLINT_VERSION="0.65.1"
SWIFTLINT_URL="https://github.com/realm/SwiftLint/releases/download/${SWIFTLINT_VERSION}/swiftlint_linux_amd64.zip"
SWIFTLINT_SHA256="caeed6f4a679c35539ffaf124f6c4ab4a8416917f7d8796279dc52b74026059d"

log() { echo "==> $*" >&2; }
die() { echo "error: $*" >&2; exit 1; }

if [ "$(uname -s)" != "Linux" ] || [ "$(uname -m)" != "x86_64" ]; then
  die "only Linux x86_64 is supported; on macOS install the tools with Homebrew and fvm instead"
fi

for cmd in curl sha256sum tar unzip xz; do
  command -v "$cmd" >/dev/null || die "missing required command: $cmd"
done

# Downloads $1 to $2 and checks it against sha256 $3.
fetch() {
  local url="$1" dest="$2" sha="$3"
  curl -fsSL --retry 3 -o "$dest" "$url"
  echo "$sha  $dest" | sha256sum -c --quiet - || die "checksum mismatch for $url"
}

# Prints PATH without entries under $TOOLS_DIR, with the managed JDK appended
# when installed so JVM tools found on PATH (ktlint) can start.
external_path() {
  local entry out=() parts
  IFS=: read -ra parts <<<"$PATH"
  for entry in "${parts[@]}"; do
    case "$entry" in
      "$TOOLS_DIR" | "$TOOLS_DIR"/*) ;;
      *) out+=("$entry") ;;
    esac
  done
  if [ -x "$TOOLS_DIR/jdk/bin/java" ]; then out+=("$TOOLS_DIR/jdk/bin"); fi
  (IFS=:; echo "${out[*]}")
}

# Prints the path of command $1 on PATH outside $TOOLS_DIR, or nothing.
external_cmd() {
  PATH="$(external_path)" command -v "$1" || true
}

# Succeeds when directory $1 is $TOOLS_DIR or inside it.
in_tools_dir() {
  case "$1" in
    "$TOOLS_DIR" | "$TOOLS_DIR"/*) return 0 ;;
    *) return 1 ;;
  esac
}

# Prints the first x.y.z version in the output of the given command, or
# nothing when the command fails.
version_of() {
  local out
  out="$(PATH="$(external_path)" "$@" 2>&1)" || return 0
  grep -oE '[0-9]+\.[0-9]+\.[0-9]+' <<<"$out" | head -1 || true
}

# Removes each given path, relative to $TOOLS_DIR, that exists.
drop_managed() {
  local path
  for path in "$@"; do
    if [ -e "$TOOLS_DIR/$path" ]; then
      log "removing $TOOLS_DIR/$path"
      rm -rf "${TOOLS_DIR:?}/$path"
    fi
  done
}

install_flutter() {
  local marker="$TOOLS_DIR/flutter/.installed-$FLUTTER_VERSION"
  if [ -f "$marker" ]; then
    log "flutter $FLUTTER_VERSION already installed"
    return
  fi
  local flutter version
  flutter="$(external_cmd flutter)"
  if [ -n "$flutter" ]; then
    version="$(PATH="$(external_path)" "$flutter" --version --machine 2>/dev/null |
      sed -n 's/.*"frameworkVersion": *"\([^"]*\)".*/\1/p' | head -1 || true)"
    if [ "$version" = "$FLUTTER_VERSION" ]; then
      log "flutter $version already on PATH, skipping ($flutter)"
      drop_managed flutter
      return
    fi
    log "flutter on PATH is ${version:-unknown} ($flutter), want $FLUTTER_VERSION"
  fi
  local sha="${FLUTTER_SHA256S[$FLUTTER_VERSION]:-}"
  [ -n "$sha" ] || die "no sha256 for flutter $FLUTTER_VERSION; add it to FLUTTER_SHA256S in $0"
  log "installing flutter $FLUTTER_VERSION"
  rm -rf "$TOOLS_DIR/flutter"
  fetch "$FLUTTER_URL" "$TMP/flutter.tar.xz" "$sha"
  tar -xJf "$TMP/flutter.tar.xz" -C "$TOOLS_DIR"
  "$TOOLS_DIR/flutter/bin/flutter" config --no-analytics >/dev/null
  "$TOOLS_DIR/flutter/bin/flutter" --version >/dev/null
  touch "$marker"
}

install_jdk() {
  if [ -x "$TOOLS_DIR/jdk/bin/java" ]; then
    log "jdk already installed"
    return
  fi
  local java where
  if [ -n "${JAVA_HOME:-}" ] && ! in_tools_dir "$JAVA_HOME"; then
    java="$JAVA_HOME/bin/java"
    where="at JAVA_HOME"
  else
    java="$(external_cmd java)"
    where="on PATH"
  fi
  if [ -n "$java" ] && [ -x "$java" ]; then
    local version
    version="$("$java" -version 2>&1 | sed -n 's/.* version "\([^"]*\)".*/\1/p' | head -1 || true)"
    if [ "${version%%.*}" = "17" ]; then
      log "java $version already $where, skipping ($java)"
      return
    fi
    log "java $where is ${version:-unknown} ($java), want 17"
  fi
  log "installing temurin jdk 17"
  rm -rf "$TOOLS_DIR/jdk"
  mkdir -p "$TOOLS_DIR/jdk"
  fetch "$JDK_URL" "$TMP/jdk.tar.gz" "$JDK_SHA256"
  tar -xzf "$TMP/jdk.tar.gz" -C "$TOOLS_DIR/jdk" --strip-components=1
}

# Prints the first package in ANDROID_PACKAGES not installed under SDK root $1.
android_missing_package() {
  local pkg dir
  for pkg in "${ANDROID_PACKAGES[@]}"; do
    dir="$1/${pkg//;//}"
    if [ ! -f "$dir/package.xml" ] && [ ! -f "$dir/source.properties" ]; then
      echo "$pkg"
      return
    fi
  done
}

install_android() {
  local sdk="$TOOLS_DIR/android-sdk"
  local sdkmanager="$sdk/cmdline-tools/latest/bin/sdkmanager"
  if [ -x "$sdkmanager" ] && [ -z "$(android_missing_package "$sdk")" ]; then
    log "android sdk packages already installed"
    return
  fi
  local var root missing
  for var in ANDROID_HOME ANDROID_SDK_ROOT; do
    root="${!var:-}"
    if [ -z "$root" ] || in_tools_dir "$root"; then continue; fi
    missing="$(android_missing_package "$root")"
    if [ -z "$missing" ]; then
      log "android sdk ${ANDROID_PACKAGES[*]} already at $var, skipping ($root)"
      drop_managed android-sdk
      return
    fi
    log "android sdk at $var ($root) is missing $missing"
  done
  if [ ! -x "$sdkmanager" ]; then
    log "installing android command-line tools"
    fetch "$ANDROID_CMDLINE_TOOLS_URL" "$TMP/cmdline-tools.zip" "$ANDROID_CMDLINE_TOOLS_SHA256"
    rm -rf "$sdk/cmdline-tools"
    mkdir -p "$sdk/cmdline-tools"
    unzip -q "$TMP/cmdline-tools.zip" -d "$TMP/cmdline-tools"
    mv "$TMP/cmdline-tools/cmdline-tools" "$sdk/cmdline-tools/latest"
  fi
  local java_home="${JAVA_HOME:-}"
  if [ -x "$TOOLS_DIR/jdk/bin/java" ]; then
    java_home="$TOOLS_DIR/jdk"
  elif [ -z "$java_home" ] && [ -n "$(external_cmd java)" ]; then
    java_home="$(dirname "$(dirname "$(readlink -f "$(external_cmd java)")")")"
  fi
  [ -n "$java_home" ] || die "android sdkmanager needs a JDK; install the jdk component or set JAVA_HOME"
  log "installing android sdk packages: ${ANDROID_PACKAGES[*]}"
  yes | JAVA_HOME="$java_home" "$sdkmanager" --sdk_root="$sdk" --licenses >/dev/null || true
  JAVA_HOME="$java_home" "$sdkmanager" --sdk_root="$sdk" "${ANDROID_PACKAGES[@]}" >/dev/null
}

install_ktlint() {
  if [ -x "$TOOLS_DIR/bin/ktlint" ] && [ -f "$TOOLS_DIR/bin/.ktlint-$KTLINT_VERSION" ]; then
    log "ktlint $KTLINT_VERSION already installed"
    return
  fi
  local ktlint version
  ktlint="$(external_cmd ktlint)"
  if [ -n "$ktlint" ]; then
    version="$(version_of "$ktlint" --version)"
    if [ "$version" = "$KTLINT_VERSION" ]; then
      log "ktlint $version already on PATH, skipping ($ktlint)"
      drop_managed bin/ktlint
      rm -f "$TOOLS_DIR"/bin/.ktlint-*
      return
    fi
    log "ktlint on PATH is ${version:-unknown} ($ktlint), want $KTLINT_VERSION"
  fi
  log "installing ktlint $KTLINT_VERSION"
  fetch "$KTLINT_URL" "$TOOLS_DIR/bin/ktlint" "$KTLINT_SHA256"
  chmod +x "$TOOLS_DIR/bin/ktlint"
  rm -f "$TOOLS_DIR"/bin/.ktlint-*
  touch "$TOOLS_DIR/bin/.ktlint-$KTLINT_VERSION"
}

install_swiftlint() {
  if [ -x "$TOOLS_DIR/bin/swiftlint" ] && [ -f "$TOOLS_DIR/bin/.swiftlint-$SWIFTLINT_VERSION" ]; then
    log "swiftlint $SWIFTLINT_VERSION already installed"
    return
  fi
  local swiftlint version
  swiftlint="$(external_cmd swiftlint)"
  if [ -n "$swiftlint" ]; then
    version="$(version_of "$swiftlint" --version)"
    if [ "$version" = "$SWIFTLINT_VERSION" ]; then
      log "swiftlint $version already on PATH, skipping ($swiftlint)"
      drop_managed bin/swiftlint
      rm -f "$TOOLS_DIR"/bin/.swiftlint-*
      return
    fi
    log "swiftlint on PATH is ${version:-unknown} ($swiftlint), want $SWIFTLINT_VERSION"
  fi
  log "installing swiftlint $SWIFTLINT_VERSION"
  fetch "$SWIFTLINT_URL" "$TMP/swiftlint.zip" "$SWIFTLINT_SHA256"
  unzip -q -o "$TMP/swiftlint.zip" swiftlint-static -d "$TMP"
  mv "$TMP/swiftlint-static" "$TOOLS_DIR/bin/swiftlint"
  chmod +x "$TOOLS_DIR/bin/swiftlint"
  rm -f "$TOOLS_DIR"/bin/.swiftlint-*
  touch "$TOOLS_DIR/bin/.swiftlint-$SWIFTLINT_VERSION"
}

write_env() {
  cat >"$TOOLS_DIR/env.sh" <<EOF
# Generated by scripts/setup-linux.sh
export KLAVIYO_TOOLS_DIR="$TOOLS_DIR"
if [ -d "$TOOLS_DIR/jdk" ]; then export JAVA_HOME="$TOOLS_DIR/jdk"; fi
if [ -d "$TOOLS_DIR/android-sdk" ]; then export ANDROID_HOME="$TOOLS_DIR/android-sdk"; fi
for _dir in "$TOOLS_DIR/jdk/bin" "$TOOLS_DIR/flutter/bin" "$TOOLS_DIR/bin"; do
  if [ -d "\$_dir" ]; then export PATH="\$_dir:\$PATH"; fi
done
unset _dir
EOF
}

components=("$@")
if [ ${#components[@]} -eq 0 ]; then
  components=(flutter jdk android ktlint swiftlint)
fi

mkdir -p "$TOOLS_DIR/bin"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

for component in "${components[@]}"; do
  case "$component" in
    flutter | jdk | android | ktlint | swiftlint) "install_$component" ;;
    *) die "unknown component: $component (expected flutter, jdk, android, ktlint or swiftlint)" ;;
  esac
done

write_env

if [ -n "${GITHUB_PATH:-}" ]; then
  echo "$TOOLS_DIR/bin" >>"$GITHUB_PATH"
  for dir in "$TOOLS_DIR/flutter/bin" "$TOOLS_DIR/jdk/bin"; do
    if [ -d "$dir" ]; then echo "$dir" >>"$GITHUB_PATH"; fi
  done
fi

log "done; run: source \"$TOOLS_DIR/env.sh\""
