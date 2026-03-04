#!/bin/bash
# TypeScript to Heifer: Parse, Translate, and Verify Pipeline
#
# Usage: ./verify.sh <input.ts>
#
# This script performs three steps:
# 1. Parse TypeScript to JSON AST using the TS parser
# 2. Translate JSON AST to Heifer IR
# 3. Run Heifer verification on the translated code

set -e

if [ $# -lt 1 ]; then
  echo "Usage: $0 <input.ts>"
  echo ""
  echo "Example:"
  echo "  $0 test/test_cases/ts/01_basic_types.ts"
  echo ""
  echo "This will:"
  echo "  1. Parse TypeScript to JSON AST"
  echo "  2. Translate to Heifer IR"
  echo "  3. Verify using Heifer's type system"
  exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INPUT_TS="$(realpath "$1")"
BASENAME=$(basename "$INPUT_TS" .ts)
DIRNAME=$(dirname "$INPUT_TS")
OUTPUT_JSON="$DIRNAME/$BASENAME.json"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  TypeScript to Heifer: Full Pipeline                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Input:  $INPUT_TS"
echo "Output: $OUTPUT_JSON"
echo ""

# Phase 1: Parse TypeScript to JSON
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 1: Parsing TypeScript to JSON AST"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ ! -f "$SCRIPT_DIR/parser/dist/parser.js" ]; then
  echo "Error: TypeScript parser not found!"
  echo "Please build the parser first:"
  echo "  cd $SCRIPT_DIR/parser && npm install && npm run build"
  exit 1
fi

node "$SCRIPT_DIR/parser/dist/parser.js" "$INPUT_TS" "$OUTPUT_JSON"
echo "✓ JSON AST generated: $OUTPUT_JSON"
echo ""

# Phase 2: Translate to Heifer IR
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 2: Translating JSON AST to Heifer IR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cd "$SCRIPT_DIR/.." && dune exec ts_to_heifer/bin/main.exe "$OUTPUT_JSON" 2>&1
echo ""

# Phase 3: Verify with Heifer
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 3: Running Heifer Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cd "$SCRIPT_DIR/.." && dune exec ts_to_heifer/bin/verify.exe "$OUTPUT_JSON" 2>&1

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Pipeline Complete                                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
