# TypeScript to Heifer - Test Suite

## Overview

This test suite contains comprehensive TypeScript test cases **without JSDoc annotations** to test automatic specification generation from TypeScript's type system.

All tests focus on **type annotations only** - no manual specifications needed!

---

## Directory Structure

```
test/
├── test_cases/          # TypeScript test files (input)
│   ├── 01_basic_types.ts
│   ├── 02_nullable_types.ts
│   ├── 03_control_flow.ts
│   ├── 04_operators.ts
│   ├── 05_variables.ts
│   ├── 06_objects.ts
│   ├── 07_arrays.ts
│   ├── 08_loops.ts
│   ├── 09_type_guards.ts
│   └── 10_complex_functions.ts
├── ast_output/          # JSON AST files (parser output)
│   ├── 01_basic_types.json
│   ├── 02_nullable_types.json
│   └── ...
├── parse_all_tests.sh   # Script to parse all tests
└── README.md            # This file
```

---

## Quick Start

### Parse All Test Files

```bash
cd test
./parse_all_tests.sh
```

This will:
1. Parse all `.ts` files in `test_cases/`
2. Generate JSON AST files in `ast_output/`
3. Show summary and inspection commands

### Inspect AST Output

```bash
# View formatted JSON
cat ast_output/01_basic_types.json | jq '.'

# View specific function
cat ast_output/01_basic_types.json | jq '.statements[0]'

# Extract all function names
cat ast_output/01_basic_types.json | jq '.statements[].name.text'

# View function parameters with types
cat ast_output/01_basic_types.json | jq '.statements[0].parameters[] | {name: .name.text, type: .type.kind}'

# View return type
cat ast_output/01_basic_types.json | jq '.statements[0].type'
```

---

## Test Categories

### 01_basic_types.ts - Primitive Type Annotations

**Purpose:** Test how parser handles basic TypeScript type annotations

**Functions:**
- `identity_number(x: number): number` - Number types
- `identity_string(s: string): string` - String types
- `identity_bool(b: boolean): boolean` - Boolean types
- `log_message(msg: string): void` - Void return type
- `add(x: number, y: number): number` - Multiple parameters
- `format(prefix: string, value: number): string` - Mixed parameter types

**Key AST Features:**
- Parameter type annotations (`.parameters[].type`)
- Return type annotations (`.type`)
- Multiple parameter handling

**Example Inspection:**
```bash
# View the add function signature
cat ast_output/01_basic_types.json | jq '.statements[] | select(.name.text == "add")'
```

---

### 02_nullable_types.ts - Union Types and Null Handling

**Purpose:** Test nullable types and union type annotations

**Functions:**
- `get_length(s: string | null): number` - Nullable parameter
- `find_first(arr: number[]): number | null` - Nullable return
- `process_value(x: number | string): number` - Union types
- `get_or_default(x: number | undefined, def: number): number` - Undefined handling
- `handle_result(result: string | number | boolean): string` - Multiple union types

**Key AST Features:**
- Union type nodes (`.type.kind === "UnionType"`)
- Union type members (`.type.types[]`)
- Null/undefined in union types

**Example Inspection:**
```bash
# View union type structure
cat ast_output/02_nullable_types.json | jq '.statements[0].parameters[0].type'
```

---

### 03_control_flow.ts - Conditional Branching

**Purpose:** Test control flow with different return paths

**Functions:**
- `abs(x: number): number` - Simple if-else
- `max(a: number, b: number): number` - Both branches return
- `min(a: number, b: number): number` - Ternary operator
- `sign(x: number): string` - Multiple conditions (if-else-if)
- `classify(x: number, y: number): string` - Nested conditionals
- `safe_divide(a: number, b: number): number` - Early return

**Key AST Features:**
- If statements (`.body.statements[] | select(.kind == "IfStatement")`)
- Conditional expressions (ternary)
- Return statements in different branches

**Example Inspection:**
```bash
# View if-statement structure
cat ast_output/03_control_flow.json | jq '.statements[0].body.statements[0]'
```

---

### 04_operators.ts - Binary and Unary Operators

**Purpose:** Test operator parsing and type inference

