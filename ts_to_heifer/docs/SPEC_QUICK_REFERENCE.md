# Automatic Specification Generation - Quick Reference

## Core Idea

**Extract formal verification specifications from TypeScript's type system automatically.**

Just like variance analysis detects mutable variables, specification generation detects type constraints and converts them to verification conditions.

---

## Type Mappings

### Primitive Types

| TypeScript | Heifer Type | Spec Example |
|------------|-------------|--------------|
| `number` | `#int` | `x:#int` |
| `string` | `#string` | `s:#string` |
| `boolean` | `#bool` | `b:#bool` |
| `void` | `#unit` | `res:#unit` |
| `null` | `#unit` | `x:#unit` |
| `undefined` | `#unit` | `x:#unit` |
| `any` | `#any` | `x:#any` |

### Composite Types

| TypeScript | Heifer Type | Spec Example |
|------------|-------------|--------------|
| `number \| string` | `(#int \| #string)` | `x:(#int \| #string)` |
| `number[]` | `#list<int>` | `arr:#list<int>` |
| `{x: number}` | `{x: int ref}` | `p:#point /\ p.x \|-> v` |
| `(x: number) => string` | `int -> string` | `f:(#int -> #string)` |

---

## Function Specification Pattern

### Basic Pattern

**TypeScript:**
```typescript
function f(param1: Type1, param2: Type2): ReturnType {
  // body
}
```

**Generated Heifer Spec:**
```ocaml
let f param1 param2 = (* body *)
 (*@ req param1:#Type1 /\ param2:#Type2 ;
     ens res:#ReturnType @*)
```

### With Value Constraints

**TypeScript:**
```typescript
function add(x: number, y: number): number {
  return x + y;
}
```

**Generated Heifer Spec:**
```ocaml
let add x y = (x + y)
 (*@ req x:#int /\ y:#int ;
     ens res:#int /\ res = (x + y) @*)
```

### With Conditionals

**TypeScript:**
```typescript
function abs(x: number): number {
  if (x < 0) return -x;
  return x;
}
```

**Generated Heifer Spec:**
```ocaml
let abs x =
  if (x < 0) then -x else x
 (*@ req x:#int ;
     ens (x < 0 => res:#int /\ res = -x) /\
         (x >= 0 => res:#int /\ res = x) @*)
```

---

## Specification Components

### Precondition (req)

**What:** Constraints that must hold when function is called

**From TypeScript:**
- Parameter types → type constraints
- Nullable parameters → union types
- Object parameters → heap formulas

**Example:**
```typescript
function process(x: number, s: string | null): void
```
→
```ocaml
(*@ req x:#int /\ s:(#string | #unit) ; ... @*)
```

### Postcondition (ens)

**What:** Constraints that hold when function returns

**From TypeScript:**
- Return type → result type constraint
- Return expression → value constraint
- Conditional returns → implications

**Example:**
```typescript
function double(x: number): number { return x * 2; }
```
→
```ocaml
(*@ ... ; ens res:#int /\ res = (x * 2) @*)
```

### Heap Formulas

**What:** Separation logic formulas for object mutations

**From TypeScript:**
- Object fields → `|->` (points-to)
- Multiple objects → `*` (separating conjunction)

**Example:**
```typescript
function setX(p: {x: number}, val: number): void { p.x = val; }
```
→
```ocaml
(*@ req p:#point /\ p.x |-> old_x /\ val:#int ;
    ens p.x |-> val @*)
```

---

## Common Patterns

### Pattern 1: Pure Function

```typescript
function square(x: number): number {
  return x * x;
}
```
↓
```ocaml
let square x = (x * x)
 (*@ req x:#int ; ens res:#int /\ res = (x * x) @*)
```

### Pattern 2: Nullable Return

```typescript
function findFirst(arr: number[]): number | null {
  return arr.length > 0 ? arr[0] : null;
}
```
↓
```ocaml
let findFirst arr =
  match arr with
  | [] -> null
  | x :: _ -> x
 (*@ req arr:#list<int> ;
     ens (arr = [] => res:#unit) /\
         (arr <> [] => res:#int /\ res = hd(arr)) @*)
```

### Pattern 3: Object Mutation

```typescript
interface Counter { count: number }
function increment(c: Counter): void {
  c.count = c.count + 1;
}
```
↓
```ocaml
type counter = { count: int ref }
let increment c = c.count := (!c.count + 1)
 (*@ req c:#counter /\ c.count |-> n ;
     ens c.count |-> (n + 1) @*)
```

