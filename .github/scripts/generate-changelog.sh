#!/bin/bash
set -e

if [ -z "$NEW_VERSION" ]; then
  echo "❌ Error: NEW_VERSION environment variable not set"
  exit 1
fi

echo "📝 Generating changelog for v${NEW_VERSION}..."

# Get the latest tag (if any)
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [ -z "$LATEST_TAG" ]; then
  COMMIT_RANGE="HEAD"
  PREVIOUS_VERSION="Initial Release"
else
  COMMIT_RANGE="${LATEST_TAG}..HEAD"
  PREVIOUS_VERSION="${LATEST_TAG}"
fi

# Get current date
RELEASE_DATE=$(date +%Y-%m-%d)

# Initialize changelog content
CHANGELOG_ENTRY="# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [${NEW_VERSION}] - ${RELEASE_DATE}

"

# Categorize commits
FEATURES=$(git log ${COMMIT_RANGE} --pretty=format:"%s" --grep="^feat" || echo "")
FIXES=$(git log ${COMMIT_RANGE} --pretty=format:"%s" --grep="^fix" || echo "")
PERFORMANCE=$(git log ${COMMIT_RANGE} --pretty=format:"%s" --grep="^perf" || echo "")
BREAKING=$(git log ${COMMIT_RANGE} --pretty=format:"%B" --grep="BREAKING CHANGE:" || echo "")
DOCS=$(git log ${COMMIT_RANGE} --pretty=format:"%s" --grep="^docs" || echo "")
REFACTOR=$(git log ${COMMIT_RANGE} --pretty=format:"%s" --grep="^refactor" || echo "")
CHORE=$(git log ${COMMIT_RANGE} --pretty=format:"%s" --grep="^chore" || echo "")

# Add breaking changes
if [ -n "$BREAKING" ]; then
  CHANGELOG_ENTRY+="### ⚠️ BREAKING CHANGES

"
  while IFS= read -r line; do
    if [[ "$line" == BREAKING\ CHANGE:* ]]; then
      CHANGELOG_ENTRY+="- ${line#BREAKING CHANGE: }
"
    fi
  done <<< "$BREAKING"
  CHANGELOG_ENTRY+="
"
fi

# Add features
if [ -n "$FEATURES" ]; then
  CHANGELOG_ENTRY+="### ✨ Features

"
  while IFS= read -r commit; do
    # Extract scope and message
    if [[ "$commit" =~ ^feat\(([^)]+)\)!?:\ (.+)$ ]]; then
      SCOPE="${BASH_REMATCH[1]}"
      MESSAGE="${BASH_REMATCH[2]}"
      CHANGELOG_ENTRY+="- **${SCOPE}**: ${MESSAGE}
"
    elif [[ "$commit" =~ ^feat!?:\ (.+)$ ]]; then
      MESSAGE="${BASH_REMATCH[1]}"
      CHANGELOG_ENTRY+="- ${MESSAGE}
"
    fi
  done <<< "$FEATURES"
  CHANGELOG_ENTRY+="
"
fi

# Add fixes
if [ -n "$FIXES" ]; then
  CHANGELOG_ENTRY+="### 🐛 Bug Fixes

"
  while IFS= read -r commit; do
    if [[ "$commit" =~ ^fix\(([^)]+)\):\ (.+)$ ]]; then
      SCOPE="${BASH_REMATCH[1]}"
      MESSAGE="${BASH_REMATCH[2]}"
      CHANGELOG_ENTRY+="- **${SCOPE}**: ${MESSAGE}
"
    elif [[ "$commit" =~ ^fix:\ (.+)$ ]]; then
      MESSAGE="${BASH_REMATCH[1]}"
      CHANGELOG_ENTRY+="- ${MESSAGE}
"
    fi
  done <<< "$FIXES"
  CHANGELOG_ENTRY+="
"
fi

# Add performance improvements
if [ -n "$PERFORMANCE" ]; then
  CHANGELOG_ENTRY+="### ⚡ Performance Improvements

"
  while IFS= read -r commit; do
    if [[ "$commit" =~ ^perf\(([^)]+)\):\ (.+)$ ]]; then
      SCOPE="${BASH_REMATCH[1]}"
      MESSAGE="${BASH_REMATCH[2]}"
      CHANGELOG_ENTRY+="- **${SCOPE}**: ${MESSAGE}
"
    elif [[ "$commit" =~ ^perf:\ (.+)$ ]]; then
      MESSAGE="${BASH_REMATCH[1]}"
      CHANGELOG_ENTRY+="- ${MESSAGE}
"
    fi
  done <<< "$PERFORMANCE"
  CHANGELOG_ENTRY+="
"
fi

# Add refactoring
if [ -n "$REFACTOR" ]; then
  CHANGELOG_ENTRY+="### ♻️ Code Refactoring

"
  while IFS= read -r commit; do
    if [[ "$commit" =~ ^refactor\(([^)]+)\):\ (.+)$ ]]; then
      SCOPE="${BASH_REMATCH[1]}"
      MESSAGE="${BASH_REMATCH[2]}"
      CHANGELOG_ENTRY+="- **${SCOPE}**: ${MESSAGE}
"
    elif [[ "$commit" =~ ^refactor:\ (.+)$ ]]; then
      MESSAGE="${BASH_REMATCH[1]}"
      CHANGELOG_ENTRY+="- ${MESSAGE}
"
    fi
  done <<< "$REFACTOR"
  CHANGELOG_ENTRY+="
"
fi

# Add documentation
if [ -n "$DOCS" ]; then
  CHANGELOG_ENTRY+="### 📚 Documentation

"
  while IFS= read -r commit; do
    if [[ "$commit" =~ ^docs\(([^)]+)\):\ (.+)$ ]]; then
      SCOPE="${BASH_REMATCH[1]}"
      MESSAGE="${BASH_REMATCH[2]}"
      CHANGELOG_ENTRY+="- **${SCOPE}**: ${MESSAGE}
"
    elif [[ "$commit" =~ ^docs:\ (.+)$ ]]; then
      MESSAGE="${BASH_REMATCH[1]}"
      CHANGELOG_ENTRY+="- ${MESSAGE}
"
    fi
  done <<< "$DOCS"
  CHANGELOG_ENTRY+="
"
fi

# Add chores
if [ -n "$CHORE" ]; then
  CHANGELOG_ENTRY+="### 🔧 Chores

"
  while IFS= read -r commit; do
    if [[ "$commit" =~ ^chore\(([^)]+)\):\ (.+)$ ]]; then
      SCOPE="${BASH_REMATCH[1]}"
      MESSAGE="${BASH_REMATCH[2]}"
      CHANGELOG_ENTRY+="- **${SCOPE}**: ${MESSAGE}
"
    elif [[ "$commit" =~ ^chore:\ (.+)$ ]]; then
      MESSAGE="${BASH_REMATCH[1]}"
      CHANGELOG_ENTRY+="- ${MESSAGE}
"
    fi
  done <<< "$CHORE"
  CHANGELOG_ENTRY+="
"
fi

# Append to existing changelog or create new one
if [ -f "CHANGELOG.md" ]; then
  # Read existing changelog, skip the header, and append new entry
  EXISTING_CONTENT=$(tail -n +8 CHANGELOG.md 2>/dev/null || echo "")
  echo "$CHANGELOG_ENTRY$EXISTING_CONTENT" > CHANGELOG.md
else
  echo "$CHANGELOG_ENTRY" > CHANGELOG.md
fi

echo "✅ Changelog generated successfully!"
echo ""
echo "Preview:"
echo "----------------------------------------"
head -n 50 CHANGELOG.md
echo "----------------------------------------"
