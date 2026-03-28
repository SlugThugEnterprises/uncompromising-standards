#!/usr/bin/env bash
# =============================================================================
# Code Standards Checker - Pre-Write Hook
# Receives JSON from stdin, validates code, returns allow/deny.
# Exit codes: 0 = allow, 2 = block
# =============================================================================

set -uo pipefail
set +H

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHECKERS_DIR="$PROJECT_ROOT/checkers"

LOG_DIR="${LOG_DIR:-$PROJECT_ROOT/logs}"
LOG_FILE="$LOG_DIR/hook.log"
DEBUG_LOG="${LOG_DIR}/hook.debug.log"

setup_logging() {
    mkdir -p "$LOG_DIR"
    chmod 755 "$LOG_DIR"
}

log() {
    local level="$1"
    local msg="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $msg" >> "$LOG_FILE"
}

log_debug() {
    [[ "${HOOK_DEBUG:-0}" == "1" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S.%3N')] $1" >> "$DEBUG_LOG"
}

should_bypass() {
    local file_path="$1"
    log_debug "  should_bypass: $file_path"
    local bypass_dirs=("hooks" "tools" "checkers" "rules" ".claude")
    for dir in "${bypass_dirs[@]}"; do
        if [[ "$file_path" == *"/$dir/"* ]] || [[ "$file_path" == *"/$dir" ]] || [[ "$file_path" == "$dir"* ]]; then
            log_debug "  BYPASSED (dir: $dir)"
            return 0
        fi
    done
    log_debug "  NOT bypassed"
    return 1
}

get_checker() {
    local file_path="$1"
    local ext="${file_path##*.}"
    log_debug "  get_checker: ext=$ext"
    case "$ext" in
        rs)  echo "$CHECKERS_DIR/rs.sh" ;;
        sh|bash) echo "$CHECKERS_DIR/sh.sh" ;;
        py)  echo "$CHECKERS_DIR/py.sh" ;;
        *)   echo "" ;;
    esac
}

main() {
    setup_logging
    log_debug "=== check.sh START ==="
    log_debug "  Args: $@"
    
    local input
    input=$(cat)
    log_debug "  Raw input: $input"
    
    if ! echo "$input" | jq -e . &>/dev/null; then
        log "WARN" "Invalid JSON - allowing"
        log_debug "=== check.sh END (invalid JSON) ==="
        exit 0
    fi
    
    local tool_name
    tool_name=$(echo "$input" | jq -r '.tool_name // .tool // empty')
    log_debug "  tool_name: '$tool_name'"
    
    case "$tool_name" in
        Write|WriteFile|write_file|write)
            log_debug "  Processing Write operation"
            ;;
        *)
            log_debug "  Skipping (not Write): $tool_name"
            log_debug "=== check.sh END (not Write) ==="
            exit 0
            ;;
    esac
    
    local file_path
    file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // .tool_input.filePath // empty')
    log_debug "  file_path: '$file_path'"
    
    if [[ -z "$file_path" ]]; then
        log "WARN" "No file path - allowing"
        log_debug "=== check.sh END (no file_path) ==="
        exit 0
    fi
    
    if should_bypass "$file_path"; then
        log "INFO" "Bypassed: $file_path"
        log_debug "=== check.sh END (bypassed) ==="
        exit 0
    fi
    
    local checker
    checker=$(get_checker "$file_path")
    log_debug "  checker: '$checker'"
    
    if [[ -z "$checker" ]] || [[ ! -x "$checker" ]]; then
        log "INFO" "No checker for $file_path - allowing"
        log_debug "=== check.sh END (no checker) ==="
        exit 0
    fi
    
    local content
    content=$(echo "$input" | jq -r '.tool_input.content // empty')
    log_debug "  content length: ${#content} chars"
    
    if [[ -z "$content" ]]; then
        log "WARN" "No content - allowing"
        log_debug "=== check.sh END (no content) ==="
        exit 0
    fi
    
    content="${content//\\!/!}"
    
    local temp_file
    temp_file=$(mktemp "/tmp/hook-check-XXXXXX.${file_path##*.}")
    printf '%s' "$content" > "$temp_file"
    log_debug "  temp_file: $temp_file"
    
    local checker_output
    checker_output=$("$checker" "$temp_file" "$file_path" 2>&1)
    local checker_rc=$?
    rm -f "$temp_file"
    
    log_debug "  checker exit code: $checker_rc"
    
    if [[ $checker_rc -eq 0 ]]; then
        log "INFO" "ALLOWED: $file_path"
        log_debug "=== check.sh END (ALLOWED) ==="
        exit 0
    else
        log "ERROR" "BLOCKED: $file_path - $checker_output"
        log_debug "  block reason: $checker_output"
        log_debug "=== check.sh END (BLOCKED) ==="
        
        # Detect OpenCode vs Claude Code
        # OpenCode sends "write" (lowercase) and uses filePath (camelCase)
        local caller="claude-code"
        if [[ "$tool_name" == "write" ]]; then
            caller="opencode"
        fi
        
        # Fallback: check if input contains filePath (camelCase, OpenCode format)
        if [[ "$input" == *"filePath"* ]]; then
            caller="opencode"
        fi
        
        # Format error message (strip ANSI codes and clean up)
        local formatted_reason
        formatted_reason=$(echo "$checker_output" | grep "FAIL" | grep -v "Check FAILED" | sed 's/.*FAIL.*: //' | sed 's/   File: .*//' | tr '\n' ';' | sed 's/;$//' | sed 's/\x1b\[[0-9;]*m//g')
        [[ -z "$formatted_reason" ]] && formatted_reason="Code standards check failed"
        
        if [[ "$caller" == "opencode" ]]; then
            # OpenCode: plain text to stderr
            echo "$formatted_reason" >&2
        else
            # Claude Code: JSON to stderr
            jq -n --arg reason "$checker_output" '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": $reason}}' >&2
        fi
        exit 2
    fi
}

main "$@"
