# TypeScript to Heifer: Command Reference

## Quick Commands

### Full Pipeline (Parse + Translate + Verify)

```bash
./verify.sh <input.ts>
```

**Example:**
```bash
./verify.sh test/test_cases/01_basic_types.ts
```

This runs all three phases:
1. Parse TypeScript to JSON AST
2. Translate JSON to Heifer IR
3. Run Heifer verification

---

## Individual Commands

### 1. Parse Only (TypeScript → JSON)

```bash
node parser/dist/parser.js <input.ts> <output.json>
```

**Example:**
```bash
node parser/dist/parser.js test/test_cases/01_basic_types.ts test/ast_output/01_basic_types.json
```

### 2. Translate Only (JSON → Heifer IR)

```bash
cd .. && dune exec ts_to_heifer/bin/main.exe <input.json>
```

**Example:**
```bash
cd .. && dune exec ts_to_heifer/bin/main.exe ts_to_heifer/test/ast_output/01_basic_types.json
```

### 3. Verify Only (JSON → Verification)

```bash
cd .. && dune exec ts_to_heifer/bin/verify.exe <input.json>
```

**Example:**
```bash
cd .. && dune exec ts_to_heifer/bin/verify.exe ts_to_heifer/test/ast_output/01_basic_types.json
```

---

## One-Liner Commands

### From Repository Root

```bash
# Full pipeline from .ts file
cd ts_to_heifer && ./verify.sh test/test_cases/01_basic_types.ts

# Translate existing JSON
dune exec ts_to_heifer/bin/main.exe ts_to_heifer/test/ast_output/01_basic_types.json

# Verify existing JSON
dune exec ts_to_heifer/bin/verify.exe ts_to_heifer/test/ast_output/01_basic_types.json
```

### From ts_to_heifer Directory

```bash
# Full pipeline
./verify.sh test/test_cases/01_basic_types.ts

# Just translate
./translate.sh test/test_cases/01_basic_types.ts

# Parse TypeScript
node parser/dist/parser.js test/test_cases/01_basic_types.ts test/test_cases/01_basic_types.json

# Translate JSON
../_build/default/ts_to_heifer/bin/main.exe test/ast_output/01_basic_types.json

# Verify JSON
../_build/default/ts_to_heifer/bin/verify.exe test/ast_output/01_basic_types.json
```

---

## Advanced Usage

### Custom Output Location

```bash
# Parse to custom location
node parser/dist/parser.js input.ts custom/output.json

# Translate custom JSON
dune exec ts_to_heifer/bin/main.exe custom/output.json

# Verify custom JSON
dune exec ts_to_heifer/bin/verify.exe custom/output.json
```

### Suppress Warnings

```bash
# Suppress JSDoc parsing warnings
./verify.sh test/test_cases/01_basic_types.ts 2>/dev/null
```

### Save Output to File

```bash
# Save verification results
./verify.sh test/test_cases/01_basic_types.ts > results.txt 2>&1
```

---

## Using Direct Build Artifacts

If you prefer using the built executables directly:

```bash
# From repository root
_build/default/ts_to_heifer/bin/main.exe ts_to_heifer/test/ast_output/01_basic_types.json

_build/default/ts_to_heifer/bin/verify.exe ts_to_heifer/test/ast_output/01_basic_types.json
```

---

## Examples with Different Test Cases

### Basic Types
```bash
./verify.sh test/test_cases/01_basic_types.ts
```

### Control Flow
```bash
./verify.sh test/test_cases/03_control_flow.ts
```

### Impure Functions (with state)
```bash
./verify.sh test/test_cases/11_impure_functions.ts
```

---

## Troubleshooting

### Parser Not Found
```bash
cd parser
npm install
npm run build
cd ..
```

### Build Errors
```bash
cd ..
dune clean
dune build ts_to_heifer/bin/main.exe
dune build ts_to_heifer/bin/verify.exe
cd ts_to_heifer
```

### Permission Denied
```bash
chmod +x verify.sh
chmod +x translate.sh
```

---

## Understanding the Output

### Phase 1: Parser Output
```
Parsing <file>.ts...
✓ AST written to <file>.json
  Statements: N
```

### Phase 2: Translator Output
```
=== Translation Successful ===

Heifer IR:
let identity_number = fun x -> x in
...

Type: unit
```

### Phase 3: Verification Output
```
Function 1: identity_number
------------------------------------------------------------
Signature:
  fun identity_number(x: int) : int

Body:
  x

Verification:
  Inferred spec: ens res=x
  ✓ VERIFICATION PASSED
  Result: true
```

---

## Quick Reference Table

| Task | Command |
|------|---------|
| **Full pipeline** | `./verify.sh <file>.ts` |
| **Parse only** | `node parser/dist/parser.js <file>.ts <file>.json` |
| **Translate only** | `dune exec ts_to_heifer/bin/main.exe <file>.json` |
| **Verify only** | `dune exec ts_to_heifer/bin/verify.exe <file>.json` |
| **Build all** | `cd .. && dune build` |
| **Clean build** | `cd .. && dune clean && dune build` |

