// Test 2: Nullable and union types (without field access)
// Testing how parser handles union types and null/undefined

// Nullable parameter - returns passed value or 0
function get_value(s: number | null): number {
  if (s !== null) {
    return s + 1;
  }
  return 0;
}

// Nullable return - returns value or null
function maybe_positive(x: number): number | null {
  if (x > 0) {
    return x;
  }
  return null;
}

// Union of multiple types - type guard with typeof
function process_value(x: number | string): number {
  if (typeof x === "number") {
    return x + 1;
  }
  // For string, return 0 (placeholder since we can't access .length)
  return 0;
}

// Undefined handling
function get_or_default(x: number | undefined, def: number): number {
  if (x !== undefined) {
    return x;
  }
  return def;
}

// Complex union - type guards
function handle_result(result: string | number | boolean): number {
  if (typeof result === "string") {
    return 0;  // placeholder for string case
  } else if (typeof result === "number") {
    return result;
  } else {
    return result ? 1 : 0;
  }
}

// Null comparison
function is_null(x: number | null): boolean {
  return x === null;
}

// Undefined comparison
function is_undefined(x: number | undefined): boolean {
  return x === undefined;
}
