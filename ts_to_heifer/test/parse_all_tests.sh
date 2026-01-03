#!/bin/bash
# Parse all test TypeScript files to JSON AST format
# Output goes to test/ast_output/ for easy inspection

set -e  # Exit on error

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."

# Directories
TEST_CASES_DIR="$SCRIPT_DIR/test_cases"
AST_OUTPUT_DIR="$SCRIPT_DIR/ast_output"
PARSER_SCRIPT="$PROJECT_ROOT/parser/dist/parser.js"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== TypeScript Test Parser ===${NC}"
echo ""

# Check if parser exists
if [ ! -f "$PARSER_SCRIPT" ]; then
    echo -e "${YELLOW}Parser not found. Building parser...${NC}"
    cd "$PROJECT_ROOT/parser"
    npm install
    npm run build
    cd "$SCRIPT_DIR"
fi

# Create output directory if it doesn't exist
mkdir -p "$AST_OUTPUT_DIR"

# Clean previous output
echo -e "${BLUE}Cleaning previous AST output...${NC}"
rm -f "$AST_OUTPUT_DIR"/*.json

# Parse each test file
echo -e "${BLUE}Parsing test files...${NC}"
echo ""

TEST_COUNT=0
SUCCESS_COUNT=0

for ts_file in "$TEST_CASES_DIR"/*.ts; do
    if [ -f "$ts_file" ]; then
        TEST_COUNT=$((TEST_COUNT + 1))

        # Get filename without path and extension
        filename=$(basename "$ts_file" .ts)

        # Output JSON file path
        json_file="$AST_OUTPUT_DIR/${filename}.json"

        echo -e "${BLUE}[$TEST_COUNT]${NC} Parsing: ${GREEN}$filename.ts${NC}"

        # Parse TypeScript to JSON
        if node "$PARSER_SCRIPT" "$ts_file" "$json_file"; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))

            # Get file size for feedback
            size=$(wc -c < "$json_file" | tr -d ' ')
            echo -e "     → Generated: ${GREEN}$json_file${NC} (${size} bytes)"
        else
            echo -e "     → ${YELLOW}Failed to parse${NC}"
        fi

        echo ""
    fi
done

echo -e "${BLUE}=== Summary ===${NC}"
echo -e "Total test files: ${BLUE}$TEST_COUNT${NC}"
echo -e "Successfully parsed: ${GREEN}$SUCCESS_COUNT${NC}"
echo -e "AST output directory: ${GREEN}$AST_OUTPUT_DIR${NC}"
echo ""

# Show how to inspect AST files
if [ $SUCCESS_COUNT -gt 0 ]; then
    echo -e "${BLUE}=== How to Inspect AST ===${NC}"
    echo ""
    echo "View formatted JSON:"
    echo -e "  ${GREEN}cat $AST_OUTPUT_DIR/01_basic_types.json | jq '.'${NC}"
    echo ""
    echo "View specific function:"
    echo -e "  ${GREEN}cat $AST_OUTPUT_DIR/01_basic_types.json | jq '.statements[0]'${NC}"
    echo ""
    echo "Extract function names:"
    echo -e "  ${GREEN}cat $AST_OUTPUT_DIR/01_basic_types.json | jq '.statements[].name.text'${NC}"
    echo ""
    echo "View function parameters:"
    echo -e "  ${GREEN}cat $AST_OUTPUT_DIR/01_basic_types.json | jq '.statements[0].parameters'${NC}"
    echo ""
    echo "All files are in: ${GREEN}$AST_OUTPUT_DIR/${NC}"
fi
