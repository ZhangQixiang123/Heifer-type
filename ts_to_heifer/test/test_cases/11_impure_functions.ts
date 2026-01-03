// Test 11: Impure functions with global state
// Testing functions that access and modify global variables
// This is critical for separation logic - heap effects!

// Global counter
let globalCounter: number = 0;

// Function that reads global state
function getCounter(): number {
  return globalCounter;
}

// Function that modifies global state
function incrementCounter(): void {
  globalCounter = globalCounter + 1;
}

// Function that both reads and modifies global state
function incrementAndReturn(): number {
  globalCounter = globalCounter + 1;
  return globalCounter;
}

// Function with parameter and global state modification
function addToCounter(x: number): void {
  globalCounter = globalCounter + x;
}

// Function that conditionally modifies global state
function incrementIfPositive(x: number): void {
  if (x > 0) {
    globalCounter = globalCounter + 1;
  }
}

// Multiple global variables
let total: number = 0;
let count: number = 0;

// Function modifying multiple globals
function addToAverage(value: number): void {
  total = total + value;
  count = count + 1;
}

// Function reading multiple globals
function getAverage(): number {
  if (count > 0) {
    return total / count;
  }
  return 0;
}

// Global reference to demonstrate heap effects
let sharedValue: number = 42;

// Function that swaps with global
function swapWithGlobal(x: number): number {
  const temp: number = sharedValue;
  sharedValue = x;
  return temp;
}

// Nested function calls with global state
function doubleIncrement(): void {
  incrementCounter();
  incrementCounter();
}
