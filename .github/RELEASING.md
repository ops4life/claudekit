# Release Process

This document describes the automated release process for claudekit.

## Overview

Releases are **fully automated** using GitHub Actions. When changes are merged to the `main` branch, the release workflow:

1. ✅ Validates plugin configuration
2. 🔍 Analyzes commits using conventional commit format
3. 📦 Determines version bump (major/minor/patch)
4. 📝 Generates changelog
5. 🏷️ Creates git tag
6. 🚀 Publishes GitHub release

## Conventional Commits

The release system uses [Conventional Commits](https://www.conventionalcommits.org/) to automatically determine version bumps.

### Commit Format

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Commit Types and Version Bumps

| Type | Version Bump | Example |
|------|-------------|---------|
| `feat:` | **MINOR** | `feat(k8s): add new deployment validation` |
| `fix:` | **PATCH** | `fix(terraform): correct cost calculation` |
| `perf:` | **PATCH** | `perf(cicd): optimize pipeline execution` |
| `BREAKING CHANGE:` | **MAJOR** | `feat!: redesign command structure` |
| `docs:` | None | `docs: update installation guide` |
| `chore:` | None | `chore: update dependencies` |
| `refactor:` | None | `refactor: simplify validation logic` |

### Examples

**Minor version bump (new feature):**
```bash
git commit -m "feat(observability): add SLO calculator command

Add new command to help teams calculate SLO targets and error budgets
based on availability requirements and traffic patterns."
```

**Patch version bump (bug fix):**
```bash
git commit -m "fix(k8s): handle empty namespace in validation

Fixes issue where validation would fail when namespace is not specified
in manifest files."
```

**Major version bump (breaking change):**
```bash
git commit -m "feat(cicd)!: redesign pipeline command structure

BREAKING CHANGE: Pipeline commands now require explicit stage definitions.
Users must update existing pipeline configurations to use the new format."
```

**No version bump:**
```bash
git commit -m "docs: update README with new examples"
git commit -m "chore: update GitHub Actions workflow"
```

## Release Workflow

### Automatic Process (Recommended)

1. **Develop on feature branch:**
   ```bash
   git checkout -b feature/add-new-command
   # Make changes
   git add .
   git commit -m "feat(k8s): add rollback command"
   ```

2. **Create pull request:**
   - Open PR from your feature branch to `main`
   - PR will be reviewed and merged

3. **Automatic release on merge:**
   - When PR is merged to `main`, GitHub Actions automatically:
     - Analyzes commits
     - Determines version bump
     - Generates changelog
     - Creates release

4. **Monitor release:**
   - Check [GitHub Actions](https://github.com/ops4life/claudekit/actions) for workflow status
   - New release appears in [Releases](https://github.com/ops4life/claudekit/releases)

### Release Workflow Behavior

**Release is created when:**
- Commits with `feat:`, `fix:`, or `perf:` prefixes are merged to `main`
- Commits contain `BREAKING CHANGE:` in the message

**No release is created when:**
- Only `docs:`, `chore:`, `refactor:`, `style:`, or `test:` commits are merged
- No conventional commits are found

### What Gets Updated

When a release is created, the workflow automatically:

1. **Updates version in:**
   - `.claude-plugin/plugin.json`

2. **Generates/updates:**
   - `CHANGELOG.md` with categorized changes

3. **Creates:**
   - Git tag (e.g., `v1.2.0`)
   - GitHub release with notes

4. **Commits back to main:**
   - Version bump commit
   - Changelog update

## Changelog Format

The automated changelog follows [Keep a Changelog](https://keepachangelog.com/) format:

```markdown
# Changelog

## [1.2.0] - 2025-11-09

### ✨ Features
- **k8s**: add new deployment validation
- **observability**: add SLO calculator

### 🐛 Bug Fixes
- **terraform**: correct cost calculation for GCP

### 📚 Documentation
- update installation guide
```

## Version Strategy

claudekit follows [Semantic Versioning](https://semver.org/) (SemVer):

**Format:** `MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes (e.g., `1.0.0` → `2.0.0`)
- **MINOR**: New features, backward compatible (e.g., `1.0.0` → `1.1.0`)
- **PATCH**: Bug fixes, backward compatible (e.g., `1.0.0` → `1.0.1`)

## Troubleshooting

### No release was created after merge

**Check:**
1. Do commits follow conventional commit format?
   - ✅ `feat: add feature` or `fix: bug fix`
   - ❌ `add feature` or `bug fix`

2. Are commits of types that trigger releases?
   - ✅ `feat:`, `fix:`, `perf:`, `BREAKING CHANGE:`
   - ❌ `docs:`, `chore:`, `refactor:`

3. Check [GitHub Actions](https://github.com/ops4life/claudekit/actions) logs

### Release workflow failed

1. Check GitHub Actions logs for errors
2. Common issues:
   - Invalid JSON in `plugin.json`
   - Missing YAML frontmatter in command files
   - Git conflicts (rarely happens)

### Want to skip a release

Use commit types that don't trigger releases:
```bash
git commit -m "docs: update README"
git commit -m "chore: update dependencies"
```

## Manual Release (Emergency)

If automation fails, you can manually create a release:

1. **Update version:**
   ```bash
   # Edit .claude-plugin/plugin.json
   # Update "version" field
   ```

2. **Update changelog:**
   ```bash
   # Edit CHANGELOG.md
   # Add new version section
   ```

3. **Commit and tag:**
   ```bash
   git add .claude-plugin/plugin.json CHANGELOG.md
   git commit -m "chore(release): bump version to v1.2.0"
   git tag -a v1.2.0 -m "Release v1.2.0"
   git push origin main
   git push origin v1.2.0
   ```

4. **Create GitHub release:**
   ```bash
   gh release create v1.2.0 \
     --title "v1.2.0" \
     --notes "See CHANGELOG.md for details"
   ```

## Best Practices

1. **Write clear commit messages:**
   - Use conventional commit format
   - Include scope when applicable
   - Explain why, not just what

2. **Keep commits focused:**
   - One logical change per commit
   - Easier to review and understand

3. **Use breaking changes sparingly:**
   - Plan major versions carefully
   - Document migration path

4. **Review changelog before release:**
   - Ensure changes are properly categorized
   - Verify nothing sensitive is exposed

## CI/CD Pipeline Details

### Workflow File
`.github/workflows/release.yml`

### Scripts
- `.github/scripts/validate-plugin.sh` - Plugin validation
- `.github/scripts/determine-version.sh` - Version bump logic
- `.github/scripts/update-versions.sh` - Update version files
- `.github/scripts/generate-changelog.sh` - Changelog generation
- `.github/scripts/create-release.sh` - GitHub release creation

### Required Permissions

The workflow requires these GitHub permissions:
- `contents: write` - To push commits and tags
- `pull-requests: write` - To comment on PRs (future enhancement)

### Secrets

No additional secrets required - uses built-in `GITHUB_TOKEN`

## Future Enhancements

Planned improvements:
- [ ] PR comment with preview of changes and version bump
- [ ] Auto-update marketplace.json
- [ ] Plugin validation in PRs
- [ ] Release notes templates
- [ ] Slack/Discord notifications
- [ ] Automated plugin publishing to Claude Code marketplace
