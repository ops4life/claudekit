#!/bin/bash
set -e

echo "🔍 Determining version bump from conventional commits..."

# Get current version from plugin.json
if command -v jq &> /dev/null; then
  CURRENT_VERSION=$(jq -r '.version' .claude-plugin/plugin.json)
else
  CURRENT_VERSION=$(python3 -c "import json; print(json.load(open('.claude-plugin/plugin.json'))['version'])")
fi

echo "📦 Current version: v${CURRENT_VERSION}"

# Get the latest tag (if any)
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [ -z "$LATEST_TAG" ]; then
  echo "ℹ️  No previous tags found, this will be the first release"
  COMMIT_RANGE="HEAD"
else
  echo "📌 Latest tag: ${LATEST_TAG}"
  COMMIT_RANGE="${LATEST_TAG}..HEAD"
fi

# Get commits since last tag
COMMITS=$(git log ${COMMIT_RANGE} --pretty=format:"%s" 2>/dev/null || echo "")

if [ -z "$COMMITS" ]; then
  echo "ℹ️  No commits found since last release"
  echo "should_release=false" >> $GITHUB_OUTPUT
  exit 0
fi

echo ""
echo "📝 Analyzing commits:"
echo "$COMMITS"
echo ""

# Determine version bump based on conventional commits
MAJOR_BUMP=false
MINOR_BUMP=false
PATCH_BUMP=false

# Check for breaking changes (major bump)
if echo "$COMMITS" | grep -qiE "^(feat|fix|perf|refactor|build|ci|docs|style|test|chore)(\(.+\))?!:|BREAKING CHANGE:"; then
  MAJOR_BUMP=true
  echo "🚨 Found breaking changes - MAJOR version bump"
fi

# Check for features (minor bump)
if echo "$COMMITS" | grep -qiE "^feat(\(.+\))?:"; then
  if [ "$MAJOR_BUMP" != "true" ]; then
    MINOR_BUMP=true
    echo "✨ Found new features - MINOR version bump"
  fi
fi

# Check for fixes, performance improvements, etc (patch bump)
if echo "$COMMITS" | grep -qiE "^(fix|perf)(\(.+\))?:"; then
  if [ "$MAJOR_BUMP" != "true" ] && [ "$MINOR_BUMP" != "true" ]; then
    PATCH_BUMP=true
    echo "🐛 Found fixes - PATCH version bump"
  fi
fi

# If no conventional commits found, no release
if [ "$MAJOR_BUMP" != "true" ] && [ "$MINOR_BUMP" != "true" ] && [ "$PATCH_BUMP" != "true" ]; then
  echo "ℹ️  No conventional commits found (feat:, fix:, perf:, BREAKING CHANGE:)"
  echo "ℹ️  Skipping release"
  echo "should_release=false" >> $GITHUB_OUTPUT
  exit 0
fi

# Calculate new version
IFS='.' read -ra VERSION_PARTS <<< "$CURRENT_VERSION"
MAJOR="${VERSION_PARTS[0]}"
MINOR="${VERSION_PARTS[1]}"
PATCH="${VERSION_PARTS[2]}"

if [ "$MAJOR_BUMP" = "true" ]; then
  MAJOR=$((MAJOR + 1))
  MINOR=0
  PATCH=0
  BUMP_TYPE="major"
elif [ "$MINOR_BUMP" = "true" ]; then
  MINOR=$((MINOR + 1))
  PATCH=0
  BUMP_TYPE="minor"
else
  PATCH=$((PATCH + 1))
  BUMP_TYPE="patch"
fi

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"

echo ""
echo "✅ Version bump: ${CURRENT_VERSION} → ${NEW_VERSION} (${BUMP_TYPE})"

# Set outputs for GitHub Actions
echo "should_release=true" >> $GITHUB_OUTPUT
echo "new_version=${NEW_VERSION}" >> $GITHUB_OUTPUT
echo "old_version=${CURRENT_VERSION}" >> $GITHUB_OUTPUT
echo "bump_type=${BUMP_TYPE}" >> $GITHUB_OUTPUT
