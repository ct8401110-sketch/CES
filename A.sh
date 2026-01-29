#!/usr/bin/env bash

# Configuração de segurança do Bash
# Aborta se um comando falhar, se uma variável não estiver definida ou se houver erro em pipe
set -Eeuo pipefail
IFS=$'\n\t'

# Definição de Variáveis de Versão e Configuração
ANDROID_API="34"
BUILD_TOOLS="34.0.0"
NDK_VERSION="26.3.11579264"
CMAKE_VERSION="3.22.1"

# Caminhos do Sistema
USER_HOME="$HOME"
if [ -n "${SUDO_USER:-}" ]; then
  USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
fi

ANDROID_SDK_DIR="$USER_HOME/android-sdk"
DOTNET_USER_DIR="$USER_HOME/.dotnet"
CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"

# Configuração de Logs
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="$USER_HOME/bootstrap-install-$TIMESTAMP.log"

# Evita interatividade do apt
export DEBIAN_FRONTEND=noninteractive

# Redireciona stdout e stderr para o log e para o console
exec > >(tee -a "$LOG_FILE") 2>&1

# ------------------------------------------------------------------------------
# Funções de Utilitários e Logging
# ------------------------------------------------------------------------------

# Função para registrar mensagens informativas em verde
log_info() {
  local msg="$1"
  local time
  time=$(date +%H:%M:%S)
  printf "\033[0;32m[%s] [INFO] %s\033[0m\n" "$time" "$msg"
}

# Função para registrar avisos em amarelo
log_warn() {
  local msg="$1"
  local time
  time=$(date +%H:%M:%S)
  printf "\033[0;33m[%s] [WARN] %s\033[0m\n" "$time" "$msg" >&2
}

# Função para registrar erros fatais em vermelho e sair
log_fatal() {
  local msg="$1"
  local time
  time=$(date +%H:%M:%S)
  printf "\033[0;31m[%s] [FATAL] %s\033[0m\n" "$time" "$msg" >&2
  exit 1
}

# Tratamento de erro (trap)
on_error() {
  local exit_code=$?
  local line_number=${BASH_LINENO[0]}
  local command="${BASH_COMMAND}"
  log_fatal "Falha na linha $line_number executando: '$command'. Código de saída: $exit_code. Verifique o log em: $LOG_FILE"
}
trap on_error ERR

# Verificação de privilégios
check_sudo() {
  if [ "$(id -u)" -ne 0 ] && ! command -v sudo >/dev/null 2>&1; then
    log_fatal "Este script requer privilégios de superusuário (root) ou sudo instalado."
  fi
}

# Wrapper para execução como root
run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

# Wrapper para execução como o usuário real (não root)
run_as_user() {
  if [ -n "${SUDO_USER:-}" ]; then
    sudo -u "$SUDO_USER" "$@"
  else
    "$@"
  fi
}

# Adicionar variáveis de ambiente de forma persistente
append_to_profile() {
  local var_name="$1"
  local var_value="$2"
  local files=("$USER_HOME/.bashrc" "$USER_HOME/.profile" "$USER_HOME/.zshrc")
  
  export "$var_name"="$var_value"

  for file in "${files[@]}"; do
    if [ -f "$file" ] || [ "$file" = "$USER_HOME/.bashrc" ]; then
      touch "$file"
      if ! grep -q "export $var_name=" "$file"; then
        echo "export $var_name=\"$var_value\"" >> "$file"
        log_info "Variável $var_name adicionada ao $file"
      fi
    fi
  done
}

# Adicionar ao PATH de forma persistente
append_to_path() {
  local new_path="$1"
  local files=("$USER_HOME/.bashrc" "$USER_HOME/.profile" "$USER_HOME/.zshrc")
  
  export PATH="$new_path:$PATH"

  for file in "${files[@]}"; do
    if [ -f "$file" ] || [ "$file" = "$USER_HOME/.bashrc" ]; then
      touch "$file"
      if ! grep -q "export PATH=\"$new_path:\$PATH\"" "$file"; then
        echo "export PATH=\"$new_path:\$PATH\"" >> "$file"
        log_info "Caminho $new_path adicionado ao PATH em $file"
      fi
    fi
  done
}

