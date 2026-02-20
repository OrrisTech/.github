# OrrisTech `.github` Repository

Central configuration repository for the **OrrisTech** GitHub organization. This repo contains shared workflows, sync files, templates, scripts, and org-wide standards that are distributed to all OrrisTech repositories.

## Directory Structure

```
.github/
  workflows/
    sync-files.yml          # Workflow that syncs files to all org repos
    ci-build.yml            # Reusable CI workflow: production build
    ci-dead-links.yml       # Reusable CI workflow: broken link check
    ci-e2e.yml              # Reusable CI workflow: Playwright e2e tests
    ci-lint-typecheck.yml   # Reusable CI workflow: ESLint + TypeScript
    ci-react-doctor.yml     # Reusable CI workflow: React Doctor checks
    ci-security.yml         # Reusable CI workflow: dependency audit
    ci-seo-lighthouse.yml   # Reusable CI workflow: Lighthouse CI
    ci-test.yml             # Reusable CI workflow: Vitest unit tests
sync/
  .claude/org-rules.md    # Org coding standards for Claude AI
  .github/
    pull_request_template.md
    workflows/ci.yml      # Standard CI pipeline (calls reusable workflows)
  lefthook.yml            # Git hooks configuration
  .vscode/settings.json   # Shared VS Code settings
templates/
  CLAUDE.md.full          # Full CLAUDE.md template for new projects
scripts/
  detect-pkg-manager.sh   # Detect pnpm/bun/yarn/npm from lock files
  bootstrap-repo.sh       # Set up a new repo with all org standards
  audit-all-repos.sh      # Audit compliance across all org repos
profile/
  README.md               # Organization profile (shown on GitHub org page)
sync-config.yml           # Configuration for BetaHuhn/repo-file-sync-action
```

## How Reusable Workflows Work

The `.github/workflows/` directory contains reusable CI workflows that individual repos call via `workflow_call`. This keeps CI logic centralized and consistent.

Each repo has a thin `ci.yml` (synced from `sync/.github/workflows/ci.yml`) that calls the reusable workflows:

```yaml
# In any OrrisTech repo: .github/workflows/ci.yml
jobs:
  lint:
    uses: OrrisTech/.github/.github/workflows/ci-lint-typecheck.yml@main
  test:
    uses: OrrisTech/.github/.github/workflows/ci-test.yml@main
  build:
    uses: OrrisTech/.github/.github/workflows/ci-build.yml@main
```

All reusable workflows auto-detect the package manager (pnpm, bun, yarn, or npm) from lock files.

## How File Sync Works

The [BetaHuhn/repo-file-sync-action](https://github.com/BetaHuhn/repo-file-sync-action) automatically syncs files from `sync/` to all configured repos.

**Trigger conditions:**
- Push to `sync/` directory or `sync-config.yml` on `main`
- Weekly schedule (Sundays at 09:00 UTC)
- Manual dispatch from Actions tab

**What happens:**
1. The workflow reads `sync-config.yml` to determine which files go to which repos.
2. For each repo, it opens a PR with any changed files.
3. PRs are labeled `sync` and `automated` for easy filtering.

### Adding a New Repo to Sync

1. Open `sync-config.yml`
2. Add the repo name under the appropriate group's `repos:` key:
   ```yaml
   repos: |
     OrrisTech/seomate
     OrrisTech/clawdgo
     OrrisTech/adwhiz-landing
     OrrisTech/your-new-repo    # <-- add here
   ```
3. Commit and push to `main`. The sync workflow will run and open a PR in the new repo.

## Bootstrapping a New Repo

For repos that need immediate setup (without waiting for the sync workflow):

```bash
# Clone this repo if you haven't already
git clone https://github.com/OrrisTech/.github.git orristech-github-org

# Run the bootstrap script
./orristech-github-org/scripts/bootstrap-repo.sh ~/Dev/your-new-repo
```

The bootstrap script will:
- Copy all sync files to the repo
- Install dev dependencies (ESLint, Vitest, Lefthook, TypeScript)
- Initialize Lefthook git hooks
- Create an initial commit (if the repo is fresh)
- Print a list of manual steps to complete

## Running the Audit

Check compliance across all OrrisTech repos:

```bash
# Human-readable table
./scripts/audit-all-repos.sh

# Machine-readable JSON
./scripts/audit-all-repos.sh --json
```

Requires the [GitHub CLI](https://cli.github.com/) (`gh`) to be installed and authenticated.

## Manual Configuration Required

These settings cannot be automated via file sync and must be configured manually:

### 1. GitHub Personal Access Token (PAT)

The sync workflow needs a PAT stored as `ORG_SYNC_PAT` in this repo's secrets.

Create a fine-grained PAT with these permissions for the OrrisTech org:
- **Contents**: Read and write
- **Pull requests**: Read and write

### 2. Organization Settings

In [OrrisTech org settings](https://github.com/organizations/OrrisTech/settings):
- Enable "Members can create public/private repositories"
- Configure default repository permissions as needed

### 3. Branch Protection Rules

For each repo, configure branch protection on `main`:
- Require pull request reviews (1 reviewer minimum)
- Require status checks to pass (CI workflow)
- Require branches to be up to date before merging

### 4. Reusable Workflow Access

In this repo's settings, under **Actions > General > Access**, set:
- "Accessible from repositories in the OrrisTech organization"

This allows other repos to call the reusable workflows in `.github/workflows/`.

## Related Documentation

- [GitHub Reusable Workflows](https://docs.github.com/en/actions/sharing-automations/reusing-workflows)
- [BetaHuhn/repo-file-sync-action](https://github.com/BetaHuhn/repo-file-sync-action)
- [Lefthook](https://github.com/evilmartians/lefthook)
- [Vitest](https://vitest.dev/)
- [Playwright](https://playwright.dev/)
