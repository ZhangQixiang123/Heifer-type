#!/bin/bash
# Run OCaml translator on all test JSON files
# Output goes to heifer_output/ for inspection

set -e  # Exit on error

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."

# Directories
AST_INPUT_DIR="$SCRIPT_DIR/ast_output"
HEIFER_OUTPUT_DIR="$SCRIPT_DIR/heifer_output"
TRANSLATOR="$PROJECT_ROOT/../ts_to_heifer/bin/main.exe"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== TypeScript to Heifer Translation Test ===${NC}"
echo ""

# Check if AST files exist
if [ ! -d "$AST_INPUT_DIR" ] || [ -z "$(ls -A $AST_INPUT_DIR 2>/dev/null)" ]; then
    echo -e "${YELLOW}No AST files found. Running parser first...${NC}"
    ./parse_all_tests.sh
    echo ""
fi

# Build the translator
echo -e "${BLUE}Building OCaml translator...${NC}"
cd "$PROJECT_ROOT/.."
eval $(opam env --switch=default 2>/dev/null || opam env)
dune build ts_to_heifer 2>&1 | head -20

if [ ! -f "_build/default/ts_to_heifer/bin/main.exe" ]; then
    echo -e "${RED}Error: Translator not built${NC}"
    exit 1
fi

cd "$SCRIPT_DIR"
echo -e "${GREEN}✓ Translator ready${NC}"
echo ""

# Create output directory
mkdir -p "$HEIFER_OUTPUT_DIR"

# Clean previous output
echo -e "${BLUE}Cleaning previous Heifer output...${NC}"
rm -f "$HEIFER_OUTPUT_DIR"/*.ml
rm -f "$HEIFER_OUTPUT_DIR"/*.txt

echo -e "${BLUE}Translating JSON AST to Heifer IR...${NC}"
echo ""

TEST_COUNT=0
SUCCESS_COUNT=0
FAIL_COUNT=0

for json_file in "$AST_INPUT_DIR"/*.json; do
    if [ -f "$json_file" ]; then
        TEST_COUNT=$((TEST_COUNT + 1))

        # Get filename without path and extension
        filename=$(basename "$json_file" .json)

        # Output files
        heifer_output="$HEIFER_OUTPUT_DIR/${filename}.ml"
        error_output="$HEIFER_OUTPUT_DIR/${filename}_error.txt"

        echo -e "${BLUE}[$TEST_COUNT]${NC} Translating: ${GREEN}$filename${NC}"

        # Run translator
        if "$PROJECT_ROOT/../_build/default/ts_to_heifer/bin/main.exe" "$json_file" > "$heifer_output" 2>"$error_output"; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))

            # Check output size
            if [ -s "$heifer_output" ]; then
                lines=$(wc -l < "$heifer_output" | tr -d ' ')
                echo -e "     → ${GREEN}Success${NC}: $lines lines generated"

                # Show snippet
                echo -e "     ${BLUE}Preview:${NC}"
                head -3 "$heifer_output" | sed 's/^/       /'

                # Remove error file if empty
                if [ ! -s "$error_output" ]; then
                    rm -f "$error_output"
                fi
            else
                echo -e "     → ${YELLOW}Warning: Empty output${NC}"
                FAIL_COUNT=$((FAIL_COUNT + 1))
            fi
        else
            FAIL_COUNT=$((FAIL_COUNT + 1))
            echo -e "     → ${RED}Failed${NC}"

            # Show error preview
            if [ -s "$error_output" ]; then
                echo -e "     ${RED}Error:${NC}"
                head -5 "$error_output" | sed 's/^/       /'
            fi
        fi

        echo ""
    fi
done

echo -e "${BLUE}=== Summary ===${NC}"
echo -e "Total test files: ${BLUE}$TEST_COUNT${NC}"
echo -e "Successfully translated: ${GREEN}$SUCCESS_COUNT${NC}"
echo -e "Failed: ${RED}$FAIL_COUNT${NC}"
echo -e "Heifer output directory: ${GREEN}$HEIFER_OUTPUT_DIR${NC}"
echo ""

# Show what was generated
if [ $SUCCESS_COUNT -gt 0 ]; then
    echo -e "${BLUE}=== Generated Files ===${NC}"
    ls -lh "$HEIFER_OUTPUT_DIR"/*.ml 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
    echo ""

    echo -e "${BLUE}=== How to Inspect Output ===${NC}"
    echo ""
    echo "View generated Heifer code:"
    echo -e "  ${GREEN}cat $HEIFER_OUTPUT_DIR/01_basic_types.ml${NC}"
    echo ""
    echo "View all function names:"
    echo -e "  ${GREEN}grep '^let ' $HEIFER_OUTPUT_DIR/*.ml${NC}"
    echo ""
    echo "Check for errors:"
    echo -e "  ${GREEN}cat $HEIFER_OUTPUT_DIR/*_error.txt 2>/dev/null${NC}"
    echo ""
fi

# Show errors if any
if [ -f "$HEIFER_OUTPUT_DIR"/*_error.txt 2>/dev/null ]; then
    echo -e "${YELLOW}=== Translation Errors ===${NC}"
    for error_file in "$HEIFER_OUTPUT_DIR"/*_error.txt; do
        if [ -s "$error_file" ]; then
            echo -e "${YELLOW}$(basename $error_file):${NC}"
            cat "$error_file" | head -10
            echo ""
        fi
    done
fi