# Wrapper seguro para apt-get install
install_apt_package() {
  local package="$1"
  if dpkg -s "$package" >/dev/null 2>&1; then
    log_info "Pacote '$package' já está instalado."
  else
    log_info "Instalando pacote: $package"
    run_as_root apt-get install -y -qq \
      -o Dpkg::Options::="--force-confdef" \
      -o Dpkg::Options::="--force-confold" \
      --no-install-recommends "$package"
  fi
}

# Wrapper para download com retries
download_file() {
  local url="$1"
  local output="$2"
  local retries=3
  local count=0

  until [ "$count" -ge "$retries" ]; do
    log_info "Baixando $url (Tentativa $((count+1))/$retries)..."
    if curl -fsSL "$url" -o "$output"; then
      return 0
    fi
    count=$((count+1))
    log_warn "Falha no download. Tentando novamente em 2 segundos..."
    sleep 2
  done
  log_fatal "Falha ao baixar $url após $retries tentativas."
}

# ------------------------------------------------------------------------------
# Fase 1: Preparação do Sistema e Ferramentas Básicas
# ------------------------------------------------------------------------------

phase_system_prep() {
  log_info "Iniciando atualização do sistema..."
  run_as_root apt-get update -y -qq
  
  log_info "Instalando dependências essenciais..."
  local basic_packages=(
    "bash"
    "coreutils"
    "git"
    "curl"
    "wget"
    "unzip"
    "zip"
    "tar"
    "xz-utils"
    "software-properties-common"
    "build-essential"
    "gcc"
    "g++"
    "make"
    "cmake"
    "ninja-build"
    "pkg-config"
    "autoconf"
    "libtool"
    "clang"
    "llvm"
    "lld"
    "gdb"
    "python3"
    "python3-pip"
    "libsdl2-dev"
    "libopenal-dev"
    "libfreetype6-dev"
    "libfontconfig1-dev"
    "libssl-dev"
    "zlib1g-dev"
  )

  for pkg in "${basic_packages[@]}"; do
    install_apt_package "$pkg"
  done
}

# ------------------------------------------------------------------------------
# Fase 2: Node.js 20 (NodeSource)
# ------------------------------------------------------------------------------

phase_nodejs() {
  log_info "Verificando instalação do Node.js..."
  
  local need_install=true
  if command -v node >/dev/null 2>&1; then
    local node_version
    node_version=$(node -v)
    if [[ "$node_version" == v20* ]]; then
      log_info "Node.js $node_version já está instalado."
      need_install=false
    fi
  fi

  if [ "$need_install" = true ]; then
    log_info "Configurando repositório NodeSource v20..."
    install_apt_package "ca-certificates"
    install_apt_package "gnupg"
    
    run_as_root mkdir -p /etc/apt/keyrings
    run_as_root rm -f /etc/apt/keyrings/nodesource.gpg
    
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
      run_as_root gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | \
      run_as_root tee /etc/apt/sources.list.d/nodesource.list >/dev/null
    
    run_as_root apt-get update -y -qq
    install_apt_package "nodejs"
  fi
}

# ------------------------------------------------------------------------------
# Fase 3: Java 17 (OpenJDK)
# ------------------------------------------------------------------------------

phase_java() {
  log_info "Configurando Java 17..."
  install_apt_package "openjdk-17-jdk"
  
  local javac_path
  javac_path=$(readlink -f "$(command -v javac)" 2>/dev/null || true)
  
  if [ -n "$javac_path" ]; then
    local java_home_dir
    java_home_dir=$(echo "$javac_path" | sed 's#/bin/javac##')
    log_info "JAVA_HOME detectado: $java_home_dir"
    
    append_to_profile "JAVA_HOME" "$java_home_dir"
    append_to_path "$java_home_dir/bin"
  else
    log_warn "Não foi possível detectar o caminho do javac automaticamente."
  fi
}

