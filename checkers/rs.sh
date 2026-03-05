#!/usr/bin/env bash
# DO-NOT-EDIT_static_Quality_Check.sh
# Rust Gate 0 (single-file): CRITICAL-only, no overrides, "perfect lanes".

set -euo pipefail
IFS=$'\n\t'

MAX_BYTES=$((1024*1024))  # hard fail
MAX_LINES=150             # hard fail
MAX_FN_LINES=40           # hard fail

usage() {
  echo "Usage: $0 --file path/to/file.rs"
  echo "   or: $0 path/to/file.rs"
}

FILE=""

# --- args (single-file only) ---
if [[ $# -eq 0 ]]; then usage; exit 2; fi
while [[ $# -gt 0 ]]; do
  case "$1" in
    --file) FILE="${2:?}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)
      if [[ -z "$FILE" ]]; then FILE="$1"; shift
      else echo "Unknown arg: $1" >&2; usage; exit 2
      fi
      ;;
  esac
done

CRIT=0
emit() { # file line msg
  local f="$1" ln="${2:-0}" msg="$3"
  CRIT=$((CRIT+1))
  printf 'CRITICAL: %s:%s: %s\n' "$f" "$ln" "$msg"
}

# basic file validation
if [[ -z "${FILE:-}" || "$FILE" != *.rs || ! -f "$FILE" ]]; then
  emit "${FILE:-<missing>}" 0 "invalid or missing .rs file"
  exit 1
fi

# --- sanitizer (best-effort, preserves line count) ---
# Strips //, /* */, normal strings, raw strings (r"..." and r#"... "#), byte strings, raw byte strings, char literals.
sanitize_rs() {
  awk '
  BEGIN { in_block=0; in_str=0; in_char=0; in_raw=0; raw_hash=""; }
  {
    line=$0; out="";
    for (i=1;i<=length(line);i++) {
      c=substr(line,i,1); n=substr(line,i,2);

      if (in_block) { if (n=="*/") { in_block=0; i++ } continue }
      if (in_raw) {
        endpat="\"" raw_hash
        if (substr(line,i,length(endpat))==endpat) { in_raw=0; i+=length(endpat)-1 }
        continue
      }
      if (in_str) { if (c=="\"" && substr(line,i-1,1)!="\\") { in_str=0 } continue }
      if (in_char) { if (c=="\047" && substr(line,i-1,1)!="\\") { in_char=0 } continue }

      if (n=="//") break
      if (n=="/*") { in_block=1; i++; continue }

      # raw string: r#*"   (zero or more hashes)
      if (match(substr(line,i), /^r#*"/)) {
        raw_hash=substr(line, i+1, RLENGTH-2)  # hashes after r (maybe empty)
        in_raw=1
        i+=RLENGTH-1
        continue
      }

      # raw byte string: br#*"
      if (match(substr(line,i), /^br#*"/)) {
        raw_hash=substr(line, i+2, RLENGTH-3)  # hashes after br (maybe empty)
        in_raw=1
        i+=RLENGTH-1
        continue
      }

      # byte string: b"..." (treat as normal string)
      if (match(substr(line,i), /^b"/)) { in_str=1; i+=1; continue }

      if (c=="\"") { in_str=1; continue }
      if (c=="\047") { in_char=1; continue }

      out=out c
    }
    print out
  }'
}

raw="$(cat "$FILE")"
san="$(sanitize_rs <<<"$raw")"

# --- hard limits ---
sz=$(wc -c < "$FILE" | tr -d ' ')
if [[ "$sz" -gt "$MAX_BYTES" ]]; then
  emit "$FILE" 0 "file too large: ${sz} bytes > ${MAX_BYTES}"
fi

lines=$(wc -l < "$FILE" | tr -d ' ')
if [[ "$lines" -gt "$MAX_LINES" ]]; then
  emit "$FILE" 0 "file too long: ${lines} lines > ${MAX_LINES}"
fi

# --- mandatory traceability (raw, not sanitized) ---
if ! grep -q '@satisfies[[:space:]]\+REQ-' <<<"$raw"; then
  emit "$FILE" 0 "traceability missing: required '@satisfies REQ-...'"
fi

# --- 1) unfinished markers / forbidden macros ---
while IFS=: read -r ln _; do
  emit "$FILE" "$ln" "unfinished marker/macro forbidden (TODO/FIXME/HACK/XXX/todo!/unimplemented!)"
done < <(
  grep -nE '\b(TODO|FIXME|HACK|XXX)\b|(^|[^A-Za-z0-9_])todo!\s*\(|(^|[^A-Za-z0-9_])unimplemented!\s*\(' <<<"$san" || true
)

# --- 2) unsafe / UB magnets (mandatory ban) ---
while IFS=: read -r ln _; do
  emit "$FILE" "$ln" "unsafe/UB-magnet forbidden"
done < <(
  grep -nE '\bunsafe\b|\btransmute\b|\bzeroed\b|\bassume_init\b|\bget_unchecked\b|\bfrom_utf8_unchecked\b|intrinsics::|\bstatic[[:space:]]+mut\b|\bUnsafeCell\b|\baddr_of\b' <<<"$san" || true
)

# --- 3) debug output forbidden everywhere ---
while IFS=: read -r ln _; do
  emit "$FILE" "$ln" "debug output forbidden (dbg!/println!/eprintln!)"
done < <(
  grep -nE '(^|[^A-Za-z0-9_])dbg!\s*\(|(^|[^A-Za-z0-9_])(println|eprintln)!\s*\(' <<<"$san" || true
)

# --- 4) panic sources forbidden everywhere (mandatory lanes) ---
while IFS=: read -r ln _; do
  emit "$FILE" "$ln" "panic source forbidden (panic!/unreachable!/assert!/unwrap/expect)"
done < <(
  grep -nE '(^|[^A-Za-z0-9_])panic!\s*\(|(^|[^A-Za-z0-9_])unreachable!\s*\(|(^|[^A-Za-z0-9_])assert(_eq)?!\s*\(|(^|[^A-Za-z0-9_])debug_assert(_eq)?!\s*\(|\.unwrap\s*\(|\.expect\s*\(' <<<"$san" || true
)

# --- 5) heap ban (mandatory lanes) ---
# Strict: bans both heap-alloc sites and common heap-owning types/paths.
while IFS=: read -r ln _; do
  emit "$FILE" "$ln" "heap forbidden (no-heap): Vec/Box/Arc/Rc/HashMap/BTreeMap/alloc or allocation site"
done < <(
  grep -nE '\b(Vec|Box|Arc|Rc|HashMap|BTreeMap)\b|\balloc::\b|vec!\s*\[|Vec::(new|with_capacity)\s*\(|Box::new\s*\(|Arc::new\s*\(|Rc::new\s*\(|HashMap::new\s*\(|BTreeMap::new\s*\(|\bto_vec\s*\(|collect::\s*<\s*Vec\b' <<<"$san" || true
)

# --- 6) operator ban (mandatory lanes) ---
# Bans: + - * / % anywhere they look like arithmetic operators.
# Excludes: ->, *const, *mut, references &, and common type-pointer tokens.
# NOTE: This is intentionally strict.
while IFS=: read -r ln line; do
  # skip arrows and pointer type tokens to reduce obvious false positives
  if grep -qE '->|\*const|\*mut' <<<"$line"; then
    # keep checking other operators on the same line (e.g., +)
    :
  fi

  # Ban + * / % when between "value-ish" tokens
  if grep -qE '([A-Za-z0-9_\)\]])[[:space:]]*[\+\*\/%][[:space:]]*([A-Za-z0-9_\(\[])' <<<"$line"; then
    emit "$FILE" "$ln" "operator forbidden: use checked_/saturating_/wrapping_ APIs (found one of + * / %)"
    continue
  fi

  # Ban '-' as subtraction (try to avoid negative literals like = -1 or ( -1 )
  if grep -qE '([A-Za-z0-9_\)\]])[[:space:]]*-[[:space:]]*([A-Za-z_\(]|[0-9])' <<<"$line"; then
    # exclude common negative literal contexts: "= -1", "( -1", ", -1", "[ -1"
    if ! grep -qE '(^|[=,\(\[])[[:space:]]*-[[:space:]]*[0-9]+' <<<"$line"; then
      emit "$FILE" "$ln" "operator forbidden: use checked_/saturating_/wrapping_ APIs (found '-')"
      continue
    fi
  fi
done < <(grep -nE '[\+\-\*\/%]' <<<"$san" || true)

# --- 7) indexing ban (mandatory lanes) ---
# Flags x[i] / x[0] etc. (does not flag attributes #[...]).
while IFS=: read -r ln line; do
  emit "$FILE" "$ln" "indexing forbidden: use .get() / iterators (no [])"
done < <(
  grep -nE '([A-Za-z0-9_\)\]])[[:space:]]*\[[^]]+\]' <<<"$san" | grep -vE '^[0-9]+:\s*#\s*\[' || true
)

# --- 8) wildcard match arm ban (mandatory lanes) ---
# Any `_ =>` is forbidden. No exceptions.
while IFS=: read -r ln _; do
  emit "$FILE" "$ln" "wildcard match arm forbidden: '_ => ...' not allowed (must be exhaustive)"
done < <(grep -nE '_[[:space:]]*=>' <<<"$san" || true)

# --- 9) structural balance (mandatory sanity) ---
ob=$(grep -o '{' <<<"$san" | wc -l | tr -d ' ')
cb=$(grep -o '}' <<<"$san" | wc -l | tr -d ' ')
op=$(grep -o '(' <<<"$san" | wc -l | tr -d ' ')
cp=$(grep -o ')' <<<"$san" | wc -l | tr -d ' ')
os=$(grep -o '\[' <<<"$san" | wc -l | tr -d ' ')
cs=$(grep -o ']' <<<"$san" | wc -l | tr -d ' ')
[[ "$ob" -ne "$cb" ]] && emit "$FILE" 0 "brace mismatch: {=$ob }=$cb"
[[ "$op" -ne "$cp" ]] && emit "$FILE" 0 "paren mismatch: (=$op )=$cp"
[[ "$os" -ne "$cs" ]] && emit "$FILE" 0 "bracket mismatch: [=$os ]=$cs"

# --- 10) function length hard-fail (sanitized brace depth heuristic) ---

sanitize_rs() {
  awk '
  BEGIN { in_block=0; in_str=0; in_char=0; in_raw=0; raw_hash=""; }

  function is_escaped(s, pos,   k, bs) {
    bs=0
    for (k=pos-1; k>=1 && substr(s,k,1)=="\\"; k--) bs++
    return (bs % 2 == 1)
  }

  {
    line=$0; out="";
    for (i=1;i<=length(line);i++) {
      c=substr(line,i,1); n=substr(line,i,2);

      if (in_block) { if (n=="*/") { in_block=0; i++ } continue }
      if (in_raw) {
        endpat="\"" raw_hash
        if (substr(line,i,length(endpat))==endpat) { in_raw=0; i+=length(endpat)-1 }
        continue
      }

      if (in_str) {
        if (c=="\"" && !is_escaped(line, i)) { in_str=0 }
        continue
      }

      if (in_char) { if (c=="\047" && substr(line,i-1,1)!="\\") { in_char=0 } continue }

      if (n=="//") break
      if (n=="/*") { in_block=1; i++; continue }

      # raw string: r#*"   (zero or more hashes)
      if (match(substr(line,i), /^r#*"/)) {
        raw_hash=substr(line, i+1, RLENGTH-2)  # hashes after r (maybe empty)
        in_raw=1
        i+=RLENGTH-1
        continue
      }

      # raw byte string: br#*"
      if (match(substr(line,i), /^br#*"/)) {
        raw_hash=substr(line, i+2, RLENGTH-3)  # hashes after br (maybe empty)
        in_raw=1
        i+=RLENGTH-1
        continue
      }

      # byte string: b"..." (treat as normal string)
      if (match(substr(line,i), /^b"/)) { in_str=1; i+=1; continue }

      if (c=="\"") { in_str=1; continue }
      if (c=="\047") { in_char=1; continue }

      out=out c
    }
    print out
}






# --- exit --- 
if [[ "$CRIT" -gt 0 ]]; then
  exit 1
fi 
exit 0
