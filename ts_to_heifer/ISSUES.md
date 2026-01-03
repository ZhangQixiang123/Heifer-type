# TypeScript to Heifer Translation Issues

## Method Call Translation Problem

### Issue
Method calls like `value.toString()` are not being translated correctly.

**Current behavior:**
```ocaml
let format prefix value = let tmp1 = toString in
(prefix + tmp1)
```

**Expected behavior:**
Should properly represent the method call on the object.

### Root Cause
TypeScript's object-oriented method calls don't map directly to Heifer's functional representation:

1. **In TypeScript**: `value.toString()` is a method call on the `value` object
   - `value` is a number (type: `number`)
   - `toString` is a method of the number type
   - The call returns a string

2. **Current Translation**:
   - Extracts method name: `"toString"`
   - Loses the receiver object: `value`
   - Creates `CFunCall("toString", [])` - calling toString with no arguments
   - Result: just the identifier `toString` instead of a call

### Design Considerations

**Option 1: Treat methods as functions with object as first argument**
```ocaml
let format prefix value = let tmp1 = toString value in
(prefix + tmp1)
```
- Pros: Simple, functional representation
- Cons: Doesn't match TypeScript semantics (toString is not a standalone function)

**Option 2: Built-in conversion functions**
Recognize common methods like `toString()` and translate to built-in conversions:
```ocaml
let format prefix value = let tmp1 = int_to_string value in
(prefix + tmp1)
```
- Pros: Semantically correct, matches verification needs
- Cons: Requires special-casing many methods

**Option 3: Property access + application**
Preserve the property access and then apply it:
```ocaml
let format prefix value = let tmp1 = (value.toString)() in
(prefix + tmp1)
```
- Pros: Matches TypeScript structure
- Cons: Requires full object/record support in translation

**Option 4: Skip for now**
Mark method calls as unsupported until we have proper object support:
- Pros: Honest about limitations
- Cons: Many tests will fail

### Current Status
- Method calls are partially working (test passes)
- Output is semantically incorrect
- Need to decide on proper representation strategy

### Test Case
From [test_cases/01_basic_types.ts:30-32](ts_to_heifer/test/test_cases/01_basic_types.ts#L30-L32):
```typescript
function format(prefix: string, value: number): string {
  return prefix + value.toString();
}
```

### Related Files
- [translator.ml:417-464](ts_to_heifer/lib/translator.ml#L417-L464) - CallExpression handling
- [translator.ml:404-411](ts_to_heifer/lib/translator.ml#L404-L411) - PropertyAccessExpression handling
