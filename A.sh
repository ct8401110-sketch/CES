#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

ANDROID_API="${ANDROID_API:-34}"
BUILD_TOOLS="${BUILD_TOOLS:-34.0.0}"
NDK_VERSION="${NDK_VERSION:-26.3.11579264}"
CMAKE_VERSION="${CMAKE_VERSION:-3.22.1}"

ANDROID_SDK_DIR="${ANDROID_SDK_DIR:-$HOME/android-sdk}"
CMDLINE_TOOLS_ZIP="${CMDLINE_TOOLS_ZIP:-commandlinetools-linux-11076708_latest.zip}"
CMDLINE_TOOLS_URL="${CMDLINE_TOOLS_URL:-https://dl.google.com/android/repository/${CMDLINE_TOOLS_ZIP}}"

DOTNET_USER_DIR="${DOTNET_USER_DIR:-$HOME/.dotnet}"

LOG_DIR="${LOG_DIR:-$HOME}"
LOG_FILE="${LOG_FILE:-$LOG_DIR/bootstrap-app-android-$(date +%Y%m%d-%H%M%S).txt}"

export DEBIAN_FRONTEND=noninteractive

exec > >(tee -a "$LOG_FILE") 2>&1

on_err() {
  local exit_code=$?
  echo "[FATAL] Falha na linha ${BASH_LINENO[0]}: comando '${BASH_COMMAND}' (exit=${exit_code})"
  echo "[FATAL] Log: $LOG_FILE"
  exit "$exit_code"
}
trap on_err ERR

log() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

need_sudo() {
  if ! command -v sudo >/dev/null 2>&1; then
    echo "[FATAL] sudo não encontrado."
    exit 1
  fi
}

as_root() { need_sudo; sudo "$@"; }

retry() {
  local -r tries="$1"; shift
  local -r delay="$1"; shift
  local n=0
  until "$@"; do
    n=$((n+1))
    if [ "$n" -ge "$tries" ]; then
      return 1
    fi
    log "retry ${n}/${tries}: $* (aguardando ${delay}s)"
    sleep "$delay"
  done
}

append_once() {
  local file="$1"
  local line="$2"
  touch "$file"
  grep -Fqs "$line" "$file" || printf "\n%s\n" "$line" >> "$file"
}

dpkg_has() { dpkg -s "$1" >/dev/null 2>&1; }

apt_update_once() {
  if [ "${_APT_UPDATED:-0}" = "0" ]; then
    log "apt: update"
    as_root apt-get update -y
    _APT_UPDATED=1
  fi
}

apt_install_missing() {
  apt_update_once
  local pkgs=()
  local p
  for p in "$@"; do
    if ! dpkg_has "$p"; then
      pkgs+=("$p")
    fi
  done
  if [ "${#pkgs[@]}" -gt 0 ]; then
    log "apt: install (${#pkgs[@]}): ${pkgs[*]}"
    as_root apt-get install -y --no-install-recommends "${pkgs[@]}"
  else
    log "apt: ok (nada a instalar)"
  fi
}

ensure_nodesource_20() {
  if command -v node >/dev/null 2>&1; then
    local major
    major="$(node -v | sed -E 's/^v([0-9]+).*/\1/')" || major=""
    if [ "$major" = "20" ]; then
      log "nodejs: já é v20"
      return 0
    fi
  fi

  log "nodejs: configurando NodeSource 20.x"
  apt_install_missing ca-certificates curl gnupg
  as_root mkdir -p /etc/apt/keyrings
  retry 3 2 bash -lc 'curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg'
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | as_root tee /etc/apt/sources.list.d/nodesource.list >/dev/null
  _APT_UPDATED=0
  apt_install_missing nodejs
  node -v || true
  npm -v || true
}

detect_java_home() {
  local javac_path
  javac_path="$(command -v javac 2>/dev/null || true)"
  if [ -z "$javac_path" ]; then
    return 0
  fi
  readlink -f "$javac_path" | sed 's#/bin/javac##'
}

