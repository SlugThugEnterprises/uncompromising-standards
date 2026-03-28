---
hooks:
  # Block write operations that violate code standards
  - event: tool.before.write
    actions:
      - bash:
          command: |
            # Get file path and content from stdin JSON
            context=$(cat)
            file_path=$(echo "$context" | jq -r '.tool_args.filePath // .tool_args.file_path // .tool_args.path // empty')
            content=$(echo "$context" | jq -r '.tool_args.content // .tool_args.contents // empty')
            
            # Skip if no file path or content
            if [[ -z "$file_path" ]] || [[ -z "$content" ]]; then
              exit 0
            fi
            
            # Bypass self and tooling directories
            case "$file_path" in
              *hooks/*|*tools/*|*checkers/*|*rules/*|*.opencode/*|*integrations/*) exit 0 ;;
            esac
            
            # Get checker based on file extension
            ext="${file_path##*.}"
            case "$ext" in
              rs) checker="/opt/uncompromising-standards/checkers/rs.sh" ;;
              py) checker="/opt/uncompromising-standards/checkers/py.sh" ;;
              sh|bash) checker="/opt/uncompromising-standards/checkers/sh.sh" ;;
              *) exit 0 ;;
            esac
            
            # Skip if no checker or not executable
            if [[ ! -x "$checker" ]]; then
              exit 0
            fi
            
            # Write content to temp file
            tmp_file=$(mktemp "/tmp/hook-check-XXXXXX.${ext}")
            printf '%s' "$content" > "$tmp_file"
            trap "rm -f '$tmp_file'" EXIT
            
            # Run checker - exit 2 blocks the tool
            "$checker" "$tmp_file" "$file_path" > /dev/null 2>&1
            exit $?

  # Block edit operations that violate code standards
  - event: tool.before.edit
    actions:
      - bash:
          command: |
            # Get file path from stdin JSON
            context=$(cat)
            file_path=$(echo "$context" | jq -r '.tool_args.filePath // .tool_args.file_path // .tool_args.path // empty')
            
            # Skip if no file path
            if [[ -z "$file_path" ]]; then
              exit 0
            fi
            
            # Bypass self and tooling directories
            case "$file_path" in
              *hooks/*|*tools/*|*checkers/*|*rules/*|*.opencode/*|*integrations/*) exit 0 ;;
            esac
            
            # Get checker based on file extension
            ext="${file_path##*.}"
            case "$ext" in
              rs) checker="/opt/uncompromising-standards/checkers/rs.sh" ;;
              py) checker="/opt/uncompromising-standards/checkers/py.sh" ;;
              sh|bash) checker="/opt/uncompromising-standards/checkers/sh.sh" ;;
              *) exit 0 ;;
            esac
            
            # Skip if no checker or not executable
            if [[ ! -x "$checker" ]]; then
              exit 0
            fi
            
            # For edits, we need to simulate what the edit would produce
            # Read current file, apply oldString->newString replacement, check result
            old_string=$(echo "$context" | jq -r '.tool_args.oldString // .tool_args.old_string // empty')
            new_string=$(echo "$context" | jq -r '.tool_args.newString // .tool_args.new_string // empty')
            
            if [[ -z "$old_string" ]]; then
              exit 0
            fi
            
            # Read current content and apply edit
            if [[ -f "$file_path" ]]; then
              content=$(cat "$file_path")
              # Apply the edit
              result="${content//"$old_string"/"$new_string"}"
              
              # Write to temp and check
              tmp_file=$(mktemp "/tmp/hook-check-XXXXXX.${ext}")
              printf '%s' "$result" > "$tmp_file"
              trap "rm -f '$tmp_file'" EXIT
              
              # Run checker - exit 2 blocks the tool
              "$checker" "$tmp_file" "$file_path" > /dev/null 2>&1
              exit $?
            fi
            
            exit 0
