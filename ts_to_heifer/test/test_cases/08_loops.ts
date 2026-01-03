// Test 8: Loop constructs
// Testing while, for, and loop patterns

// Simple while loop
function count_to_n(n: number): number {
  let i: number = 0;
  while (i < n) {
    i = i + 1;
  }
  return i;
}

// While loop with accumulator
function sum_to_n(n: number): number {
  let sum: number = 0;
  let i: number = 0;
  while (i <= n) {
    sum = sum + i;
    i = i + 1;
  }
  return sum;
}

// For loop
function sum_array(arr: number[]): number {
  let total: number = 0;
  for (let i = 0; i < arr.length; i++) {
    total = total + arr[i];
  }
  return total;
}

// Nested loops
function sum_matrix(matrix: number[][]): number {
  let sum: number = 0;
  for (let i = 0; i < matrix.length; i++) {
    for (let j = 0; j < matrix[i].length; j++) {
      sum = sum + matrix[i][j];
    }
  }
  return sum;
}

// Loop with break
function find_index(arr: number[], target: number): number {
  for (let i = 0; i < arr.length; i++) {
    if (arr[i] === target) {
      return i;
    }
  }
  return -1;
}

// Loop with continue pattern (using if)
function sum_positive(arr: number[]): number {
  let sum: number = 0;
  for (let i = 0; i < arr.length; i++) {
    if (arr[i] > 0) {
      sum = sum + arr[i];
    }
  }
  return sum;
}
