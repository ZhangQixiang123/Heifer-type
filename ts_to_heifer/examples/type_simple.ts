// Simplified TypeScript version of type.ml (without object literals for now)

// Simple identity function
function id2(y: number): number {
  return y;
}

// Addition function
function plus(x: number, y: number): number {
  return x + y;
}

// Generic identity with let binding
function id(y: number): number {
  const x = y;
  return x;
}

// String identity
function id2_str(y: string): string {
  return y;
}

// Identity with function call
function id3(x: string): string {
  return id2_str(x);
}
