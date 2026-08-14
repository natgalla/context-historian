#!/usr/bin/env bash
# Usage: size-guard.sh <file-path>
# If file >3000 bytes, print STATE and OPEN sections only. Otherwise print full file.
FILE="$1"
if [ "$(wc -c < "$FILE")" -gt 3000 ]; then
  awk '/^\*\*STATE\*\*/{found=1} found && /^\*\*[A-Z]/ && !/^\*\*STATE\*\*/{exit} found{print}' "$FILE"
  echo ""
  awk '/^\*\*OPEN\*\*/{found=1} found && /^\*\*[A-Z]/ && !/^\*\*OPEN\*\*/{exit} found{print}' "$FILE"
else
  cat "$FILE"
fi
