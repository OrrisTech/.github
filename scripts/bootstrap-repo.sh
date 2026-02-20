#!/usr/bin/env bash
# Bootstrap a new or existing repo with OrrisTech org standards.
#
# This script copies sync files, installs dev dependencies, sets up lefthook,
# and configures the repo to follow org conventions.
#
# Usage:
#   ./bootstrap-repo.sh <path-to-repo>
#
# Example:
#   ./bootstrap-repo.sh ~/Dev/my-new-project

set -euo pipefail

# ─── Color helpers ───────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No color

info()    { echo -e "${BLUE}[info]${NC} $*"; }
success() { echo -e "${GREEN}[done]${NC} $*"; }
warn()    { echo -e "${YELLOW}[warn]${NC} $*"; }
error()   { echo -e "${RED}[error]${NC} $*" >&2; }

# ─── Validate arguments ─────────────────────────────────────────────────────
if [ -z "${1:-}" ]; then
  error "Usage: $0 <path-to-repo>"
  exit 1
fi

REPO_DIR="$(cd "$1" && pwd)"
REPO_NAME="$(basename "$REPO_DIR")"

# Resolve the path to this script's parent (the .github org repo root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORG_REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

info "Bootstrapping repo: $REPO_NAME ($REPO_DIR)"
echo ""

# ─── Verify the org repo has the required sync files ────────────────────────
SYNC_DIR="$ORG_REPO_DIR/sync"
if [ ! -d "$SYNC_DIR" ]; then
  error "Sync directory not found at $SYNC_DIR"
  error "Make sure the orristech-github-org repo is cloned and up to date."
  exit 1
fi

# ─── Verify target is a git repo ────────────────────────────────────────────
if [ ! -d "$REPO_DIR/.git" ]; then
  warn "Target directory is not a git repo. Initializing git..."
  git -C "$REPO_DIR" init
fi

# ─── Copy sync files ────────────────────────────────────────────────────────
info "Copying org sync files..."

# Create directories that may not exist yet
mkdir -p "$REPO_DIR/.claude"
mkdir -p "$REPO_DIR/.github"
mkdir -p "$REPO_DIR/.vscode"

# Copy each sync file if it exists in the org repo
copy_if_exists() {
  local src="$SYNC_DIR/$1"
  local dest="$REPO_DIR/$1"
  if [ -f "$src" ]; then
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    success "  Copied $1"
  else
    warn "  Skipping $1 (not found in sync/)"
  fi
}

copy_if_exists ".claude/org-rules.md"
copy_if_exists ".github/pull_request_template.md"
copy_if_exists ".github/workflows/ci.yml"
copy_if_exists "lefthook.yml"
copy_if_exists ".vscode/settings.json"

echo ""

# ─── Copy templates ─────────────────────────────────────────────────────────
TEMPLATES_DIR="$ORG_REPO_DIR/templates"

# Copy CLAUDE.md template if no CLAUDE.md exists in the repo
if [ ! -f "$REPO_DIR/CLAUDE.md" ] && [ -f "$TEMPLATES_DIR/CLAUDE.md.full" ]; then
  info "Copying CLAUDE.md template..."
  cp "$TEMPLATES_DIR/CLAUDE.md.full" "$REPO_DIR/CLAUDE.md"
  success "  Created CLAUDE.md (edit to customize for your project)"
fi

echo ""

# ─── Detect package manager ─────────────────────────────────────────────────
source "$SCRIPT_DIR/detect-pkg-manager.sh" "$REPO_DIR"
info "Detected package manager: $PKG_MANAGER"

# ─── Check for package.json ─────────────────────────────────────────────────
if [ ! -f "$REPO_DIR/package.json" ]; then
  warn "No package.json found. Skipping dependency installation."
  warn "Run '$PKG_MANAGER init' in the repo first, then re-run this script."
else
  # ─── Install dev dependencies ──────────────────────────────────────────
  info "Installing dev dependencies..."

  DEV_DEPS=(
    "eslint"
    "vitest"
    "@vitest/coverage-v8"
    "lefthook"
    "typescript"
  )

  cd "$REPO_DIR"

  case "$PKG_MANAGER" in
    pnpm)
      pnpm add -D "${DEV_DEPS[@]}"
      ;;
    bun)
      bun add -D "${DEV_DEPS[@]}"
      ;;
    yarn)
      yarn add -D "${DEV_DEPS[@]}"
      ;;
    npm)
      npm install -D "${DEV_DEPS[@]}"
      ;;
  esac

  success "Dev dependencies installed"
  echo ""

  # ─── Initialize lefthook ───────────────────────────────────────────────
  if [ -f "$REPO_DIR/lefthook.yml" ]; then
    info "Initializing lefthook..."
    cd "$REPO_DIR"
    npx lefthook install
    success "Lefthook initialized"
  fi
fi

echo ""

# ─── Create initial commit (if repo is fresh) ───────────────────────────────
cd "$REPO_DIR"
COMMIT_COUNT=$(git rev-list --count HEAD 2>/dev/null || echo "0")

if [ "$COMMIT_COUNT" = "0" ]; then
  info "Creating initial commit..."
  git add -A
  git commit -m "chore: bootstrap repo with OrrisTech org standards"
  success "Initial commit created"
else
  info "Repo already has commits. Skipping initial commit."
  info "Stage and commit the new files manually when ready."
fi

echo ""

# ─── Summary ─────────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}Bootstrap complete for ${REPO_NAME}${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "What was set up:"
echo "  - .claude/org-rules.md      (org coding standards)"
echo "  - .github/pull_request_template.md"
echo "  - .github/workflows/ci.yml  (CI pipeline)"
echo "  - lefthook.yml              (git hooks)"
echo "  - .vscode/settings.json     (editor config)"
echo "  - CLAUDE.md                 (AI assistant config)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${YELLOW}Manual steps required:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  1. Edit CLAUDE.md to customize for your project"
echo "  2. Add your ESLint config (eslint.config.mjs) if not present"
echo "  3. Add vitest.config.ts if not present"
echo "  4. Update .github/workflows/ci.yml if your project needs"
echo "     custom CI steps (e.g., database, environment variables)"
echo "  5. Set up branch protection rules on GitHub:"
echo "     - Require PR reviews before merging"
echo "     - Require CI checks to pass"
echo "  6. Add the repo to sync-config.yml in the .github org repo"
echo "     to receive future org standard updates automatically"
echo ""
