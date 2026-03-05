#!/usr/bin/env bash
# =============================================================================
# Pre-Write Hook Trigger
#
# Minimal trigger that calls tools/check.sh.
# All logic lives in tools/check.sh.
# =============================================================================

set -euo pipefail
set +H  # Disable history expansion

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Read stdin (JSON from Claude Code) and pass to check.sh
exec "$PROJECT_ROOT/tools/check.sh"
