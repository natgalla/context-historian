#!/usr/bin/env bash
# Usage: size-guard.sh <file-path>
# If file >3000 bytes, print STATE and OPEN sections only. Otherwise print full file.
FILE="$1"
if [ "$(wc -c < "$FILE")" -gt 3000 ]; then
  awk '/^\*\*STATE\*\*/{p=1} /^\*\*DECISIONS\*\*/{p=0} /^\*\*OPEN\*\*/{p=1} /^<!-- HEAD:/{p=0} p' "$FILE"
else
  cat "$FILE"
fi
