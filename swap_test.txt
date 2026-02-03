// @ts-nocheck
// Test 17: Swap function with case-based specification
// Using Ref<T> type for proper reference semantics
// Note: @ts-nocheck needed because TypeScript cannot type heterogeneous swap

// Ref type definition
type Ref<T> = { value: T };
/**
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
 * @forall a, b
 * @params x, y
 * @case x -> Ref(a) * y -> Ref(b) => x -> Ref(b) * y -> Ref(a) /\ r : ()
 * @case x -> Ref(a) /\ y : x => x -> Ref(a) /\ r : ()
 */
function swap_case_spec_true_2<A, B>(x: Ref<A>, y: Ref<B>): void {
  const tmp = x.value;
  x.value = y.value;
  y.value = tmp;
}

/**
 *
 * @forall A
 * @params x, y
 * @case x : Ref(A) /\ y : Ref(A) => r : ()
 */
function swap_case_spec_true_3<A, B>(x: Ref<A>, y: Ref<B>): void {
  const tmp = x.value;
  x.value = y.value;
  y.value = tmp;
}

/**
 * @forall A, a, b
 * @params x, y
 * @case x : Ref(A) /\ y : Ref(A) => r : ()
 * @case x -> Ref(a) * y -> Ref(b) => x -> Ref(b) * y -> Ref(a) /\ r : ()
 */
function swap_case_spec_false<A, B>(x: Ref<A>, y: Ref<B>): void {
  const tmp = x.value;
  x.value = y.value;
  y.value = tmp;
}

/**
 * @forall A, a
 * @params x, y
 * @case x : Ref(A) /\ y : Ref(A) => r : ()
 * @case x -> Ref(a) /\ y : x => x -> Ref(a) /\ r : ()
 */
function swap_case_spec_false_2<A, B>(x: Ref<A>, y: Ref<B>): void {
  const tmp = x.value;
  x.value = y.value;
  y.value = tmp;
}