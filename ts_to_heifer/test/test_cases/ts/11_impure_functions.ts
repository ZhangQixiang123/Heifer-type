// Test 11: Impure functions with global state
// Testing functions that access and modify global variables
// This is critical for separation logic - heap effects!

// Global counter
let globalCounter: number = 0;

/**
 * Read global state
 * @require globalCounter -> v
 * @ensure globalCounter -> v /\ res = v
 */
function getCounter_true(): number {
  return globalCounter;
}

/**
 * Modify global state: increment by 1
 * @require globalCounter -> v
 * @ensure globalCounter -> v + 1
 */
function incrementCounter_true(): void {
  globalCounter = globalCounter + 1;
}

/**
 * Read and modify: increment and return new value
 * @require globalCounter -> v
 * @ensure globalCounter -> v + 1 /\ res = v + 1
 */
function incrementAndReturn_true(): number {
  globalCounter = globalCounter + 1;
  return globalCounter;
}

/**
 * Add parameter to global
 * @require globalCounter -> v
 * @ensure globalCounter -> v + x
 */
function addToCounter_true(x: number): void {
  globalCounter = globalCounter + x;
}

// Multiple global variables
let total: number = 0;
let count: number = 0;

/**
 * Modify two globals: add value and increment count
 * @require total -> t * count -> c
 * @ensure total -> t + value * count -> c + 1
 */
function addToAverage_true(value: number): void {
  total = total + value;
  count = count + 1;
}

// Global for swap test
let sharedValue: number = 42;

/**
 * Simple write: set global to parameter value
 * @require sharedValue -> old
 * @ensure sharedValue -> newVal
 */
function setSharedValue_true(newVal: number): void {
  sharedValue = newVal;
}

/**
 * Read and return global value
 * @require sharedValue -> v
 * @ensure sharedValue -> v /\ res = v
 */
function getSharedValue_true(): number {
  return sharedValue;
}

// ========== NEGATIVE TESTS ==========

/**
 * Wrong increment spec: claims no change (should fail)
 * @require globalCounter -> v
 * @ensure globalCounter -> v
 */
function incrementCounter_wrong_false(): void {
  globalCounter = globalCounter + 1;
}

/**
 * Wrong read spec: claims different value (should fail)
 * @require globalCounter -> v
 * @ensure globalCounter -> v /\ res = 0
 */
function getCounter_wrong_false(): number {
  return globalCounter;
}

/**
 * Wrong write spec: claims value unchanged (should fail)
 * @require sharedValue -> old
 * @ensure sharedValue -> old
 */
function setSharedValue_wrong_false(newVal: number): void {
  sharedValue = newVal;
}
