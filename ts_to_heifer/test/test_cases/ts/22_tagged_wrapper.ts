type Ref<T> = { value: T };

// Test 22: Tagged container — downcast via frame rule with non-trivial footprint
//
// Subtype chain: 42 <: number <: Object
// The downcast Object → number is proven safe by:
//   1. Writing 42 (a number) to data (typed Object)
//   2. Calling label(tag) — modifies tag, NOT data
//   3. Frame rule preserves data -> 42
//   4. Reading data as number — safe: 42 IS a number

/**
 * Labels a tag cell. Non-empty heap footprint.
 * @require tag -> t
 * @ensure tag -> 1
 */
function label(tag: Ref<number>): void {
    tag.value = 1;
}

/**
 * TypeScript rejects: x.value has type Object after label() call.
 * Heifer proves safe: frame rule preserves data -> 42.
 *
 * Verification trace:
 *   {data -> d * tag -> t}
 *   data.value = 42;           // {data -> 42 * tag -> t}
 *   label(tag);                // spec: {tag -> t} → {tag -> 1}
 *                              // frame: data -> 42 NOT in footprint
 *                              // {data -> 42 * tag -> 1}
 *   return data.value;         // read 42, 42 <: number ✓
 *   {data -> 42 * tag -> 1 /\ res = 42}
 *
 * @require data -> d * tag -> t
 * @ensure data -> 42 * tag -> 1 /\ res = 42
 */
function tagAndCast(data: Ref<Object>, tag: Ref<number>): number {
    data.value = 42;
    label(tag);
    return data.value;
}
