# Implementation Plan: Impure Functions with Global State

## Problem Statement

The current translator treats all function declarations as pure, self-contained units. However, **separation logic's core purpose** is to verify programs with heap effects - functions that read/write shared mutable state.

### Current Limitation
```typescript
let globalCounter: number = 0;

function increment(): void {
  globalCounter = globalCounter + 1;
}
```

Currently translates each function in isolation, ignoring global variable access. This **completely defeats the purpose of Heifer's separation logic verification**.

## Why This Is Critical

Separation logic exists to:
1. **Verify heap safety**: No dangling pointers, memory leaks
2. **Track ownership**: Which function owns which heap cells
3. **Prove correctness**: Functions modify only what they claim in specs
4. **Enable modular verification**: Local reasoning about global effects

Without global state handling, we can't verify ANY of these properties!

## Design Challenges

### Challenge 1: Global Variables in Heifer

**Issue**: Heifer functions are pure lambda abstractions. Global mutable state must be:
- Allocated in the heap (not stack)
- Passed as implicit parameters OR
- Accessed through a global heap context

**Options**:
1. **Heap references**: Translate globals as top-level `ref` allocations
2. **Environment passing**: Thread global environment through all functions
3. **Effect system**: Use Heifer's effect handlers for state

### Challenge 2: Function Specifications

**Issue**: Function specs must declare heap effects!

```typescript
let counter: number = 0;

function increment(): void {
  counter = counter + 1;
}
```

Should translate to:
```ocaml
let counter = ref 0 in
let increment = fun () (*@
  req counter -> ?v;  (* counter points to some value v *)
  ens counter -> v+1  (* counter now points to v+1 *)
@*) ->
  counter := !counter + 1
in ...
```

### Challenge 3: Top-level vs Function-level Variables

**Two scopes**:
1. **Top-level globals**: Visible to all functions
2. **Function-local variables**: Already handled correctly

Need to track both!

## Proposed Implementation

### Phase 1: Track Global Variables ✓ (Straightforward)

**1.1 Add global context to translation state**

```ocaml
type translation_context = {
  (* Existing per-function context *)
  local_ctx: context;

  (* NEW: Shared global context *)
  global_ctx: context;
}
```

**1.2 Collect top-level variable declarations**

Before translating functions, scan top-level for:
```typescript
let globalVar: number = 0;
const globalConst: string = "hello";
```

Store in `global_ctx` with variance and types.

**1.3 Modify variable resolution**

When translating `globalCounter` in a function:
1. Check `local_ctx` first (shadows global)
2. If not found, check `global_ctx`
3. If in `global_ctx`, access as heap reference

### Phase 2: Translate Globals as Heap References ✓ (Core Feature)

**2.1 Top-level allocation**

```typescript
let counter: number = 0;
let total: number = 0;

function increment() { ... }
```

Translates to:
```ocaml
let counter = ref 0 in
let total = ref 0 in
let increment = fun () (*@ ... @*) -> ... in
...
```

**2.2 Function bodies use global refs**

```typescript
function increment(): void {
  globalCounter = globalCounter + 1;
}
```

Translates to:
```ocaml
let increment = fun () (*@
  req globalCounter -> ?v;
  ens globalCounter -> v+1
@*) ->
  let tmp = !globalCounter in
  globalCounter := (tmp + 1)
in
```

### Phase 3: Generate Separation Logic Specs ⚠️ (Complex!)

**3.1 Infer required heap cells**

For each function, analyze:
- Which globals are **read**: Add to `req` as `var -> ?v`
- Which globals are **written**: Add to `ens` as `var -> new_expr`

**3.2 Separate pure and heap assertions**

Heifer specs have form:
```
req pi /\ kappa; ens pi' /\ kappa'
```

Where:
- `pi`, `pi'` are **pure** assertions (e.g., `x > 0`)
- `kappa`, `kappa'` are **heap** assertions (e.g., `counter -> 5`)

**3.3 Handle complex heap patterns**

```typescript
function swap(x: number): number {
  const temp = sharedValue;
  sharedValue = x;
  return temp;
}
```

Spec should be:
```ocaml
(*@
  req sharedValue -> ?old /\ x:int;
  ens sharedValue -> x /\ res = old
@*)
```

### Phase 4: Integration with Existing Code

**4.1 Modify `translate_program`**

