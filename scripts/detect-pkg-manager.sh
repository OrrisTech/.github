#!/usr/bin/env bash
# Detect the package manager used in a project by checking lock files.
# Can be executed directly or sourced by other scripts.
#
# Usage (direct):
#   ./detect-pkg-manager.sh [project_dir]
#
# Usage (sourced):
#   source ./detect-pkg-manager.sh [project_dir]
#   echo "$PKG_MANAGER"       # pnpm | bun | yarn | npm
#   echo "$PKG_INSTALL_CMD"   # pnpm install | bun install | yarn install | npm install
#   echo "$PKG_RUN_CMD"       # pnpm | bunx | yarn | npx
#   echo "$PKG_EXEC_CMD"      # pnpm exec | bunx | yarn exec | npx

set -euo pipefail

# Allow specifying a target directory; defaults to current working directory
TARGET_DIR="${1:-.}"

# Resolve to absolute path for consistency
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

# --- Detection logic ---
if [ -f "$TARGET_DIR/pnpm-lock.yaml" ]; then
  PKG_MANAGER="pnpm"
  PKG_INSTALL_CMD="pnpm install"
  PKG_RUN_CMD="pnpm"
  PKG_EXEC_CMD="pnpm exec"
  PKG_CI_CMD="pnpm install --frozen-lockfile"
elif [ -f "$TARGET_DIR/bun.lockb" ] || [ -f "$TARGET_DIR/bun.lock" ]; then
  PKG_MANAGER="bun"
  PKG_INSTALL_CMD="bun install"
  PKG_RUN_CMD="bunx"
  PKG_EXEC_CMD="bunx"
  PKG_CI_CMD="bun install --frozen-lockfile"
elif [ -f "$TARGET_DIR/yarn.lock" ]; then
  PKG_MANAGER="yarn"
  PKG_INSTALL_CMD="yarn install"
  PKG_RUN_CMD="yarn"
  PKG_EXEC_CMD="yarn exec"
  PKG_CI_CMD="yarn install --frozen-lockfile"
else
  PKG_MANAGER="npm"
  PKG_INSTALL_CMD="npm install"
  PKG_RUN_CMD="npx"
  PKG_EXEC_CMD="npx"
  PKG_CI_CMD="npm ci"
fi

# Export for use by sourcing scripts
export PKG_MANAGER PKG_INSTALL_CMD PKG_RUN_CMD PKG_EXEC_CMD PKG_CI_CMD

# When run directly (not sourced), print the detected package manager
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "$PKG_MANAGER"
fi
