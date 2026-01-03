#!/bin/bash
# TypeScript to Heifer Translation Pipeline
#
# Usage: ./translate.sh <input.ts>

set -e

if [ $# -lt 1 ]; then
  echo "Usage: $0 <input.ts>"
  exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INPUT_TS="$(realpath "$1")"
BASENAME=$(basename "$INPUT_TS" .ts)
DIRNAME=$(dirname "$INPUT_TS")
OUTPUT_JSON="$DIRNAME/$BASENAME.json"

echo "==> Phase 1: Parsing TypeScript to JSON AST..."
node "$SCRIPT_DIR/parser/dist/parser.js" "$INPUT_TS" "$OUTPUT_JSON"

echo ""
echo "==> Phase 2: Translating JSON AST to Heifer IR..."
cd "$SCRIPT_DIR/.." && eval $(opam env --switch=default) && dune exec ts_to_heifer/bin/main.exe "$OUTPUT_JSON"

echo ""
echo "✓ Translation complete!"
echo "  TypeScript: $INPUT_TS"
echo "  JSON AST:   $OUTPUT_JSON"
