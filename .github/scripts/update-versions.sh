#!/bin/bash
set -e

if [ -z "$NEW_VERSION" ]; then
  echo "❌ Error: NEW_VERSION environment variable not set"
  exit 1
fi

echo "📝 Updating version to ${NEW_VERSION}..."

# Update plugin.json
if command -v jq &> /dev/null; then
  # Use jq for precise JSON manipulation
  jq --arg version "$NEW_VERSION" '.version = $version' .claude-plugin/plugin.json > .claude-plugin/plugin.json.tmp
  mv .claude-plugin/plugin.json.tmp .claude-plugin/plugin.json
  echo "✅ Updated .claude-plugin/plugin.json"
else
  # Fallback to python
  python3 << EOF
import json
with open('.claude-plugin/plugin.json', 'r') as f:
    data = json.load(f)
data['version'] = '$NEW_VERSION'
with open('.claude-plugin/plugin.json', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
EOF
  echo "✅ Updated .claude-plugin/plugin.json"
fi

echo "✅ Version update complete!"
