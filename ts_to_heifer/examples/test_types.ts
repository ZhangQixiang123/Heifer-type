// Test functions similar to type.ml

// Identity function (similar to id2 in type.ml)
/**
 * @requires y: number, heap_empty
 * @ensures res: number, heap_empty
 */
function id2(y: number): number {
  return y;
}

// Addition (similar to plus in type.ml)
/**
 * @requires x: number /\ y: number, heap_empty
 * @ensures res: number, heap_empty
 */
function plus(x: number, y: number): number {
  return x + y;
}

// Generic identity (polymorphic, similar to id in type.ml)
/**
 * @requires y: any, heap_empty
 * @ensures res: any, heap_empty
 */
function id<T>(y: T): T {
  const x = y;
  return x;
}

// Conditional function
/**
 * @requires x: number, heap_empty
 * @ensures res: string, heap_empty
 */
function classify(x: number): string {
  if (x > 0) {
    return "positive";
  } else {
    return "non-positive";
  }
}

// Function with mutable variable (tests variance)
/**
 * @requires init: number, heap_empty
 * @ensures res: number, heap_empty
 */
function increment(init: number): number {
  let x: number = init;
  x = x + 1;
  return x;
}