```ocaml
let translate_program json =
  (* Step 1: Collect globals *)
  let globals = collect_global_variables json in

  (* Step 2: Create global context *)
  let global_ctx = create_global_context globals in

  (* Step 3: Allocate global refs *)
  let global_allocations = translate_global_allocations globals in

  (* Step 4: Translate functions with global context *)
  let functions = translate_functions json global_ctx in

  (* Step 5: Nest everything *)
  nest_lets global_allocations functions
```

**4.2 Update `translate_function_decl`**

Add `global_ctx` parameter:
```ocaml
and translate_function_decl global_ctx json continuation =
  let func_ctx = create_context () in

  (* Combine local and global contexts for variable resolution *)
  let combined_ctx = { local = func_ctx; global = global_ctx } in

  (* Rest of translation uses combined_ctx *)
  ...
```

**4.3 Update `translate_expr` variable resolution**

```ocaml
| "Identifier" ->
    let name = get_identifier json in

    (* Check local context first *)
    if has_local_var func_ctx name then
      (* Use existing logic *)
      ...
    else if has_global_var global_ctx name then
      (* Global variable - always mutable heap reference *)
      { core_desc = CRead name;
        core_type = get_type global_ctx name }
    else
      failwith ("Undefined variable: " ^ name)
```

## Implementation Steps (Prioritized)

### Step 1: Foundation (Required)
1. Add `global_ctx` field to translation state
2. Implement `collect_global_variables`
3. Test with simple read-only global

### Step 2: Basic Writes (Required)
4. Modify variable resolution to check global context
5. Translate global assignments as `CWrite`
6. Test with increment example

### Step 3: Top-level Structure (Required)
7. Generate top-level `let global = ref value in ...`
8. Nest all functions inside global allocations
9. Test complete translation

### Step 4: Specifications (Important but can defer)
10. Infer heap footprint (which globals accessed)
11. Generate `kappa` for `req` (points-to before)
12. Generate `kappa` for `ens` (points-to after)
13. Test specification generation

### Step 5: Advanced Features (Nice to have)
14. Handle global shadowing
15. Support const globals (immutable heap cells)
16. Optimize: globals only read don't need `ens` clause

## Example Translation

### Input (TypeScript)
```typescript
let counter: number = 0;

function increment(): void {
  counter = counter + 1;
}

function getCounter(): number {
  return counter;
}
```

### Output (Heifer IR)
```ocaml
let counter = ref 0 in
let increment = fun () (*@
  req counter -> ?v;
  ens counter -> v+1
@*) ->
  let tmp = !counter in
  counter := (tmp + 1)
in
let getCounter = fun () (*@
  req counter -> ?v;
  ens counter -> v /\ res = v
@*) ->
  !counter
in
()
```

## Testing Strategy

### Test 1: Read-only global
```typescript
const PI: number = 3.14;
function area(r: number): number {
  return PI * r * r;
}
```

### Test 2: Single mutable global
```typescript
let counter: number = 0;
function increment(): void {
  counter = counter + 1;
}
```

### Test 3: Multiple globals
```typescript
let x: number = 0;
let y: number = 0;
function swap(): void {
  const temp = x;
  x = y;
  y = temp;
}
```

### Test 4: Conditional global access
```typescript
let flag: boolean = false;
function toggle(): void {
  flag = !flag;
}
```

## Open Questions

1. **Q**: Should we support global *functions* calling other global functions?
   **A**: Yes, but defer - needs call graph analysis for specs

2. **Q**: How to handle globals not yet allocated when function defined?
   **A**: All globals must be allocated before any function definitions (enforce ordering)

3. **Q**: What about global arrays/objects?
   **A**: Skip for now - already skipping arrays/objects in general

4. **Q**: How to specify frame conditions (unmodified globals)?
   **A**: Heifer's frame rule handles this - only mention modified globals in spec

## Success Criteria

**Minimum viable**:
- ✅ Translate top-level `let`/`const` declarations
- ✅ Resolve global variables in function bodies
- ✅ Generate correct heap reads (`CRead`) and writes (`CWrite`)

**Full feature**:
- ✅ Generate separation logic specs with heap assertions
- ✅ Handle multiple globals correctly
- ✅ Support both reads and writes

**Stretch goals**:
- ⭐ Infer minimal footprint (only mention accessed globals)
- ⭐ Optimize read-only globals
- ⭐ Support global shadowing