# ------------------------------------------------------------------------------
# Fase 4: .NET 8 SDK
# ------------------------------------------------------------------------------

phase_dotnet() {
  log_info "Verificando instalação do .NET 8..."
  
  if command -v dotnet >/dev/null 2>&1 && [[ "$(dotnet --version)" == 8.* ]]; then
    log_info ".NET 8 já está instalado."
  else
    log_info "Instalando .NET 8 via script de instalação oficial..."
    
    local install_script="/tmp/dotnet-install.sh"
    download_file "https://dot.net/v1/dotnet-install.sh" "$install_script"
    chmod +x "$install_script"
    
    run_as_user mkdir -p "$DOTNET_USER_DIR"
    run_as_user bash "$install_script" --channel 8.0 --install-dir "$DOTNET_USER_DIR"
    
    append_to_profile "DOTNET_ROOT" "$DOTNET_USER_DIR"
    append_to_path "$DOTNET_USER_DIR"
    append_to_path "$DOTNET_USER_DIR/tools"
    
    rm -f "$install_script"
  fi

  log_info "Verificando Workload Android para .NET..."
  if ! run_as_user "$DOTNET_USER_DIR/dotnet" workload list | grep -qi "android"; then
    log_info "Instalando Workload Android..."
    run_as_user "$DOTNET_USER_DIR/dotnet" workload install android --skip-manifest-update
  else
    log_info "Workload Android já instalado."
  fi
}

# ------------------------------------------------------------------------------
# Fase 5: Android SDK, NDK e CMake
# ------------------------------------------------------------------------------

phase_android_sdk() {
  log_info "Configurando Android SDK em: $ANDROID_SDK_DIR"
  
  run_as_user mkdir -p "$ANDROID_SDK_DIR/cmdline-tools"
  run_as_user mkdir -p "$ANDROID_SDK_DIR/platform-tools"
  run_as_user mkdir -p "$USER_HOME/.android"
  
  # Cria arquivo de repositórios para evitar avisos
  run_as_user touch "$USER_HOME/.android/repositories.cfg"

  # Instalação das Command Line Tools
  if [ ! -d "$ANDROID_SDK_DIR/cmdline-tools/latest" ]; then
    log_info "Baixando Android Command Line Tools..."
    local zip_path="/tmp/cmdline-tools.zip"
    download_file "$CMDLINE_TOOLS_URL" "$zip_path"
    
    local temp_extract="/tmp/cmdline-extract"
    mkdir -p "$temp_extract"
    unzip -q "$zip_path" -d "$temp_extract"
    
    run_as_user mkdir -p "$ANDROID_SDK_DIR/cmdline-tools/latest"
    
    # Move o conteúdo corretamente dependendo da estrutura do zip
    if [ -d "$temp_extract/cmdline-tools" ]; then
      run_as_user cp -r "$temp_extract/cmdline-tools/"* "$ANDROID_SDK_DIR/cmdline-tools/latest/"
    elif [ -d "$temp_extract/tools" ]; then
      run_as_user cp -r "$temp_extract/tools/"* "$ANDROID_SDK_DIR/cmdline-tools/latest/"
    else
      # Fallback genérico
      run_as_user cp -r "$temp_extract/"* "$ANDROID_SDK_DIR/cmdline-tools/latest/"
    fi
    
    rm -rf "$temp_extract"
    rm -f "$zip_path"
  fi

  # Variáveis de Ambiente Android
  append_to_profile "ANDROID_HOME" "$ANDROID_SDK_DIR"
  append_to_profile "ANDROID_SDK_ROOT" "$ANDROID_SDK_DIR"
  append_to_path "$ANDROID_SDK_DIR/cmdline-tools/latest/bin"
  append_to_path "$ANDROID_SDK_DIR/platform-tools"

  # Aceitação de Licenças via Hash (Método Otimizado)
  log_info "Escrevendo licenças do Android SDK..."
  run_as_user mkdir -p "$ANDROID_SDK_DIR/licenses"
  
  # Licença SDK principal
  echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" | run_as_user tee "$ANDROID_SDK_DIR/licenses/android-sdk-license" >/dev/null
  echo "84831b9409646a918e30573bab4c9c91346d8abd" | run_as_user tee -a "$ANDROID_SDK_DIR/licenses/android-sdk-license" >/dev/null
  
  # Outras licenças
  echo "601085b94cd77f0b54ff86406957099ebe79c4d6" | run_as_user tee "$ANDROID_SDK_DIR/licenses/android-googletv-license" >/dev/null
  echo "33b6a2b64607f11b759f320ef9dff4ae5c47d97a" | run_as_user tee "$ANDROID_SDK_DIR/licenses/google-gdk-license" >/dev/null
  echo "e9acab5b5fbb560a72cfaecce6eb5b36b1e850d9" | run_as_user tee "$ANDROID_SDK_DIR/licenses/mips-android-sysimage-license" >/dev/null

  # Instalação dos pacotes via sdkmanager
  local sdkmanager_bin="$ANDROID_SDK_DIR/cmdline-tools/latest/bin/sdkmanager"
  
  log_info "Instalando Plataforma, Build-Tools, NDK e CMake..."
  yes | run_as_user "$sdkmanager_bin" --install \
    "platform-tools" \
    "platforms;android-${ANDROID_API}" \
    "build-tools;${BUILD_TOOLS}" \
    "ndk;${NDK_VERSION}" \
    "cmake;${CMAKE_VERSION}" >/dev/null
}

