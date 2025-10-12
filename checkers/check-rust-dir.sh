#!/usr/bin/env bash
set -uo pipefail

# Recursive Rust directory checker with per-file results
# Usage: ./check-rust-dir.sh <directory>

if [ $# -eq 0 ]; then
    echo "Usage: $0 <directory>"
    echo "Example: $0 /opt/SlugThugShell-clean/crates/common"
    exit 1
fi

TARGET_DIR="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKER="$SCRIPT_DIR/rust-fast-check.sh"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="$SCRIPT_DIR/rust-check-results_${TIMESTAMP}.txt"

if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory not found: $TARGET_DIR"
    exit 1
fi

if [ ! -f "$CHECKER" ]; then
    echo "Error: rust-fast-check.sh not found at $CHECKER"
    exit 1
fi

echo "🔍 Scanning directory: $TARGET_DIR"
echo "📝 Results will be saved to: $OUTPUT_FILE"
echo ""

# Find all Rust files
RUST_FILES=$(find "$TARGET_DIR" -name "*.rs" -type f | sort)
TOTAL_FILES=$(echo "$RUST_FILES" | wc -l)

if [ $TOTAL_FILES -eq 0 ]; then
    echo "No Rust files found in $TARGET_DIR"
    exit 0
fi

echo "Found $TOTAL_FILES Rust files"
echo ""

# Initialize counters
PASSED=0
FAILED=0
CURRENT=0

# Create output file with header
cat > "$OUTPUT_FILE" << EOF
================================================================================
Rust Quality Check Results
================================================================================
Directory: $TARGET_DIR
Timestamp: $(date)
Total Files: $TOTAL_FILES
================================================================================

EOF

# Process each file
for file in $RUST_FILES; do
    ((CURRENT++))
    echo -ne "\rProcessing: $CURRENT/$TOTAL_FILES"

    # Run checker and capture output
    RESULT=$("$CHECKER" "$file" 2>&1)
    EXIT_CODE=$?

    # Append to output file
    cat >> "$OUTPUT_FILE" << EOF
================================================================================
File: $file
Status: $([ $EXIT_CODE -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")
================================================================================
$RESULT

EOF

    # Update counters
    if [ $EXIT_CODE -eq 0 ]; then
        ((PASSED++))
    else
        ((FAILED++))
    fi
done

echo "" # New line after progress

# Add summary to output file
cat >> "$OUTPUT_FILE" << EOF

================================================================================
SUMMARY
================================================================================
Total Files Checked: $TOTAL_FILES
✅ Passed: $PASSED
❌ Failed: $FAILED
Success Rate: $(awk "BEGIN {printf \"%.1f\", ($PASSED/$TOTAL_FILES)*100}")%
================================================================================
EOF

# Display summary to console
echo ""
echo "================================================================================
SUMMARY
================================================================================
Total Files Checked: $TOTAL_FILES
✅ Passed: $PASSED
❌ Failed: $FAILED
Success Rate: $(awk "BEGIN {printf \"%.1f\", ($PASSED/$TOTAL_FILES)*100}")%
================================================================================

📝 Full results saved to: $OUTPUT_FILE
"

# Exit with error if any files failed
[ $FAILED -eq 0 ] && exit 0 || exit 1
