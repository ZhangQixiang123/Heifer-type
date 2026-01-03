#!/bin/bash
# Test script to verify TypeScript JSDoc → Heifer specification translation

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PARSER_DIR="$PROJECT_ROOT/parser"
ASSETS_DIR="$SCRIPT_DIR/assets"
TEST_FILE="$ASSETS_DIR/jsdoc_test.ts"
JSON_FILE="$ASSETS_DIR/jsdoc_test.json"
OUTPUT_FILE="$ASSETS_DIR/jsdoc_test_output.txt"

echo "=========================================="
echo "TypeScript → Heifer Specification Test"
echo "=========================================="
echo ""

# Step 1: Parse TypeScript to JSON using the TypeScript parser
echo "Step 1: Parsing TypeScript to JSON AST"
echo "Input file: $TEST_FILE"
echo ""

# Build the TypeScript parser if needed
if [ ! -d "$PARSER_DIR/node_modules" ]; then
    echo "Installing parser dependencies..."
    cd "$PARSER_DIR" && npm install
fi

if [ ! -f "$PARSER_DIR/dist/parser.js" ]; then
    echo "Building TypeScript parser..."
    cd "$PARSER_DIR" && npm run build
fi

# Run the parser
echo "Running TypeScript parser..."
cd "$PARSER_DIR"
npx ts-node src/parser.ts "$TEST_FILE" || {
    echo "✗ Parser failed!"
    exit 1
}

if [ ! -f "$JSON_FILE" ]; then
    echo "✗ Parser did not generate JSON file!"
    exit 1
fi

echo "✓ Parser generated JSON"
echo ""

# Display the TypeScript source
echo "--- TypeScript Source ---"
cat "$TEST_FILE"
echo ""

# Display JSDoc from JSON
echo "--- Extracted JSDoc Annotations ---"
cat "$JSON_FILE" | grep -A 2 '"jsdoc"' || echo "No JSDoc found"
echo ""

# Step 2: Build the translator
echo "Step 2: Building ts_to_heifer translator..."
cd "$PROJECT_ROOT/.."
dune build ts_to_heifer/bin/main.exe
echo "✓ Build successful"
echo ""

# Step 3: Run the translator
echo "Step 3: Translating to Heifer IR..."
echo "Command: dune exec ts_to_heifer/bin/main.exe -- $JSON_FILE --functions"
echo ""

dune exec ts_to_heifer/bin/main.exe -- "$JSON_FILE" --functions > "$OUTPUT_FILE" 2>&1 || {
    echo "✗ Translation failed!"
    echo "Error output:"
    cat "$OUTPUT_FILE"
    exit 1
}

echo "--- Heifer Output ---"
cat "$OUTPUT_FILE"
echo ""

# Step 4: Verify the specification was parsed correctly
echo "Step 4: Verifying specification translation..."

# Check if the output contains require and ensure
if grep -q "req" "$OUTPUT_FILE" && grep -q "ens" "$OUTPUT_FILE"; then
    echo "✓ Specification keywords found (req/ens)"
else
    echo "✗ Specification keywords NOT found"
    exit 1
fi

# Check if function name is present
if grep -q "testFunction" "$OUTPUT_FILE"; then
    echo "✓ Function name 'testFunction' found"
else
    echo "✗ Function name NOT found"
    exit 1
fi

# Check if the actual parsed spec is used (x>0 or x > 0), not generated spec (x:#int)
if grep -q "x>0\|x > 0" "$OUTPUT_FILE"; then
    echo "✓ Parsed JSDoc specification 'x>0' found in output"
else
    echo "✗ Parsed JSDoc specification NOT found - using generated spec instead"
    exit 1
fi

# Check if parameters are present
if grep -q "x" "$OUTPUT_FILE"; then
    echo "✓ Parameter 'x' found in output"
else
    echo "✗ Parameter NOT found"
    exit 1
fi

echo ""
echo "=========================================="
echo "✓ All tests passed!"
echo "=========================================="
echo ""
echo "Translation Summary:"
echo "  - TypeScript JSDoc annotations were successfully parsed"
echo "  - Heifer specifications (req/ens) were generated"
echo "  - Function signature was preserved"
echo ""
echo "Output saved to: $OUTPUT_FILE"