# ------------------------------------------------------------------------------
# Fase 6: Mono e MonoGame
# ------------------------------------------------------------------------------

phase_monogame() {
  log_info "Instalando Mono Runtime e Compilador..."
  install_apt_package "mono-complete"
  
  log_info "Instalando templates do MonoGame e MGCB Editor..."
  run_as_user "$DOTNET_USER_DIR/dotnet" new install MonoGame.Templates.CSharp >/dev/null 2>&1 || true
  run_as_user "$DOTNET_USER_DIR/dotnet" tool install --global dotnet-mgcb-editor >/dev/null 2>&1 || true
}

# ------------------------------------------------------------------------------
# Fase 7: Docker
# ------------------------------------------------------------------------------

phase_docker() {
  log_info "Verificando instalação do Docker..."
  
  if ! command -v docker >/dev/null 2>&1; then
    log_info "Docker não encontrado. Instalando via script oficial..."
    local docker_script="/tmp/get-docker.sh"
    download_file "https://get.docker.com" "$docker_script"
    run_as_root sh "$docker_script"
    rm -f "$docker_script"
    
    # Adicionar usuário ao grupo docker
    if [ -n "${SUDO_USER:-}" ]; then
      log_info "Adicionando usuário $SUDO_USER ao grupo docker..."
      run_as_root usermod -aG docker "$SUDO_USER" || true
    fi
  else
    log_info "Docker já instalado."
  fi
}

# ------------------------------------------------------------------------------
# Fase 8: VS Code e Extensões
# ------------------------------------------------------------------------------

