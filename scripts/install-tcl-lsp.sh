#!/usr/bin/env sh
# Install bitwisecook/tcl-lsp (Tcl language server) as a self-contained zipapp.
#
# Reproducible on macOS and Linux: downloads a pinned release .pyz, verifies its
# SHA-256, and places it at a machine-independent path under Neovim's data dir
# where init.lua expects it (stdpath('data')/tcl-lsp/tcl-lsp-server.pyz).
#
# Usage:
#   sh scripts/install-tcl-lsp.sh              # install the pinned version
#   TCL_LSP_VERSION=v1.12.0 sh scripts/install-tcl-lsp.sh   # override version
set -eu

TCL_LSP_VERSION="${TCL_LSP_VERSION:-v1.11.4}"
REPO="bitwisecook/tcl-lsp"

VER_NUM="${TCL_LSP_VERSION#v}"
ASSET="tcl-lsp-server-${VER_NUM}.pyz"   # the LSP server (NOT the tcl-*.pyz CLI toolchain)
BASE="https://github.com/${REPO}/releases/download/${TCL_LSP_VERSION}"

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/tcl-lsp"
DEST="${DATA_DIR}/tcl-lsp-server.pyz"

# --- prerequisites ---------------------------------------------------------
command -v curl >/dev/null 2>&1 || { echo "error: curl not found"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "error: python3 not found (need >= 3.10)"; exit 1; }
python3 - <<'PY' || { echo "error: need Python >= 3.10"; exit 1; }
import sys
sys.exit(0 if sys.version_info >= (3, 10) else 1)
PY

if command -v sha256sum >/dev/null 2>&1; then
  SHA_CMD="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
  SHA_CMD="shasum -a 256"
else
  echo "error: no sha256 tool (need sha256sum or shasum)"; exit 1
fi

# --- download + verify -----------------------------------------------------
mkdir -p "$DATA_DIR"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading ${ASSET} (${TCL_LSP_VERSION})..."
curl -fsSL "${BASE}/${ASSET}"      -o "${TMP}/${ASSET}"
curl -fsSL "${BASE}/SHA256SUMS"    -o "${TMP}/SHA256SUMS"

echo "Verifying SHA-256..."
EXPECTED="$(awk -v f="$ASSET" '{n=$2; sub(/^\*/,"",n); if (n==f) print $1}' "${TMP}/SHA256SUMS")"
[ -n "$EXPECTED" ] || { echo "error: ${ASSET} not listed in SHA256SUMS"; exit 1; }
ACTUAL="$(cd "$TMP" && $SHA_CMD "${ASSET}" | awk '{print $1}')"
if [ "$EXPECTED" != "$ACTUAL" ]; then
  echo "error: checksum mismatch"
  echo "  expected: $EXPECTED"
  echo "  actual:   $ACTUAL"
  exit 1
fi

mv "${TMP}/${ASSET}" "$DEST"
echo "Installed tcl-lsp -> $DEST"
echo "Done. Restart Neovim; open a .tcl file to attach the server."
