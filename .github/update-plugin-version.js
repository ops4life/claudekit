#!/usr/bin/env node

/**
 * Updates the version in .claude-plugin/plugin.json to match package version
 * This is called by semantic-release during the prepare phase
 */

const fs = require('fs');
const path = require('path');

const pluginJsonPath = path.join(__dirname, '../.claude-plugin/plugin.json');
const newVersion = process.env.NEXT_RELEASE_VERSION;

if (!newVersion) {
  console.error('Error: NEXT_RELEASE_VERSION environment variable not set');
  process.exit(1);
}

try {
  // Read current plugin.json
  const pluginJson = JSON.parse(fs.readFileSync(pluginJsonPath, 'utf8'));

  // Update version
  pluginJson.version = newVersion;

  // Write back with proper formatting
  fs.writeFileSync(pluginJsonPath, JSON.stringify(pluginJson, null, 2) + '\n');

  console.log(`✅ Updated plugin.json version to ${newVersion}`);
} catch (error) {
  console.error('Error updating plugin.json:', error.message);
  process.exit(1);
}
