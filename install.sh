#!/usr/bin/env bash
set -euo pipefail

DOTFILESDIR="(cd−−"(dirname -- "${BASHSOURCE[0]}")" && pwd)"

echo "==> Setting up torii-dotfiles"

"$DOTFILES_DIR/packages/install.sh"

echo "==> Setup complete"

