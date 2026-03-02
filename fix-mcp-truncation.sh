#!/usr/bin/env bash
set -e

# fix-mcp-truncation.sh — Patch for GitHub Copilot CLI issue #1732
#
# MCP tool responses larger than 10KB are silently truncated before the
# large-output-to-file mechanism can save them to a temp file.  This one-line
# patch lets the full content reach the large-output handler so responses are
# saved to a temp file instead of being silently corrupted.
#
# Usage:
#   bash fix-mcp-truncation.sh            # auto-detect npm global install
#   bash fix-mcp-truncation.sh /path/to/sdk/index.js  # explicit path
#
# The script is idempotent — running it twice on an already-patched file is a
# safe no-op.
#
# See: https://github.com/github/copilot-cli/issues/1732

SDK_FILE="${1:-}"

# Auto-detect the installed sdk/index.js when no argument is given
if [ -z "$SDK_FILE" ]; then
  if command -v npm >/dev/null 2>&1; then
    NPM_ROOT="$(npm root -g 2>/dev/null || true)"
    if [ -n "$NPM_ROOT" ] && [ -f "$NPM_ROOT/@github/copilot/sdk/index.js" ]; then
      SDK_FILE="$NPM_ROOT/@github/copilot/sdk/index.js"
    fi
  fi
fi

if [ -z "$SDK_FILE" ] || [ ! -f "$SDK_FILE" ]; then
  echo "Error: Could not locate sdk/index.js." >&2
  echo "Usage: bash fix-mcp-truncation.sh [/path/to/sdk/index.js]" >&2
  exit 1
fi

echo "Patching: $SDK_FILE"

# The pattern to find (success path with truncated textResultForLlm)
OLD='{textResultForLlm:a,binaryResultsForLlm:s,resultType:"success",sessionLog:a,toolTelemetry:i,contents:r}'
NEW='{textResultForLlm:o||"",binaryResultsForLlm:s,resultType:"success",sessionLog:a,toolTelemetry:i,contents:r}'

if grep -qF "$NEW" "$SDK_FILE"; then
  echo "Already patched — no changes needed."
  exit 0
fi

if ! grep -qF "$OLD" "$SDK_FILE"; then
  echo "Error: Expected code pattern not found in $SDK_FILE." >&2
  echo "This script is written for @github/copilot v0.0.420. The minified" >&2
  echo "variable names may differ in other versions." >&2
  exit 1
fi

# Apply the one-line fix: use the full (filtered) content for textResultForLlm
# in the success path so the downstream large-output handler can detect it and
# save to a temp file when the response exceeds 30KB.
sed -i "s@$OLD@$NEW@" "$SDK_FILE"

if grep -qF "$NEW" "$SDK_FILE"; then
  echo "✓ Patch applied successfully."
  echo "  MCP tool responses will now be saved to temp files when they exceed 30KB,"
  echo "  instead of being silently truncated to 10KB."
else
  echo "Error: Patch verification failed." >&2
  exit 1
fi