ensure_java17() {
  log "Java: instalando JDK 17"
  apt_install_missing openjdk-17-jdk
  local jh
  jh="$(detect_java_home || true)"
  if [ -n "$jh" ]; then
    export JAVA_HOME="$jh"
    append_once "$HOME/.bashrc" "export JAVA_HOME=\"$JAVA_HOME\""
    append_once "$HOME/.profile" "export JAVA_HOME=\"$JAVA_HOME\""
    append_once "$HOME/.bashrc" "export PATH=\"\$JAVA_HOME/bin:\$PATH\""
    append_once "$HOME/.profile" "export PATH=\"\$JAVA_HOME/bin:\$PATH\""
  fi
  java -version 2>&1 | head -n 2 || true
  javac -version 2>&1 || true
}

ensure_dotnet8() {
  if command -v dotnet >/dev/null 2>&1; then
    local v
    v="$(dotnet --version 2>/dev/null || true)"
    if [[ "$v" == 8.* ]]; then
      log ".NET: já disponível (dotnet $v)"
      return 0
    fi
  fi

  log ".NET: tentando instalar via repositório Microsoft (apt)"
  apt_install_missing ca-certificates wget gpg apt-transport-https

  local ubuntu_codename
  ubuntu_codename="$(. /etc/os-release && echo "${VERSION_CODENAME:-}")"
  if [ -z "$ubuntu_codename" ]; then
    ubuntu_codename="jammy"
  fi

  as_root mkdir -p /etc/apt/keyrings
  if [ ! -f /etc/apt/keyrings/microsoft.gpg ]; then
    retry 3 2 bash -lc 'wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg'
  fi
  if [ ! -f /etc/apt/sources.list.d/microsoft-prod.list ]; then
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/ubuntu/${ubuntu_codename}/prod ${ubuntu_codename} main" | as_root tee /etc/apt/sources.list.d/microsoft-prod.list >/dev/null
    _APT_UPDATED=0
  fi

  apt_update_once
  if ! as_root apt-get install -y --no-install-recommends dotnet-sdk-8.0; then
    log ".NET: fallback dotnet-install (userland)"
    retry 3 2 curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
    mkdir -p "$DOTNET_USER_DIR"
    bash /tmp/dotnet-install.sh --channel 8.0 --install-dir "$DOTNET_USER_DIR"
    export DOTNET_ROOT="$DOTNET_USER_DIR"
    export PATH="$DOTNET_USER_DIR:$PATH"
    append_once "$HOME/.bashrc" "export DOTNET_ROOT=\"$DOTNET_USER_DIR\""
    append_once "$HOME/.profile" "export DOTNET_ROOT=\"$DOTNET_USER_DIR\""
    append_once "$HOME/.bashrc" "export PATH=\"\$DOTNET_ROOT:\$PATH\""
    append_once "$HOME/.profile" "export PATH=\"\$DOTNET_ROOT:\$PATH\""
  fi

  dotnet --info | head -n 25 || true
}

ensure_dotnet_android_workload() {
  log ".NET: garantindo workload android"
  if dotnet workload list 2>/dev/null | grep -qiE 'android'; then
    log ".NET: workload android já instalado"
  else
    dotnet workload install android
  fi
  dotnet workload list | sed -n '1,160p' || true
}