**Functions:**
- Arithmetic: `add_nums`, `subtract`, `multiply`, `divide`, `power`
- Comparison: `less_than`, `greater_or_equal`, `equals`, `not_equals`
- Logical: `and_op`, `or_op`, `not_op`
- String: `concat`
- Unary: `negate`
- Complex: `complex_expr`

**Key AST Features:**
- Binary expressions (`.kind === "BinaryExpression"`)
- Operator tokens (`.operatorToken.kind`)
- Operator precedence and associativity

**Example Inspection:**
```bash
# View binary operator structure
cat ast_output/04_operators.json | jq '.statements[0].body.statements[0].expression'
```

---

### 05_variables.ts - Variable Declarations and Mutations

**Purpose:** Test variance analysis (const vs let, mutations)

**Functions:**
- `const_variable()` - Immutable const
- `immutable_let()` - Let without reassignment
- `mutable_variable()` - Let with reassignment
- `multiple_mutations()` - Multiple reassignments
- `mixed_variables()` - Both const and mutable let
- `shadowing()` - Variable shadowing
- `increment_pattern()` - Multiple increments

**Key AST Features:**
- Variable declarations (`.kind === "VariableDeclaration"`)
- Const vs let (`.declarationList.flags`)
- Assignments (`.kind === "BinaryExpression"` with `=` operator)

**Example Inspection:**
```bash
# Find all variable declarations
cat ast_output/05_variables.json | jq '.. | select(.kind? == "VariableDeclaration")'
```

---

### 06_objects.ts - Object Types and Interfaces

**Purpose:** Test object type annotations and field access

**Interfaces:**
- `Point { x: number; y: number }`
- `Address { street: string; city: string }`
- `Person { name: string; address: Address }`

**Functions:**
- `get_x(p: Point): number` - Field access
- `set_x(p: Point, value: number): void` - Field mutation
- `distance_from_origin(p: Point): number` - Multiple field accesses
- `process_config(cfg: { host: string; port: number })` - Inline object type
- `get_city(person: Person): string` - Nested object access
- `make_point(x: number, y: number): Point` - Object creation
- `move_point(p: Point, dx: number, dy: number): void` - Multiple mutations

**Key AST Features:**
- Interface declarations (`.kind === "InterfaceDeclaration"`)
- Property signatures (`.members[]`)
- Type references (`.type.kind === "TypeReference"`)
- Property access expressions

**Example Inspection:**
```bash
# View interface structure
cat ast_output/06_objects.json | jq '.statements[] | select(.kind == "InterfaceDeclaration")'

# View property access
cat ast_output/06_objects.json | jq '.. | select(.kind? == "PropertyAccessExpression")'
```

---

### 07_arrays.ts - Array Type Annotations

**Purpose:** Test array types and indexing

**Functions:**
- `first_element(arr: number[]): number` - Array indexing
- `safe_first(arr: number[]): number | null` - Array with nullable return
- `join_strings(arr: string[]): string` - Array iteration
- `get_element(arr: number[], index: number): number` - Parameterized indexing
- `set_element(arr: number[], index: number, value: number): void` - Array mutation
- `array_size(arr: number[]): number` - Array property access
- `get_matrix_element(matrix: number[][], row: number, col: number): number` - 2D arrays
- `get_item_name(items: Item[], index: number): string` - Array of objects

**Key AST Features:**
- Array type nodes (`.type.kind === "ArrayType"`)
- Element type (`.type.elementType`)
- Element access expressions (`.kind === "ElementAccessExpression"`)
- Multi-dimensional arrays

**Example Inspection:**
```bash
# View array type structure
cat ast_output/07_arrays.json | jq '.statements[0].parameters[0].type'

# Find all element access expressions
cat ast_output/07_arrays.json | jq '.. | select(.kind? == "ElementAccessExpression")'
```

---

### 08_loops.ts - Loop Constructs

**Purpose:** Test while loops, for loops, and iteration patterns

