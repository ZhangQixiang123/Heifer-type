type Ref<T> = { value: T };

// Test 21: Flow-sensitive type narrowing via Hoare logic
// These programs are REJECTED by TypeScript but SAFE per separation logic
//
// Key insight: The frame rule preserves heap cells across function calls
// with empty heap footprint, enabling type narrowing that TypeScript cannot do.

/**
 * Pure logging function — no heap effect
 * @require emp
 * @ensure emp
 */
function log(msg: string): void { }

/**
 * Write 42 to x, call log (which has empty footprint), then read x back.
 * TypeScript rejects this because it loses x.value narrowing after log().
 * Hoare logic proves it safe via the frame rule:
 *   {x -> 42} log(msg) {x -> 42}  (frame rule: x -> 42 not in footprint of log)
 *
 * @require x -> v
 * @ensure x -> 42 /\ res = 42
 */
function readAfterLog(x: Ref<number | string>): number {
    x.value = 42;
    log("processed");
    return x.value;
}
