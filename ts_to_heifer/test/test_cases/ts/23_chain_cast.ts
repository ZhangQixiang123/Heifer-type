type Ref<T> = { value: T };

// Test 23: Multi-hop downcast chain — progressive frame rule applications
//
// Subtype chain: 10 <: number <: Object
// x's narrowing survives through TWO function calls:
//   - check() with empty footprint
//   - clearY(y) with non-trivial footprint touching y, not x

/**
 * Pure validation — empty heap footprint.
 * @require emp
 * @ensure emp
 */
function check(): void { }

/**
 * Resets y to 0. Non-empty footprint: modifies y only.
 * @require y -> a
 * @ensure y -> 0
 */
function clearY(y: Ref<Object>): void {
    y.value = 0;
}

/**
 * TypeScript rejects: x.value is Object after check() and clearY() calls.
 * Heifer proves safe via chained frame rule:
 *
 *   {x -> v1 * y -> v2}
 *   x.value = 10;            // {x -> 10 * y -> v2}
 *   check();                 // spec: {emp} → {emp}
 *                            // frame: ENTIRE heap preserved
 *                            // {x -> 10 * y -> v2}
 *   y.value = 20;            // {x -> 10 * y -> 20}
 *   clearY(y);               // spec: {y -> a} → {y -> 0}
 *                            // frame: x -> 10 NOT in footprint
 *                            // {x -> 10 * y -> 0}
 *   return x.value;          // read 10, 10 <: number ✓
 *   {x -> 10 * y -> 0 /\ res = 10}
 *
 * @require x -> v1 * y -> v2
 * @ensure x -> 10 * y -> 0 /\ res = 10
 */
function chainCast(x: Ref<Object>, y: Ref<Object>): number {
    x.value = 10;
    check();
    y.value = 20;
    clearY(y);
    return x.value;
}
