// Test 4: Binary and unary operators
// Testing operator parsing and types

// Arithmetic operators
function add_nums(x: number, y: number): number {
  return x + y;
}

function subtract(x: number, y: number): number {
  return x - y;
}

function multiply(x: number, y: number): number {
  return x * y;
}

function divide(x: number, y: number): number {
  return x / y;
}

function power(x: number, y: number): number {
  return x ** y;
}

// Comparison operators
function less_than(x: number, y: number): boolean {
  return x < y;
}

function greater_or_equal(x: number, y: number): boolean {
  return x >= y;
}

function equals(x: number, y: number): boolean {
  return x === y;
}

function not_equals(x: number, y: number): boolean {
  return x !== y;
}

// Logical operators
function and_op(a: boolean, b: boolean): boolean {
  return a && b;
}

function or_op(a: boolean, b: boolean): boolean {
  return a || b;
}

function not_op(a: boolean): boolean {
  return !a;
}

// String concatenation
function concat(a: string, b: string): string {
  return a + b;
}

// Unary minus
function negate(x: number): number {
  return -x;
}

// Complex expression
function complex_expr(x: number, y: number, z: number): number {
  return (x + y) * z - (x - y) / 2;
}
