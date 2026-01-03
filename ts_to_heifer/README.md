# TypeScript to Heifer Translator

Translates TypeScript code to Heifer IR for verification using Heifer's actual type definitions.

## Key Achievement

✅ **Uses Heifer's real types** - Not copies! Directly imports from:
- `Hipcore_common.Types` (typ, binder)  
- `Hipcore_typed.Typed_core_ast` (core_lang, pi, kappa, staged_spec)

This guarantees the output is compatible with Heifer's verification pipeline.

## Quick Start

```bash
# From ts_to_heifer directory
./translate.sh examples/simple.ts
```

This runs the complete pipeline:
1. **Phase 1**: TypeScript → JSON AST (using TypeScript Compiler API)
2. **Phase 2**: JSON AST → Heifer IR (using OCaml translator)

## Building

```bash
cd /Users/fzjjs/Documents/Separation\ Type/Heifer-type
eval $(opam env --switch=default)
dune build ts_to_heifer
```

## Manual Usage

### Parse TypeScript to JSON
```bash
node parser/dist/parser.js examples/simple.ts examples/simple.json
```

### Translate JSON to Heifer IR
```bash
cd ..  # Go to Heifer-type root
dune exec ts_to_heifer/bin/main.exe ts_to_heifer/examples/simple.json
```

## Example

**Input TypeScript** (`examples/simple.ts`):
```typescript
let x: number = 10;
x = x + 5;
```

**Output Heifer IR**:
```ocaml
let x = ref 10 in
x := (x + 5)
```

**Type**: `unit`

## Implementation Status

### ✅ Working
- Binary operators (+, -, *, /, <, >, <=, >=, ===, !==, &&, ||)
- Constants (numbers, strings, booleans)
- Variable declarations with variance analysis
- Mutations (CWrite) with variance checking
- Control flow (if/else → CIfElse)
- **Integration with Heifer's types and pretty printer**

### 📝 TODO
- Functions and lambdas
- Loops (desugar to recursion)
- Objects and classes
- Arrays
- JSDoc → staged_spec (verification annotations)

## Project Structure

```
Heifer-type/ts_to_heifer/
├── lib/
│   ├── translator.ml       # Main translation logic
│   └── dune                # Links to Heifer libraries
├── bin/
│   └── main.ml             # CLI with Heifer pretty printer
├── parser/                 # Phase 1: TypeScript → JSON
│   ├── src/parser.ts
│   └── dist/
├── examples/
│   ├── simple.ts
│   └── simple.json
├── translate.sh            # Complete pipeline script
└── README.md
```

## Architecture

```
TypeScript Source (.ts)
    ↓
[TypeScript Compiler API - Node.js]
    ↓
JSON AST (.json)
    ↓
[OCaml Translator]
    - Uses: Hipcore_typed.Typed_core_ast
    - Variance analysis
    - Mutation tracking
    ↓
Heifer IR (core_lang)
    ↓
[Hipcore_typed.Pretty]
    ↓
Pretty-printed Heifer code
    ↓
[Heifer Verifier] ← Ready for this step!
```

## Key Features

### Variance Analysis
Automatically detects mutable variables:
- `const x = 10` or `let x = 10` (never reassigned) → immutable
- `let x = 10; x = 20` → mutable (`ref` allocation)

**Example**:
```typescript
let x = 10;    // Detected as mutable
x = x + 1;     // Assignment found
```

Translates to:
```ocaml
let x = ref 10 in    (* Allocated as reference *)
x := (x + 1)         (* Mutation via assignment *)
```

### Type Compatibility
Generated IR uses Heifer's exact types:
- `core_lang` - Core expression language
- `pi` - Pure formulas (conditions)
- `kappa` - Heap formulas
- `staged_spec` - Specifications

This ensures seamless integration with Heifer's verification pipeline.
