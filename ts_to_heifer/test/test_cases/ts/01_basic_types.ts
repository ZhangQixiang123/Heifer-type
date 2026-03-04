// Test 1: Basic primitive types
// Testing how TypeScript parser handles basic type annotations

// Simple number parameter and return
function identity_number(x: number): number {
  return x;
}

// String types
function identity_string(s: string): string {
  return s;
}

// Boolean types
function identity_bool(b: boolean): boolean {
  return b;
}

// Void return type
function log_message(msg: string): void {
  console.log(msg);
}

// Multiple parameters
function add(x: number, y: number): number {
  return x + y;
}

// Multiple parameters with different types
function format(prefix: string, value: number): string {
  return prefix + value.toString();
}