ensure_android_sdk() {
  log "Android: preparando SDK em $ANDROID_SDK_DIR"
  mkdir -p "$ANDROID_SDK_DIR/cmdline-tools" "$ANDROID_SDK_DIR/platform-tools" "$HOME/.android"

  local sdkmanager="$ANDROID_SDK_DIR/cmdline-tools/latest/bin/sdkmanager"
  if [ ! -x "$sdkmanager" ]; then
    log "Android: baixando cmdline-tools"
    local tmpdir
    tmpdir="$(mktemp -d)"
    retry 3 2 curl -fsSL -o "$tmpdir/cmdline.zip" "$CMDLINE_TOOLS_URL"
    unzip -q "$tmpdir/cmdline.zip" -d "$tmpdir"
    rm -rf "$ANDROID_SDK_DIR/cmdline-tools/latest"
    mv "$tmpdir/cmdline-tools" "$ANDROID_SDK_DIR/cmdline-tools/latest"
    rm -rf "$tmpdir"
  else
    log "Android: cmdline-tools já presente"
  fi

  export ANDROID_SDK_ROOT="$ANDROID_SDK_DIR"
  export ANDROID_HOME="$ANDROID_SDK_DIR"
  export PATH="$ANDROID_SDK_DIR/cmdline-tools/latest/bin:$ANDROID_SDK_DIR/platform-tools:$PATH"

  append_once "$HOME/.bashrc" "export ANDROID_SDK_ROOT=\"$ANDROID_SDK_DIR\""
  append_once "$HOME/.profile" "export ANDROID_SDK_ROOT=\"$ANDROID_SDK_DIR\""
  append_once "$HOME/.bashrc" "export ANDROID_HOME=\"$ANDROID_SDK_DIR\""
  append_once "$HOME/.profile" "export ANDROID_HOME=\"$ANDROID_SDK_DIR\""
  append_once "$HOME/.bashrc" "export PATH=\"\$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:\$ANDROID_SDK_ROOT/platform-tools:\$PATH\""
  append_once "$HOME/.profile" "export PATH=\"\$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:\$ANDROID_SDK_ROOT/platform-tools:\$PATH\""

  log "Android: aceitando licenças"
  yes | "$sdkmanager" --sdk_root="$ANDROID_SDK_DIR" --licenses >/dev/null || true

  log "Android: instalando platform-tools/platforms/build-tools/ndk/cmake"
  "$sdkmanager" --sdk_root="$ANDROID_SDK_DIR" \
    "platform-tools" \
    "platforms;android-${ANDROID_API}" \
    "build-tools;${BUILD_TOOLS}" \
    "cmdline-tools;latest" \
    "ndk;${NDK_VERSION}" \
    "cmake;${CMAKE_VERSION}"

  adb version | head -n 1 || true
  "$sdkmanager" --sdk_root="$ANDROID_SDK_DIR" --list_installed | sed -n '1,180p' || true
}

ensure_monogame() {
  log "MonoGame: templates + MGCB editor"
  dotnet new install MonoGame.Templates.CSharp >/dev/null 2>&1 || true
  dotnet tool install --global dotnet-mgcb-editor >/dev/null 2>&1 || true
  append_once "$HOME/.bashrc" "export PATH=\"\$HOME/.dotnet/tools:\$PATH\""
  append_once "$HOME/.profile" "export PATH=\"\$HOME/.dotnet/tools:\$PATH\""
  export PATH="$HOME/.dotnet/tools:$PATH"
}

ensure_mono() {
  log "Mono: instalando (legado)"
  apt_install_missing mono-complete || true
  if ! command -v mono >/dev/null 2>&1; then
    apt_install_missing mono-runtime mono-devel || true
  fi
  mono --version 2>/dev/null | head -n 2 || true
}

ensure_docker() {
  log "Docker: instalando client + compose plugin"
  apt_install_missing docker.io docker-compose-plugin
  if command -v docker >/dev/null 2>&1; then
    as_root usermod -aG docker "$USER" 2>/dev/null || true
    docker --version || true
    docker compose version 2>/dev/null || true
  fi
}

vscode_ext_installed() {
  local ext="$1"
  code --list-extensions 2>/dev/null | awk '{print tolower($0)}' | grep -qx "$(echo "$ext" | awk '{print tolower($0)}')"
}

