#!/bin/bash
set -e

if [ -z "$NEW_VERSION" ]; then
  echo "❌ Error: NEW_VERSION environment variable not set"
  exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
  echo "❌ Error: GITHUB_TOKEN environment variable not set"
  exit 1
fi

echo "🚀 Creating GitHub release for v${NEW_VERSION}..."

# Extract release notes from CHANGELOG.md for this version
RELEASE_NOTES=$(awk "/## \[${NEW_VERSION}\]/,/## \[/" CHANGELOG.md | sed '1d;$d' | sed '/^$/d')

if [ -z "$RELEASE_NOTES" ]; then
  RELEASE_NOTES="Release v${NEW_VERSION}

See CHANGELOG.md for details."
fi

# Create release notes file
cat > /tmp/release-notes.md << EOF
${RELEASE_NOTES}

---

## Installation

### Using Claude Code CLI

\`\`\`bash
claude plugins install ops4life/claudekit
\`\`\`

### Manual Installation

1. Clone or download this repository
2. Copy the \`.claude-plugin\` directory and \`commands\` directory to your project
3. Reload Claude Code

## Available Commands

- \`/claudekit:k8s:deploy\` - Guided Kubernetes deployment workflow
- \`/claudekit:k8s:troubleshoot\` - Systematic pod/service debugging
- \`/claudekit:k8s:manifest-validate\` - YAML validation & best practices
- \`/claudekit:terraform:plan-review\` - Terraform plan analysis
- \`/claudekit:terraform:apply\` - Safe terraform apply workflow
- \`/claudekit:terraform:cloud-cost\` - Multi-cloud cost optimization
- \`/claudekit:cicd:pipeline-new\` - Create production CI/CD pipeline
- \`/claudekit:cicd:deploy-strategy\` - Blue/green, canary, rolling deploys
- \`/claudekit:observability:alert-new\` - Create monitoring alerts
- \`/claudekit:observability:slo-define\` - Define SLOs/SLIs & error budgets
- \`/claudekit:incident:postmortem\` - Structured postmortem creation

## Documentation

For full documentation, see [README.md](https://github.com/${GITHUB_REPOSITORY}/blob/main/README.md)
EOF

# Create GitHub release using gh CLI
gh release create "v${NEW_VERSION}" \
  --title "v${NEW_VERSION}" \
  --notes-file /tmp/release-notes.md \
  --latest

echo "✅ GitHub release created successfully!"
echo "🔗 https://github.com/${GITHUB_REPOSITORY}/releases/tag/v${NEW_VERSION}"

# Cleanup
rm -f /tmp/release-notes.md
