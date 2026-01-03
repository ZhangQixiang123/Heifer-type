// Test 9: Type guards and refinement
// Testing typeof, instanceof, and type narrowing

// typeof guard - number
function double_if_number(x: number | string): number | string {
  if (typeof x === "number") {
    return x * 2;
  }
  return x;
}

// typeof guard - string
function uppercase_if_string(x: number | string): number | string {
  if (typeof x === "string") {
    return x.toUpperCase();
  }
  return x;
}

// typeof guard - boolean
function negate_if_bool(x: boolean | number): boolean | number {
  if (typeof x === "boolean") {
    return !x;
  }
  return x;
}

// Multiple typeof checks
function describe_type(x: number | string | boolean): string {
  if (typeof x === "number") {
    return "number";
  } else if (typeof x === "string") {
    return "string";
  } else if (typeof x === "boolean") {
    return "boolean";
  } else {
    return "unknown";
  }
}

// Null check (common pattern)
function string_length_safe(s: string | null): number {
  if (s !== null) {
    return s.length;
  }
  return 0;
}

// Undefined check
function get_value_or_zero(x: number | undefined): number {
  if (x !== undefined) {
    return x;
  }
  return 0;
}

// Truthiness check
function truthy_to_number(x: number | null | undefined): number {
  if (x) {
    return x;
  }
  return 0;
}
