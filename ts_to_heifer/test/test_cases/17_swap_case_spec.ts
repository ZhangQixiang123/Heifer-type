// @ts-nocheck
// Test 17: Swap function with case-based specification
// Using Ref<T> type for proper reference semantics
// Note: @ts-nocheck needed because TypeScript cannot type heterogeneous swap

// Ref type definition
type Ref<T> = { value: T };

// ========== CASE-BASED SWAP SPECIFICATION ==========

/**
 * Swap with full case-based specification (3 cases)
 *
 * swap: ∀A : AnyP, a, b : Any. case [x, y] {
 *   x : Ref(A) ∧ y : Ref(A) ⇒ ens [r] r : ();
 *   x→Ref(a) * y→Ref(b) ⇒ ens [r] x→Ref(b) * y→Ref(a) ∧ r : ();
 *   x→Ref(a) ∧ y : x ⇒ ens [r] x→Ref(a) ∧ r : ()
 * }
 *
 * @forall A, a, b
 * @params x, y
 * @case x : Ref(A) /\ y : Ref(A) => r : ()
 * @case x -> Ref(a) * y -> Ref(b) => x -> Ref(b) * y -> Ref(a) /\ r : ()
 * @case x -> Ref(a) /\ y : x => x -> Ref(a) /\ r : ()
 */
function swap_case_spec_true<A, B>(x: Ref<A>, y: Ref<B>): void {
  const tmp = x.value;
  x.value = y.value;
  y.value = tmp;
}

/**
 * Swap with only 2 cases (missing aliased case)
 * Tests what happens when a case is eliminated
 *
 * @forall A, a, b
 * @params x, y
 * @case x : Ref(A) /\ y : Ref(A) => r : ()
 * @case x -> Ref(a) * y -> Ref(b) => x -> Ref(b) * y -> Ref(a) /\ r : ()
 */
function swap_case_spec_true_2<A, B>(x: Ref<A>, y: Ref<B>): void {
  const tmp = x.value;
  x.value = y.value;
  y.value = tmp;
}

// ========== WHY THE SAME CODE WORKS FOR ALL CASES ==========

// For distinct refs (x != y via separating conjunction):
//   tmp = x.value     → tmp = a
//   x.value = y.value → x = b
//   y.value = tmp     → y = a
//   Result: x→Ref(b), y→Ref(a) (swapped!) ✓

// For aliased refs (x == y, via y : x):
//   tmp = x.value     → tmp = a
//   x.value = y.value → x = a  (reading and writing same cell)
//   y.value = tmp     → x = a  (y is x, so writing a back)
//   Result: x→Ref(a) (unchanged!) ✓

// For type-only case:
//   We only know x and y are Ref(A) types
//   The function returns unit, which satisfies r : ()