phase_vscode() {
  log_info "Verificando VS Code..."
  
  if ! command -v code >/dev/null 2>&1; then
    log_info "Instalando Visual Studio Code..."
    install_apt_package "wget"
    install_apt_package "gpg"
    install_apt_package "apt-transport-https"
    
    local key_ring="/etc/apt/keyrings/packages.microsoft.gpg"
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | run_as_root tee "$key_ring" >/dev/null
    
    echo "deb [arch=amd64,arm64,armhf signed-by=$key_ring] https://packages.microsoft.com/repos/code stable main" | \
      run_as_root tee /etc/apt/sources.list.d/vscode.list >/dev/null
    
    run_as_root apt-get update -y -qq
    install_apt_package "code"
  else
    log_info "VS Code já instalado."
  fi

  log_info "Iniciando instalação de 42 extensões do VS Code..."
  
  # Array contendo todas as extensões solicitadas
  local extensions=(
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

  local count=0
  local total=${#extensions[@]}
  local installed_list
  
  # Obtém lista de extensões já instaladas para otimizar
  if [ -n "${SUDO_USER:-}" ]; then
    installed_list=$(run_as_user code --list-extensions)
  else
    installed_list=$(code --list-extensions)
  fi
  
  # Converte para minúsculas para comparação insensível a caixa
  installed_list=$(echo "$installed_list" | tr '[:upper:]' '[:lower:]')

  for ext in "${extensions[@]}"; do
    count=$((count + 1))
    local ext_lower
    ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    
    if echo "$installed_list" | grep -q "$ext_lower"; then
      log_info "[$count/$total] Extensão já instalada: $ext"
    else
      log_info "[$count/$total] Instalando extensão: $ext..."
      # Instala como o usuário correto
      if [ -n "${SUDO_USER:-}" ]; then
        if sudo -u "$SUDO_USER" code --install-extension "$ext" --force >/dev/null 2>&1; then
           log_info "   -> Sucesso: $ext"
        else
           log_warn "   -> Falha ao instalar: $ext (Verifique compatibilidade ou ID)"
        fi
      else
        if code --install-extension "$ext" --force >/dev/null 2>&1; then
           log_info "   -> Sucesso: $ext"
        else
           log_warn "   -> Falha ao instalar: $ext"
        fi
      fi
    fi
  done
}

# ------------------------------------------------------------------------------
# Fase 9: Limpeza e Relatório Final
# ------------------------------------------------------------------------------

phase_cleanup() {
  log_info "Executando limpeza do apt..."
  run_as_root apt-get clean
  run_as_root rm -rf /var/lib/apt/lists/*
  run_as_root rm -rf /tmp/*dotnet* /tmp/*android*
}

phase_report() {
  log_info "Gerando relatório de versões..."
  
  echo ""
  echo "RELATÓRIO DE AMBIENTE INSTALADO"
  echo "Data: $(date)"
  echo ""
  
  echo "--- Sistema ---"
  echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"
  echo "Kernel: $(uname -r)"
  
  echo ""
  echo "--- Linguagens & Runtimes ---"
  echo "Java: $(java -version 2>&1 | head -n 1)"
  echo "Node.js: $(run_as_user node -v 2>/dev/null || echo 'Erro')"
  echo "NPM: $(run_as_user npm -v 2>/dev/null || echo 'Erro')"
  echo ".NET SDK: $(run_as_user "$DOTNET_USER_DIR/dotnet" --version 2>/dev/null || echo 'Erro')"
  echo "Mono: $(mono --version 2>/dev/null | head -n 1 || echo 'Não encontrado')"
  
  echo ""
  echo "--- Android ---"
  echo "SDK Root: $ANDROID_SDK_DIR"
  echo "ADB: $(run_as_user "$ANDROID_SDK_DIR/platform-tools/adb" version 2>/dev/null | head -n 1 || echo 'Erro')"
  echo "NDK Version: $NDK_VERSION"
  
  echo ""
  echo "--- Ferramentas ---"
  echo "Docker: $(docker --version 2>/dev/null || echo 'Não encontrado')"
  echo "Docker Compose: $(docker compose version 2>/dev/null || echo 'Não encontrado')"
  echo "VS Code: $(code --version 2>/dev/null | head -n 1 || echo 'Não encontrado')"
  
  echo ""
  echo "Instalação concluída com sucesso!"
  echo "Por favor, reinicie seu terminal ou execute 'source ~/.bashrc' para carregar as variáveis."
  echo "Se você instalou o Docker, pode ser necessário fazer logout/login para atualizar as permissões de grupo."
  echo ""
}

# ------------------------------------------------------------------------------
# Execução Principal
# ------------------------------------------------------------------------------

main() {
  log_info "Iniciando script de configuração do ambiente de desenvolvimento..."
  check_sudo
  
  # Sequência de execução das fases
  phase_system_prep
  phase_nodejs
  phase_java
  phase_dotnet
  phase_android_sdk
  phase_monogame
  phase_docker
  phase_vscode
  phase_cleanup
  phase_report
  
  log_info "Log completo salvo em: $LOG_FILE"
}

# Inicia o script
main "$@"
