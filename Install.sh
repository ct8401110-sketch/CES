#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Instala extensões do VS Code em GitHub Codespaces (robusto)
# - Pula extensões já instaladas
# - Tenta instalar versão exata
# - Fallback: instala última versão
# - Log completo
# ============================================================

LOG_DIR="./logs"
mkdir -p "$LOG_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/extensions_install_${TS}.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "[INFO] Iniciando instalação de extensões..."
echo "[INFO] Log: $LOG_FILE"

# ------------------------------------------------------------
# Detectar VS Code CLI
# ------------------------------------------------------------
if command -v code >/dev/null 2>&1; then
  CODE_BIN="code"
elif command -v code-server >/dev/null 2>&1; then
  CODE_BIN="code-server"
else
  echo "[ERRO] Não encontrei 'code' nem 'code-server' no PATH."
  echo "       No Codespaces normalmente existe 'code'."
  exit 1
fi

echo "[INFO] Usando binário: $CODE_BIN"

# ------------------------------------------------------------
# Instalar jq se faltar (para parse opcional futuro)
# ------------------------------------------------------------
if ! command -v jq >/dev/null 2>&1; then
  echo "[WARN] jq não encontrado. Instalando..."
  if command -v sudo >/dev/null 2>&1; then
    sudo apt-get update -y
    sudo apt-get install -y jq
  else
    echo "[WARN] sudo não disponível; pulando instalação do jq."
  fi
fi

# ------------------------------------------------------------
# Extensões (ID + versão)
# ------------------------------------------------------------
EXTS=(
  "13xforever.language-x86-64-assembly@3.1.5"
  "adelphes.android-dev-ext@1.4.0"
  "adetoola.zip-files@0.0.2"
  "bbenoist.doxygen@1.0.0"
  "cheshirekow.cmake-format@0.6.11"
  "cschlosser.doxdocgen@1.4.0"
  "danielpinto8zz6.c-cpp-project-generator@1.2.20"
  "dart-code.dart-code@3.126.0"
  "dart-code.flutter@3.126.0"
  "diemasmichiels.emulate@1.8.1"
  "dr-mohammed-hamed.android-studio-flash@0.2.0"
  "eamodio.gitlens@17.9.0"
  "editorconfig.editorconfig@0.18.1"
  "franneck94.c-cpp-runner@9.5.0"
  "franneck94.vscode-c-cpp-config@6.3.0"
  "franneck94.vscode-c-cpp-dev-extension-pack@0.10.0"
  "github.codespaces@1.18.5"
  "github.copilot@1.388.0"
  "github.copilot-chat@0.36.2"
  "github.github-vscode-theme@6.3.5"
  "github.vscode-pull-request-github@0.126.0"
  "haloscript.astyle-lsp-vscode@0.0.1"
  "hanwang.android-adb-wlan@0.0.10"
  "jeff-hykin.better-cpp-syntax@1.27.1"
  "jnoortheen.nix-ide@0.5.5"
  "kelvin.vscode-sshfs@1.26.1"
  "kylinideteam.cmake-intellisence@0.4.0"
  "kylinideteam.cppdebug@0.2.0"
  "kylinideteam.kylin-clangd@0.5.0"
  "kylinideteam.kylin-cmake-tools@0.0.4"
  "kylinideteam.kylin-cpp-pack@0.1.0"
  "llvm-vs-code-extensions.vscode-clangd@0.4.0"
  "lonedev.ia-vscode@0.2.37"
  "mitaki28.vscode-clang@0.2.4"
  "ms-ceintl.vscode-language-pack-pt-br@1.108.2026012809"
  "ms-dotnettools.csdevkit@1.90.2"
  "ms-dotnettools.csharp@2.110.4"
  "ms-dotnettools.vscode-dotnet-runtime@3.0.0"
  "ms-python.debugpy@2025.18.0"
  "ms-python.python@2026.0.0"
  "ms-python.vscode-pylance@2025.10.4"
  "ms-python.vscode-python-envs@1.16.0"
  "ms-vscode.cmake-tools@1.22.26"
  "ms-vscode.cpptools@1.30.2"
  "ms-vscode.cpptools-extension-pack@1.3.1"
  "ms-vscode.cpptools-themes@2.0.0"
  "november.clover-unity@1.0.2"
  "oracle.oracle-java@25.0.1"
  "redhat.java@1.51.0"
  "redhat.vscode-yaml@1.19.1"
  "soumyaprasadrana.vscode-java-debugx@1.0.3"
  "tomashubelbauer.zip-file-system@2.0.0"
  "tstark.ia-gptcode@1.0.0"
  "twxs.cmake@0.0.17"
  "vadimcn.vscode-lldb@1.11.0"
)

# ------------------------------------------------------------
# Funções
# ------------------------------------------------------------
list_installed() {
  "$CODE_BIN" --list-extensions 2>/dev/null || true
}

is_installed() {
  local id="$1"
  list_installed | grep -qx "$id"
}

install_ext_exact() {
  local extver="$1"
  echo "[INFO] Tentando instalar: $extver"
  "$CODE_BIN" --install-extension "$extver" --force
}

install_ext_latest() {
  local id="$1"
  echo "[INFO] Tentando fallback (última versão): $id"
  "$CODE_BIN" --install-extension "$id" --force
}

# ------------------------------------------------------------
# Execução
# ------------------------------------------------------------
INSTALLED_BEFORE="$LOG_DIR/installed_before_${TS}.txt"
INSTALLED_AFTER="$LOG_DIR/installed_after_${TS}.txt"
FAILED_LIST="$LOG_DIR/failed_${TS}.txt"
SUCCESS_LIST="$LOG_DIR/success_${TS}.txt"

list_installed | sort > "$INSTALLED_BEFORE"

total="${#EXTS[@]}"
ok=0
skip=0
fail=0

for extver in "${EXTS[@]}"; do
  id="${extver%@*}"
  ver="${extver#*@}"

  echo "------------------------------------------------------------"
  echo "[INFO] Extensão: $id | Versão: $ver"

  if is_installed "$id"; then
    echo "[SKIP] Já instalada: $id"
    echo "$id@already_installed" >> "$SUCCESS_LIST"
    ((skip++)) || true
    continue
  fi

  # tenta versão exata
  if install_ext_exact "$extver"; then
    echo "[OK] Instalado (versão exata): $extver"
    echo "$extver" >> "$SUCCESS_LIST"
    ((ok++)) || true
    continue
  fi

  # fallback: última versão
  if install_ext_latest "$id"; then
    echo "[OK] Instalado (fallback latest): $id"
    echo "$id@latest" >> "$SUCCESS_LIST"
    ((ok++)) || true
    continue
  fi

  echo "[FAIL] Falhou instalar: $extver"
  echo "$extver" >> "$FAILED_LIST"
  ((fail++)) || true
done

list_installed | sort > "$INSTALLED_AFTER"

echo "============================================================"
echo "[DONE] Finalizado."
echo "[INFO] Total: $total"
echo "[INFO] OK: $ok"
echo "[INFO] SKIP: $skip"
echo "[INFO] FAIL: $fail"
echo "[INFO] Logs:"
echo "  - $INSTALLED_BEFORE"
echo "  - $INSTALLED_AFTER"
echo "  - $SUCCESS_LIST"
echo "  - $FAILED_LIST"
echo "  - $LOG_FILE"
echo "============================================================"
