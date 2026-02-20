#!/usr/bin/env bash
# Audit all OrrisTech org repos for compliance with org standards.
#
# Checks each repo for the presence of:
#   - CI workflow (.github/workflows/)
#   - PR template (.github/pull_request_template.md)
#   - Claude org rules (.claude/org-rules.md)
#   - Lefthook config (lefthook.yml)
#   - ESLint config (eslint.config.* or .eslintrc.*)
#   - Test config (vitest.config.* or jest.config.*)
#
# Usage:
#   ./audit-all-repos.sh           # Human-readable table
#   ./audit-all-repos.sh --json    # Machine-readable JSON output

set -euo pipefail

# ─── Parse flags ─────────────────────────────────────────────────────────────
JSON_OUTPUT=false
if [[ "${1:-}" == "--json" ]]; then
  JSON_OUTPUT=true
fi

# ─── Verify gh CLI is available ──────────────────────────────────────────────
if ! command -v gh &> /dev/null; then
  echo "Error: GitHub CLI (gh) is required but not installed." >&2
  echo "Install it from https://cli.github.com/" >&2
  exit 1
fi

# ─── Fetch all org repos ────────────────────────────────────────────────────
REPOS_JSON=$(gh repo list OrrisTech --limit 100 --json name,primaryLanguage --no-archived 2>/dev/null)

if [ -z "$REPOS_JSON" ] || [ "$REPOS_JSON" = "[]" ]; then
  echo "No repos found in OrrisTech org (or gh is not authenticated)." >&2
  exit 1
fi

