// Test 3: Control flow statements
// Testing if-else, conditionals, and branching

// Simple if-else
function abs(x: number): number {
  if (x < 0) {
    return -x;
  }
  return x;
}

// If-else with both branches returning
function max(a: number, b: number): number {
  if (a > b) {
    return a;
  } else {
    return b;
  }
}

// Ternary operator
function min(a: number, b: number): number {
  return a < b ? a : b;
}

// Multiple conditions
function sign(x: number): string {
  if (x > 0) {
    return "positive";
  } else if (x < 0) {
    return "negative";
  } else {
    return "zero";
  }
}

// Nested conditionals
function classify(x: number, y: number): string {
  if (x > 0) {
    if (y > 0) {
      return "quadrant_1";
    } else {
      return "quadrant_4";
    }
  } else {
    if (y > 0) {
      return "quadrant_2";
    } else {
      return "quadrant_3";
    }
  }
}

// Early return
function safe_divide(a: number, b: number): number {
  if (b === 0) {
    return 0;
  }
  return a / b;
}