**Functions:**
- `count_to_n(n: number): number` - Simple while loop
- `sum_to_n(n: number): number` - While with accumulator
- `sum_array(arr: number[]): number` - For loop over array
- `sum_matrix(matrix: number[][]): number` - Nested loops
- `find_index(arr: number[], target: number): number` - Loop with early return
- `sum_positive(arr: number[]): number` - Conditional accumulation

**Key AST Features:**
- While statements (`.kind === "WhileStatement"`)
- For statements (`.kind === "ForStatement"`)
- Loop initialization, condition, incrementor
- Break patterns (early return)

**Example Inspection:**
```bash
# View while loop structure
cat ast_output/08_loops.json | jq '.statements[0].body.statements[] | select(.kind == "WhileStatement")'

# View for loop structure
cat ast_output/08_loops.json | jq '.. | select(.kind? == "ForStatement")'
```

---

### 09_type_guards.ts - Type Guards and Refinement

**Purpose:** Test typeof checks and type narrowing

**Functions:**
- `double_if_number(x: number | string)` - typeof for number
- `uppercase_if_string(x: number | string)` - typeof for string
- `negate_if_bool(x: boolean | number)` - typeof for boolean
- `describe_type(x: number | string | boolean): string` - Multiple typeof checks
- `string_length_safe(s: string | null): number` - Null check
- `get_value_or_zero(x: number | undefined): number` - Undefined check
- `truthy_to_number(x: number | null | undefined): number` - Truthiness check

**Key AST Features:**
- Typeof expressions (`.kind === "TypeOfExpression"`)
- Equality checks against string literals (type names)
- Null/undefined comparisons
- Type narrowing in branches

**Example Inspection:**
```bash
# Find all typeof expressions
cat ast_output/09_type_guards.json | jq '.. | select(.kind? == "TypeOfExpression")'

# View null comparison
cat ast_output/09_type_guards.json | jq '.. | select(.kind? == "BinaryExpression" and .right.kind? == "NullKeyword")'
```

---

### 10_complex_functions.ts - Combined Features

**Purpose:** Test complex scenarios combining multiple features

**Functions:**
- `calculate_grade(score: number): string` - Multiple branches with mutation
- `compute_stats(numbers: number[]): Stats` - Object, array, mutations
- `safe_operation(a: number | null, b: number | null, op: string)` - Nullable + complex logic
- `factorial(n: number): number` - Recursion pattern
- `compute_area_perimeter(width: number, height: number)` - Multiple local variables
- `process_item(item: { value: number | string }): number` - Type guards + objects

**Key AST Features:**
- Combination of all previous features
- Complex control flow
- Nested types
- Multiple mutations

**Example Inspection:**
```bash
# View complex function structure
cat ast_output/10_complex_functions.json | jq '.statements[0]' | head -100
```

---

## Inspecting Specific AST Nodes

### View All Function Names

```bash
cat ast_output/*.json | jq '.statements[].name.text' | sort | uniq
```

### View All Type Annotations

```bash
# Parameter types
cat ast_output/01_basic_types.json | jq '.statements[].parameters[] | {param: .name.text, type: .type.kind}'

# Return types
cat ast_output/01_basic_types.json | jq '.statements[] | {func: .name.text, returnType: .type.kind}'
```

### Find Specific Node Types

```bash
# Find all BinaryExpressions
cat ast_output/04_operators.json | jq '.. | select(.kind? == "BinaryExpression") | .operatorToken.kind' | sort | uniq

# Find all if statements
cat ast_output/03_control_flow.json | jq '.. | select(.kind? == "IfStatement")' | head -50

# Find all assignments
cat ast_output/05_variables.json | jq '.. | select(.kind? == "BinaryExpression" and .operatorToken.kind? == "EqualsToken")'
```

### Compare Type Annotations

```bash
# Compare parameter vs return types
cat ast_output/01_basic_types.json | jq '.statements[] | {
  name: .name.text,
  params: [.parameters[].type.kind],
  return: .type.kind
}'
```

---

## Using AST Output for Spec Generation

### Extract Function Signature Information

```bash
# Get complete signature info for spec generation
cat ast_output/01_basic_types.json | jq '.statements[0] | {
  name: .name.text,
  parameters: .parameters | map({
    name: .name.text,
    type: .type.kind
  }),
  returnType: .type.kind,
  body: .body.statements | length
}'
```