# Extract repo names into an array
REPO_NAMES=($(echo "$REPOS_JSON" | jq -r '.[].name' | sort))
TOTAL=${#REPO_NAMES[@]}

# ─── Helper: check if a file/pattern exists in a repo's default branch ──────
# Uses gh api to check file existence without cloning
file_exists_in_repo() {
  local repo="$1"
  local path="$2"
  gh api "repos/OrrisTech/$repo/contents/$path" --silent 2>/dev/null && return 0
  return 1
}

# Check if any file matching a prefix exists (for glob-like checks)
any_file_with_prefix() {
  local repo="$1"
  local dir="$2"
  # List directory contents; if it returns successfully, the directory has files
  gh api "repos/OrrisTech/$repo/contents/$dir" --silent 2>/dev/null && return 0
  return 1
}

# ─── Audit each repo ────────────────────────────────────────────────────────
declare -a RESULTS=()
PASS_COUNT=0
TOTAL_CHECKS=0

# Track per-check totals for the summary
CI_PASS=0
PR_PASS=0
CLAUDE_PASS=0
LEFTHOOK_PASS=0
ESLINT_PASS=0
TEST_PASS=0

for REPO in "${REPO_NAMES[@]}"; do
  # Check each standard
  HAS_CI="no"
  HAS_PR_TEMPLATE="no"
  HAS_CLAUDE_RULES="no"
  HAS_LEFTHOOK="no"
  HAS_ESLINT="no"
  HAS_TESTS="no"

  # CI workflow: check if .github/workflows directory has any files
  if any_file_with_prefix "$REPO" ".github/workflows"; then
    HAS_CI="yes"
    ((CI_PASS++)) || true
  fi

  # PR template
  if file_exists_in_repo "$REPO" ".github/pull_request_template.md"; then
    HAS_PR_TEMPLATE="yes"
    ((PR_PASS++)) || true
  fi

  # Claude org rules
  if file_exists_in_repo "$REPO" ".claude/org-rules.md"; then
    HAS_CLAUDE_RULES="yes"
    ((CLAUDE_PASS++)) || true
  fi

  # Lefthook
  if file_exists_in_repo "$REPO" "lefthook.yml"; then
    HAS_LEFTHOOK="yes"
    ((LEFTHOOK_PASS++)) || true
  fi

  # ESLint config (check common filenames)
  if file_exists_in_repo "$REPO" "eslint.config.mjs" || \
     file_exists_in_repo "$REPO" "eslint.config.js" || \
     file_exists_in_repo "$REPO" "eslint.config.ts" || \
     file_exists_in_repo "$REPO" ".eslintrc.json" || \
     file_exists_in_repo "$REPO" ".eslintrc.js" || \
     file_exists_in_repo "$REPO" ".eslintrc.yml"; then
    HAS_ESLINT="yes"
    ((ESLINT_PASS++)) || true
  fi

  # Test config (vitest or jest)
  if file_exists_in_repo "$REPO" "vitest.config.ts" || \
     file_exists_in_repo "$REPO" "vitest.config.js" || \
     file_exists_in_repo "$REPO" "vitest.config.mts" || \
     file_exists_in_repo "$REPO" "jest.config.ts" || \
     file_exists_in_repo "$REPO" "jest.config.js" || \
     file_exists_in_repo "$REPO" "jest.config.json"; then
    HAS_TESTS="yes"
    ((TEST_PASS++)) || true
  fi

  # Count passes for this repo
  REPO_PASS=0
  for check in "$HAS_CI" "$HAS_PR_TEMPLATE" "$HAS_CLAUDE_RULES" "$HAS_LEFTHOOK" "$HAS_ESLINT" "$HAS_TESTS"; do
    if [ "$check" = "yes" ]; then
      ((REPO_PASS++)) || true
    fi
  done
  PASS_COUNT=$((PASS_COUNT + REPO_PASS))
  TOTAL_CHECKS=$((TOTAL_CHECKS + 6))

  RESULTS+=("$REPO|$HAS_CI|$HAS_PR_TEMPLATE|$HAS_CLAUDE_RULES|$HAS_LEFTHOOK|$HAS_ESLINT|$HAS_TESTS|$REPO_PASS")
done

# ─── Output: JSON mode ──────────────────────────────────────────────────────
if $JSON_OUTPUT; then
  echo "{"
  echo "  \"audit_date\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"total_repos\": $TOTAL,"
  echo "  \"overall_compliance\": \"$((PASS_COUNT * 100 / TOTAL_CHECKS))%\","
  echo "  \"summary\": {"
  echo "    \"ci_workflow\": { \"pass\": $CI_PASS, \"total\": $TOTAL },"
  echo "    \"pr_template\": { \"pass\": $PR_PASS, \"total\": $TOTAL },"
  echo "    \"claude_rules\": { \"pass\": $CLAUDE_PASS, \"total\": $TOTAL },"
  echo "    \"lefthook\": { \"pass\": $LEFTHOOK_PASS, \"total\": $TOTAL },"
  echo "    \"eslint\": { \"pass\": $ESLINT_PASS, \"total\": $TOTAL },"
  echo "    \"test_config\": { \"pass\": $TEST_PASS, \"total\": $TOTAL }"
  echo "  },"
  echo "  \"repos\": ["

  for i in "${!RESULTS[@]}"; do
    IFS='|' read -r name ci pr claude lefthook eslint tests score <<< "${RESULTS[$i]}"
    COMMA=""
    if [ "$i" -lt $((${#RESULTS[@]} - 1)) ]; then
      COMMA=","
    fi
    echo "    {"
    echo "      \"name\": \"$name\","
    echo "      \"ci_workflow\": $([ "$ci" = "yes" ] && echo "true" || echo "false"),"
    echo "      \"pr_template\": $([ "$pr" = "yes" ] && echo "true" || echo "false"),"
    echo "      \"claude_rules\": $([ "$claude" = "yes" ] && echo "true" || echo "false"),"
    echo "      \"lefthook\": $([ "$lefthook" = "yes" ] && echo "true" || echo "false"),"
    echo "      \"eslint\": $([ "$eslint" = "yes" ] && echo "true" || echo "false"),"
    echo "      \"test_config\": $([ "$tests" = "yes" ] && echo "true" || echo "false"),"
    echo "      \"score\": \"$score/6\""
    echo "    }$COMMA"
  done

  echo "  ]"
  echo "}"
  exit 0
fi

# ─── Output: Human-readable table ───────────────────────────────────────────
CHECKMARK="Y"
CROSS="N"

echo ""
echo "OrrisTech Org Standards Compliance Report"
echo "=========================================="
echo "Date: $(date '+%Y-%m-%d %H:%M')"
echo "Repos audited: $TOTAL"
echo ""

# Print table header
printf "%-25s %-6s %-6s %-8s %-10s %-8s %-7s %-7s\n" \
  "Repository" "CI" "PR" "Claude" "Lefthook" "ESLint" "Tests" "Score"
printf "%-25s %-6s %-6s %-8s %-10s %-8s %-7s %-7s\n" \
  "-------------------------" "------" "------" "--------" "----------" "--------" "-------" "-------"

for result in "${RESULTS[@]}"; do
  IFS='|' read -r name ci pr claude lefthook eslint tests score <<< "$result"

  # Convert yes/no to checkmark/cross
  ci_mark=$([ "$ci" = "yes" ] && echo "$CHECKMARK" || echo "$CROSS")
  pr_mark=$([ "$pr" = "yes" ] && echo "$CHECKMARK" || echo "$CROSS")
  claude_mark=$([ "$claude" = "yes" ] && echo "$CHECKMARK" || echo "$CROSS")
  lefthook_mark=$([ "$lefthook" = "yes" ] && echo "$CHECKMARK" || echo "$CROSS")
  eslint_mark=$([ "$eslint" = "yes" ] && echo "$CHECKMARK" || echo "$CROSS")
  tests_mark=$([ "$tests" = "yes" ] && echo "$CHECKMARK" || echo "$CROSS")

  printf "%-25s %-6s %-6s %-8s %-10s %-8s %-7s %-7s\n" \
    "$name" "$ci_mark" "$pr_mark" "$claude_mark" "$lefthook_mark" "$eslint_mark" "$tests_mark" "$score/6"
done

echo ""
echo "──────────────────────────────────────────"
echo "Per-check compliance:"
echo "  CI workflow:    $CI_PASS/$TOTAL repos"
echo "  PR template:    $PR_PASS/$TOTAL repos"
echo "  Claude rules:   $CLAUDE_PASS/$TOTAL repos"
echo "  Lefthook:       $LEFTHOOK_PASS/$TOTAL repos"
echo "  ESLint:         $ESLINT_PASS/$TOTAL repos"
echo "  Test config:    $TEST_PASS/$TOTAL repos"
echo ""
echo "Overall compliance: $PASS_COUNT/$TOTAL_CHECKS checks ($((PASS_COUNT * 100 / TOTAL_CHECKS))%)"
echo ""
