// TypeScript version of type.ml - matching all examples

// ADT types (TypeScript uses union types)
type H = "A" | "B";

type Any =
  | { tag: "Int", value: number }
  | { tag: "Str", value: string };

// Simple identity function (polymorphic)
function id2(y: number): number {
  return y;
}

// Addition function
function plus(x: number, y: number): number {
  return x + y;
}

// Dereference (TypeScript object property access)
function deref(x: {value: number}): number {
  return x.value;
}

// Identity with function composition
function id3(x: string): string {
  return id2_str(x);
}

// Helper for id3
function id2_str(y: string): string {
  return y;
}

// Pattern matching on ADT (using discriminated union)
function id4(y: Any): Any {
  if (y.tag === "Int") {
    return { tag: "Int", value: y.value + 1 };
  } else {
    return { tag: "Str", value: "not supported" };
  }
}

// Generic identity with let binding
function id(y: number): number {
  const x = y;
  return x;
}
