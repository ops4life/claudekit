#!/bin/bash
set -e

echo "🔍 Validating plugin configuration..."

# Validate plugin.json exists and is valid JSON
if [ ! -f ".claude-plugin/plugin.json" ]; then
  echo "❌ Error: .claude-plugin/plugin.json not found"
  exit 1
fi

# Check if jq is available, if not use python
if command -v jq &> /dev/null; then
  if ! jq empty .claude-plugin/plugin.json 2>/dev/null; then
    echo "❌ Error: Invalid JSON in .claude-plugin/plugin.json"
    exit 1
  fi

  # Validate required fields
  NAME=$(jq -r '.name' .claude-plugin/plugin.json)
  VERSION=$(jq -r '.version' .claude-plugin/plugin.json)
  DESCRIPTION=$(jq -r '.description' .claude-plugin/plugin.json)
else
  # Fallback to python for JSON validation
  if ! python3 -m json.tool .claude-plugin/plugin.json > /dev/null 2>&1; then
    echo "❌ Error: Invalid JSON in .claude-plugin/plugin.json"
    exit 1
  fi

  NAME=$(python3 -c "import json; print(json.load(open('.claude-plugin/plugin.json'))['name'])")
  VERSION=$(python3 -c "import json; print(json.load(open('.claude-plugin/plugin.json'))['version'])")
  DESCRIPTION=$(python3 -c "import json; print(json.load(open('.claude-plugin/plugin.json'))['description'])")
fi

if [ "$NAME" == "null" ] || [ -z "$NAME" ]; then
  echo "❌ Error: 'name' field is required in plugin.json"
  exit 1
fi

if [ "$VERSION" == "null" ] || [ -z "$VERSION" ]; then
  echo "❌ Error: 'version' field is required in plugin.json"
  exit 1
fi

if [ "$DESCRIPTION" == "null" ] || [ -z "$DESCRIPTION" ]; then
  echo "❌ Error: 'description' field is required in plugin.json"
  exit 1
fi

echo "✅ Plugin name: $NAME"
echo "✅ Current version: $VERSION"
echo "✅ Description: $DESCRIPTION"

# Validate command files exist and have proper structure
COMMAND_COUNT=0
echo ""
echo "🔍 Validating command files..."

if [ -d "commands" ]; then
  for cmd_file in $(find commands -name "*.md" -type f); do
    # Check for YAML frontmatter
    if ! head -1 "$cmd_file" | grep -q "^---$"; then
      echo "⚠️  Warning: $cmd_file missing YAML frontmatter"
    else
      ((COMMAND_COUNT++))
    fi
  done
  echo "✅ Found $COMMAND_COUNT command files"
else
  echo "⚠️  Warning: commands directory not found"
fi

echo ""
echo "✅ Plugin validation complete!"
