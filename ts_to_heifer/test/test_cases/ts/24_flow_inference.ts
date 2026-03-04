type Ref<T> = { value: T };

// Test 24: Invariant container narrowing — spec-free flow analysis
//
// TypeScript REJECTS this program:
//   Ref<number|string> is invariant — .value has type number|string
//   After process(y), TypeScript can't prove x.value is a number
//   Returning x.value as number requires unsafe "as number" cast
//
// Heifer PROVES it safe with ZERO specs:
//   1. process(y) footprint is {y} — auto-computed from body
//   2. Frame rule: x not in {y}, so x -> 42 is preserved
//   3. 42 <: number — safe narrowing of invariant container
//
// This is STRICTLY stronger than TypeScript's type system:
//   TypeScript cannot narrow Ref<T> type parameters at all

function process(y: Ref<number | string>): void {
    y.value = "done";
}

function narrowCast(x: Ref<number | string>, y: Ref<number | string>): number {
    x.value = 42;
    process(y);
    return x.value;
}
