// Test 5: Variable declarations and mutations
// Testing const, let, and reassignment

// Immutable variable (const)
function const_variable(): number {
  const x: number = 10;
  return x + 5;
}

// Immutable let (never reassigned)
function immutable_let(): number {
  let x: number = 10;
  let y: number = 20;
  return x + y;
}

// Mutable variable (reassigned)
function mutable_variable(): number {
  let x: number = 10;
  x = x + 5;
  return x;
}

// Multiple reassignments
function multiple_mutations(): number {
  let sum: number = 0;
  sum = sum + 10;
  sum = sum + 20;
  sum = sum + 30;
  return sum;
}

// Mixed immutable and mutable
function mixed_variables(): number {
  const a: number = 10;
  let b: number = 20;
  b = b + a;
  const c: number = b * 2;
  return c;
}

// Variable shadowing
function shadowing(): number {
  let x: number = 10;
  {
    let x: number = 20;
    return x;
  }
}

// Increment and decrement patterns
function increment_pattern(): number {
  let count: number = 0;
  count = count + 1;
  count = count + 1;
  count = count + 1;
  return count;
}
