// Test 10: Complex function patterns
// Testing combinations of features

// Function with multiple branches and mutations
function calculate_grade(score: number): string {
  let grade: string = "F";
  if (score >= 90) {
    grade = "A";
  } else if (score >= 80) {
    grade = "B";
  } else if (score >= 70) {
    grade = "C";
  } else if (score >= 60) {
    grade = "D";
  }
  return grade;
}

// Function with object, array, and mutations
interface Stats {
  count: number;
  sum: number;
}

function compute_stats(numbers: number[]): Stats {
  let count: number = 0;
  let sum: number = 0;
  for (let i = 0; i < numbers.length; i++) {
    count = count + 1;
    sum = sum + numbers[i];
  }
  return { count: count, sum: sum };
}

// Function with nullable parameters and complex logic
function safe_operation(a: number | null, b: number | null, op: string): number | null {
  if (a === null || b === null) {
    return null;
  }

  if (op === "add") {
    return a + b;
  } else if (op === "multiply") {
    return a * b;
  } else if (op === "subtract") {
    return a - b;
  } else {
    return null;
  }
}

// Recursive-style pattern (will need recursion support)
function factorial(n: number): number {
  if (n <= 1) {
    return 1;
  }
  return n * factorial(n - 1);
}

// Function with multiple local variables and computations
function compute_area_perimeter(width: number, height: number): { area: number; perimeter: number } {
  const area: number = width * height;
  const perimeter: number = 2 * (width + height);
  return { area: area, perimeter: perimeter };
}

// Function combining type guards, mutations, and objects
function process_item(item: { value: number | string }): number {
  let result: number = 0;
  if (typeof item.value === "number") {
    result = item.value * 2;
  } else {
    result = item.value.length;
  }
  return result;
}
