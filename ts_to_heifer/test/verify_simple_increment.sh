#!/bin/bash
# Script to verify the simple increment example

set -e

echo "=== TypeScript to Heifer Verification Demo ==="
echo ""

# Step 1: Parse TypeScript to JSON
echo "Step 1: Parsing TypeScript to JSON AST..."
npx ts-node ../parse_ts.ts simple_increment.ts > ast_output/simple_increment.json
echo "✓ AST generated"
echo ""

# Step 2: Run verification
echo "Step 2: Translating and verifying..."
cd ..
dune exec ts_verify test/ast_output/simple_increment.json
echo ""
echo "=== Verification Complete ==="