install_vscode_extensions_41() {
  if ! command -v code >/dev/null 2>&1; then
    log "VS Code: 'code' não disponível. Pulando instalação de extensões."
    return 0
  fi

  local exts=(
    "13xforever.language-x86-64-assembly"
    "adelphes.android-dev-ext"
    "bbenoist.doxygen"
    "cheshirekow.cmake-format"
    "chrisatwindsurf.csharpextension"
    "chrisgroks.csharpextension"
    "cschlosser.doxdocgen"
    "danielpinto8zz6.c-cpp-project-generator"
    "dart-code.dart-code"
    "dart-code.flutter"
    "diemasmichiels.emulate"
    "dotnetdev-kr-custom.csharp"
    "dr-mohammed-hamed.android-studio-flash"
    "editorconfig.editorconfig"
    "franneck94.c-cpp-runner"
    "franneck94.vscode-c-cpp-config"
    "franneck94.vscode-c-cpp-dev-extension-pack"
    "haloscript.astyle-lsp-vscode"
    "hanwang.android-adb-wlan"
    "jajera.vsx-remote-ssh"
    "jeff-hykin.better-cpp-syntax"
    "jnoortheen.nix-ide"
    "kylinideteam.cmake-intellisence"
    "kylinideteam.cppdebug"
    "kylinideteam.kylin-clangd"
    "kylinideteam.kylin-cmake-tools"
    "kylinideteam.kylin-cpp-pack"
    "llvm-vs-code-extensions.vscode-clangd"
    "mitaki28.vscode-clang"
    "ms-dotnettools.csharp"
    "ms-dotnettools.csdevkit"
    "ms-dotnettools.vscode-dotnet-runtime"
    "ms-vscode.cmake-tools"
    "ms-vscode.cpptools"
    "muhammad-sammy.csharp"
    "november.clover-unity"
    "oracle.oracle-java"
    "redhat.java"
    "redhat.vscode-yaml"
    "twxs.cmake"
    "vadimcn.vscode-lldb"
    "zlorn.vstuc"
  )

  log "VS Code: instalando 41 extensões (pula as já instaladas)"
  local ext
  for ext in "${exts[@]}"; do
    if vscode_ext_installed "$ext"; then
      log "VS Code: ok (já instalada) $ext"
      continue
    fi
    log "VS Code: install $ext"
    code --install-extension "$ext" >/dev/null 2>&1 || true
  done

  log "VS Code: contagem instalada (após tentativa)"
  code --list-extensions | wc -l || true
}

install_base_toolchain_for_app() {
  log "Base/toolchain: instalando o necessário para compilar app (C/C++ + libs + utilitários)"
  apt_install_missing \
    bash coreutils \
    git openssh-client \
    curl wget jq \
    unzip zip tar xz-utils \
    file less nano \
    ca-certificates gnupg \
    build-essential gcc g++ make \
    cmake ninja-build meson pkg-config autoconf automake libtool \
    clang llvm lld gdb \
    python3 python3-pip \
    openssl sqlite3 libssl-dev zlib1g-dev libsqlite3-dev \
    libsdl2-dev libopenal-dev libfreetype6-dev libfontconfig1-dev libpng-dev \
    gradle
}

sanity() {
  log "Sanity:"
  echo "dotnet: $(dotnet --version 2>/dev/null || echo missing)"
  echo "workloads: $(dotnet workload list 2>/dev/null | tr '\n' ' ' | sed 's/  */ /g' | head -c 200 || true)"
  echo "java: $(java -version 2>&1 | head -n 1 || echo missing)"
  echo "javac: $(javac -version 2>&1 || echo missing)"
  echo "sdkmanager: $(command -v sdkmanager || echo missing)"
  echo "adb: $(adb version 2>/dev/null | head -n 1 || echo missing)"
  echo "mono: $(mono --version 2>/dev/null | head -n 1 || echo missing)"
  echo "docker: $(docker --version 2>/dev/null || echo missing)"
  echo "node: $(node -v 2>/dev/null || echo missing)"
  echo "npm: $(npm -v 2>/dev/null || echo missing)"
  echo "ANDROID_SDK_ROOT: ${ANDROID_SDK_ROOT:-unset}"
  echo "JAVA_HOME: ${JAVA_HOME:-unset}"
  echo "LOG: $LOG_FILE"
}

main() {
  log "Bootstrap iniciado (Ubuntu/Codespace). Log: $LOG_FILE"
  need_sudo

  log "1) Base + toolchain"
  install_base_toolchain_for_app

  log "2) Node.js 20 + npm"
  ensure_nodesource_20

  log "3) Java 17 + JAVA_HOME"
  ensure_java17

  log "4) .NET SDK 8"
  ensure_dotnet8

  log "5) .NET Android workload"
  ensure_dotnet_android_workload

  log "6) Android SDK (SDK/NDK/CMake conforme script base)"
  ensure_android_sdk

  log "7) Mono (legado)"
  ensure_mono

  log "8) MonoGame tools"
  ensure_monogame

  log "9) Docker"
  ensure_docker

  log "10) VS Code: 41 extensões"
  install_vscode_extensions_41

  sanity

  log "Concluído. Reabra o terminal (ou rode: source ~/.bashrc). Se instalou Docker, reabra para o grupo docker aplicar."
}

main "$@"
```0