### Pattern 4: Type Guard

```typescript
function processValue(x: number | string): number {
  if (typeof x === "number") {
    return x + 1;
  }
  return x.length;
}
```
↓
```ocaml
let processValue x =
  if (typeof x = "number") then
    x + 1
  else
    string_length x
 (*@ req x:(#int | #string) ;
     ens (x:#int => res:#int /\ res = x + 1) /\
         (x:#string => res:#int /\ res = |x|) @*)
```

### Pattern 5: Array Processing

```typescript
function sumArray(arr: number[]): number {
  let sum = 0;
  for (let i = 0; i < arr.length; i++) {
    sum += arr[i];
  }
  return sum;
}
```
↓
```ocaml
let rec sumArray arr =
  match arr with
  | [] -> 0
  | x :: xs -> x + sumArray xs
 (*@ req arr:#list<int> ;
     ens res:#int /\ res = sum(arr) @*)
```

---

## Implementation Checklist

### Phase 1: Basic Specs
- [ ] Create `spec_generator.ml`
- [ ] Map TypeScript types → Heifer types
- [ ] Generate preconditions from parameters
- [ ] Generate postconditions from return type
- [ ] Attach specs to function declarations

### Phase 2: Value Constraints
- [ ] Analyze return expressions
- [ ] Extract value constraints (res = expr)
- [ ] Handle simple arithmetic
- [ ] Handle string operations

### Phase 3: Control Flow
- [ ] Detect if-else returns
- [ ] Generate conditional postconditions
- [ ] Use implications (cond => result)
- [ ] Handle multiple branches

### Phase 4: Objects & Heap
- [ ] Track object field accesses
- [ ] Generate points-to formulas
- [ ] Track mutations
- [ ] Use separation logic

### Phase 5: Advanced
- [ ] Loop invariants
- [ ] Recursive functions
- [ ] Exception specifications
- [ ] Complex types

---

## Testing Strategy

### Test 1: Primitives
```typescript
function id(x: number): number { return x; }
```
Expected spec: `req x:#int ; ens res:#int /\ res = x`

### Test 2: Operations
```typescript
function add(x: number, y: number): number { return x + y; }
```
Expected spec: `req x:#int /\ y:#int ; ens res:#int /\ res = (x + y)`

### Test 3: Conditionals
```typescript
function max(a: number, b: number): number {
  return a > b ? a : b;
}
```
Expected spec: `req a:#int /\ b:#int ; ens (a > b => res = a) /\ (a <= b => res = b)`

### Test 4: Nullable
```typescript
function getOrDefault(x: number | null, d: number): number {
  return x !== null ? x : d;
}
```
Expected spec: `req x:(#int | #unit) /\ d:#int ; ens (x <> #unit => res = x) /\ (x = #unit => res = d)`

### Test 5: Objects
```typescript
interface Point { x: number }
function setX(p: Point, v: number): void { p.x = v; }
```
Expected spec: `req p:#point /\ p.x |-> _ /\ v:#int ; ens p.x |-> v`

---

## Debugging Commands

### View TypeScript AST
```bash
node parser/dist/parser.js file.ts file.json
cat file.json | jq '.statements[0]'
```

### Test Translation
```bash
./translate.sh examples/test.ts
```

### Verify in Heifer
```bash
./translate.sh examples/test.ts > test.ml
heifer verify test.ml
```

---

## Key Benefits

1. **No manual annotations** - TypeScript types are sufficient
2. **Type safety** - TypeScript ensures well-typed inputs
3. **Verification** - Heifer proves correctness properties
4. **Gradual** - Start with types, add JSDoc for complex invariants

---

## Resources

- **Full Design:** [AUTO_SPEC_GENERATION.md](AUTO_SPEC_GENERATION.md)
- **Implementation Guide:** [GETTING_STARTED_AUTO_SPEC.md](GETTING_STARTED_AUTO_SPEC.md)
- **Node Mappings:** [NODE_TRANSLATION.md](NODE_TRANSLATION.md)
- **Project Status:** [STATUS.md](../STATUS.md)

---

## Quick Win Example

**Input (TypeScript with just type annotations):**
```typescript
function multiply(x: number, y: number): number {
  return x * y;
}
```

**Output (Heifer with auto-generated spec):**
```ocaml
let multiply x y = (x * y)
 (*@ req x:#int /\ y:#int ;
     ens res:#int /\ res = (x * y) @*)
```

**Verification:** ✅ Heifer proves this is correct!

**No manual work needed** - the spec is extracted automatically from TypeScript types! 🎉