### Find Functions with Union Types

```bash
# Functions with union type parameters (need special handling)
cat ast_output/02_nullable_types.json | jq '.statements[] | select(.parameters[].type.kind == "UnionType") | .name.text'
```

### Find Functions with Mutations

```bash
# Functions that perform assignments (need variance analysis)
cat ast_output/05_variables.json | jq '.statements[] | select(
  .. | .kind? == "BinaryExpression" and .operatorToken.kind? == "EqualsToken"
) | .name.text'
```

---

## Test Coverage Summary

| Category | File | Functions | Features Tested |
|----------|------|-----------|-----------------|
| Basic Types | `01_basic_types.ts` | 6 | number, string, boolean, void, multiple params |
| Nullable | `02_nullable_types.ts` | 5 | union types, null, undefined |
| Control Flow | `03_control_flow.ts` | 6 | if-else, ternary, early return, nested |
| Operators | `04_operators.ts` | 15 | arithmetic, comparison, logical, unary |
| Variables | `05_variables.ts` | 7 | const, let, mutations, shadowing |
| Objects | `06_objects.ts` | 8 (+3 interfaces) | interfaces, field access, mutations |
| Arrays | `07_arrays.ts` | 8 (+1 interface) | array types, indexing, 2D arrays |
| Loops | `08_loops.ts` | 6 | while, for, nested, accumulation |
| Type Guards | `09_type_guards.ts` | 7 | typeof, null checks, type narrowing |
| Complex | `10_complex_functions.ts` | 6 (+1 interface) | combined features, recursion |

**Total:** 74 functions, 5 interfaces

---

## Next Steps

### 1. Implement Spec Generator

Use the AST output to implement automatic specification generation:

```bash
# Test with simple function
cat ast_output/01_basic_types.json | jq '.statements[0]'
# → Extract: name, parameters with types, return type
# → Generate: req params ; ens return_type spec
```

### 2. Test Translation Pipeline

```bash
# Parse TypeScript → JSON
./parse_all_tests.sh

# Translate JSON → Heifer IR (when spec_generator is implemented)
cd ..
dune exec ts_to_heifer/bin/main.exe test/ast_output/01_basic_types.json
```

### 3. Verify Generated Specs

Feed generated Heifer code to the verifier and check results.

---

## Debugging Tips

### Pretty Print Entire AST

```bash
cat ast_output/01_basic_types.json | jq '.' > /tmp/pretty.json
code /tmp/pretty.json  # or your editor
```

### Find Unknown Node Kinds

```bash
# See all node kinds in a file
cat ast_output/10_complex_functions.json | jq '.. | .kind? | select(. != null)' | sort | uniq
```

### Compare TypeScript vs AST

```bash
# Side by side
code test_cases/01_basic_types.ts ast_output/01_basic_types.json
```

---

## Adding New Tests

1. Create new `.ts` file in `test_cases/`
2. Add functions with type annotations (no JSDoc!)
3. Run `./parse_all_tests.sh`
4. Inspect AST output in `ast_output/`
5. Use for spec generator development

**Template:**
```typescript
// Test N: <Category Name>
// Testing <what feature>

function example_function(param: Type): ReturnType {
  // implementation
}
```

---

## Resources

- **TypeScript AST Explorer:** https://ts-ast-viewer.com/
  - Paste test code to see interactive AST
- **SyntaxKind Reference:** https://typestrong.org/typedoc-auto-docs/typedoc/enums/TypeScript.SyntaxKind.html
  - All possible node kinds
- **Spec Generation Docs:** [../docs/AUTO_SPEC_GENERATION.md](../docs/AUTO_SPEC_GENERATION.md)
  - How to use AST for spec generation

---

## Summary

✅ **10 test files** with **74 functions** covering all major TypeScript features
✅ **JSON AST output** in separate `ast_output/` folder for easy inspection
✅ **Parse script** to regenerate all AST files
✅ **Comprehensive examples** without manual annotations
✅ **Ready for spec generator implementation**

All tests use **TypeScript types only** - perfect for testing automatic specification generation!
