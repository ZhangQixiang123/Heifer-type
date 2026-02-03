# Separation Logic Verification: Test Case Summary

This document summarizes test cases demonstrating key properties of the TypeScript separation logic verification system.

## System Overview

The verifier checks TypeScript functions against JSDoc specifications using separation logic:
- `@require P` - precondition (what the function needs)
- `@ensure Q` - postcondition (what the function guarantees)
- `x -> v` - points-to assertion (location x holds value v)
- `P * Q` - separating conjunction (P and Q describe disjoint heap regions)

## 1. Frame Rule Preservation

**Property**: Unmodified heap cells are automatically preserved.

```typescript
// File: 13_dll.ts
/**
 * Update one node, preserve the other (frame rule test)
 * @require n1_val -> v1 * n2_val -> v2
 * @ensure n1_val -> 42 * n2_val -> v2
 */
function update_with_frame_true(): void {
  n1_val = 42;
}
```

**What it demonstrates**:
- Precondition requires two heap cells: `n1_val` and `n2_val`
- Code only modifies `n1_val`
- Postcondition correctly states `n2_val -> v2` is preserved (frame)
- The verifier automatically infers the frame from biabduction

---

## 2. Read-Modify-Write Pattern

**Property**: Sequential heap operations compose correctly.

```typescript
// File: 05_variables.ts
/**
 * Increment global
 * @require globalVar -> v
 * @ensure globalVar -> v + 1
 */
function incrementGlobal_true(): void {
  globalVar = globalVar + 1;
}
```

**What it demonstrates**:
- Reads current value `v` from `globalVar`
- Computes `v + 1`
- Writes result back to `globalVar`
- The spec captures the precise relationship between old and new values

---

## 3. Multiple Sequential Updates

**Property**: Chained updates accumulate correctly.

```typescript
// File: 05_variables.ts
/**
 * Multiple increments to global
 * @require globalVar -> v
 * @ensure globalVar -> v + 3
 */
function tripleIncrement_true(): void {
  globalVar = globalVar + 1;
  globalVar = globalVar + 1;
  globalVar = globalVar + 1;
}
```

**What it demonstrates**:
- Three consecutive increments
- Forward verifier tracks state through each statement
- Final spec correctly captures `v + 3` relationship

---

## 4. Swap with Temporary Variable

**Property**: Complex multi-cell operations with local variables.

```typescript
// File: 05_variables.ts
/**
 * Swap two globals
 * @require globalVar -> v1 * globalVar2 -> v2
 * @ensure globalVar -> v2 * globalVar2 -> v1
 */
function swapGlobals_true(): void {
  const temp: number = globalVar;
  globalVar = globalVar2;
  globalVar2 = temp;
}
```

**What it demonstrates**:
- Separating conjunction `*` for two disjoint heap cells
- Local variable `temp` doesn't appear in spec (stack, not heap)
- Values are correctly swapped between locations

---

## 5. DLL Link Operation

**Property**: Bidirectional pointer updates for doubly-linked structures.

```typescript
// File: 13_dll.ts
/**
 * Link two nodes: n1.next = n2, n2.prev = n1
 * @require n1_next -> x1 * n2_prev -> p2
 * @ensure n1_next -> 2 * n2_prev -> 1
 */
function link_nodes_true(): void {
  n1_next = 2;  // n1.next points to n2 (id=2)
  n2_prev = 1;  // n2.prev points to n1 (id=1)
}
```

**What it demonstrates**:
- Models DLL nodes using separate heap cells for each field
- Updates must be coordinated (both directions)
- Integer IDs represent node addresses (1=n1, 2=n2, 0=null)

---

## 6. Negative Test: Incorrect Increment Spec

**Property**: Verifier correctly rejects specifications that don't match behavior.

```typescript
// File: 05_variables.ts
/**
 * Wrong increment spec: claims no change (should fail)
 * @require globalVar -> v
 * @ensure globalVar -> v
 */
function incrementWrong_false(): void {
  globalVar = globalVar + 1;  // Actually changes value!
}
```

**What it demonstrates**:
- Spec claims `globalVar` is unchanged (`v -> v`)
- Code actually increments (`v -> v + 1`)
- Verifier correctly rejects: inferred `v + 1` does not entail declared `v`

---

## 7. Negative Test: Incomplete Update

**Property**: Partial updates detected as specification violations.

```typescript
// File: 13_dll.ts
/**
 * Incomplete link - only updates one pointer (should fail)
 * @require n1_next -> x1 * n2_prev -> p2
 * @ensure n1_next -> 2 * n2_prev -> 1
 */
function link_incomplete_false(): void {
  n1_next = 2;
  // Missing: n2_prev = 1
}
```

**What it demonstrates**:
- Spec promises both pointers are updated
- Code only updates `n1_next`
- `n2_prev` still has value `p2`, not `1`
- Strict entailment checking catches this mismatch

---

## 8. Return Value with Heap Preservation

**Property**: Functions can return values while preserving heap state.

```typescript
// File: 11_impure_functions.ts
/**
 * Read global state
 * @require globalCounter -> v
 * @ensure globalCounter -> v /\ res = v
 */
function getCounter_true(): number {
  return globalCounter;
}
```

**What it demonstrates**:
- Pure conjunction `/\` combines heap and value assertions
- `globalCounter -> v` asserts heap is unchanged
- `res = v` constrains the return value
- Read operation doesn't consume the heap cell

---

## 9. Two Globals with Parameter

**Property**: Parameters flow correctly through specifications.

```typescript
// File: 11_impure_functions.ts
/**
 * Modify two globals: add value and increment count
 * @require total -> t * count -> c
 * @ensure total -> t + value * count -> c + 1
 */
function addToAverage_true(value: number): void {
  total = total + value;
  count = count + 1;
}
```

**What it demonstrates**:
- Parameter `value` appears in postcondition
- Two independent updates to different heap cells
- Each cell tracks its own transformation

---

## 10. Negative Test: Wrong Return Value

**Property**: Verifier checks return value constraints.

```typescript
// File: 11_impure_functions.ts
/**
 * Wrong read spec: claims different value (should fail)
 * @require globalCounter -> v
 * @ensure globalCounter -> v /\ res = 0
 */
function getCounter_wrong_false(): number {
  return globalCounter;  // Returns v, not 0
}
```

**What it demonstrates**:
- Spec claims `res = 0` regardless of `v`
- Code actually returns `v`
- Unless `v = 0`, this is a contradiction
- Verifier rejects because `res = v` doesn't entail `res = 0`

---

## Verification Architecture

```
TypeScript + JSDoc     JSON AST      OCaml Core     SL Spec
    Source      -->    Parser    -->  Translator --> Forward
                                                      Verifier
                                                         |
                                                         v
                                                    Entailment
                                                      Check
                                                         |
                                              +----+----+----+
                                              |              |
                                            Valid        Invalid
```

### Key Components:

1. **Forward Verifier** (`sl_forward.ml`): Computes inferred specification from code
2. **Biabduction** (`biab.ml`): Extracts frame from precondition matching
3. **Entailment** (`sl_entail.ml`): Checks `inferred * frame |- declared`
4. **Strict Context Check**: Validates biabduction equalities against known facts

---

## Test Results Summary

| Category | Tests | Pass | Fail (Expected) |
|----------|-------|------|-----------------|
| Variable mutations | 11 | 8 | 3 |
| Impure functions | 10 | 7 | 3 |
| DLL operations | 10 | 8 | 2 |
| **Total** | **31** | **23** | **8** |

All tests behave correctly: positive tests verify, negative tests are rejected.
