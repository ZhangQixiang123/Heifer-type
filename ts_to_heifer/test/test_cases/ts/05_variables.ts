// Test 5: Variable declarations and mutations
// Testing const, let, and reassignment with separation logic specs

// Global mutable variable for testing
let globalVar: number = 0;

/**
 * Simple read of global
 * @require globalVar -> v
 * @ensure globalVar -> v /\ res = v
 */
function readGlobal_true(): number {
  return globalVar;
}

/**
 * Simple write to global
 * @require globalVar -> old
 * @ensure globalVar -> 42
 */
function writeGlobal_true(): void {
  globalVar = 42;
}

/**
 * Increment global
 * @require globalVar -> v
 * @ensure globalVar -> v + 1
 */
function incrementGlobal_true(): void {
  globalVar = globalVar + 1;
}

/**
 * Multiple increments to global
 * @require globalVar -> v
 * @ensure globalVar -> v + 3
 */
function tripleIncrement_true(): void {
  globalVar = globalVar + 1;
  globalVar = globalVar + 1;
  globalVar = globalVar + 1;
}

/**
 * Add parameter to global
 * @require globalVar -> v
 * @ensure globalVar -> v + amount
 */
function addToGlobal_true(amount: number): void {
  globalVar = globalVar + amount;
}

/**
 * Read-modify-write: add 10 to global value
 * @require globalVar -> v
 * @ensure globalVar -> v + 10
 */
function addTenToGlobal_true(): void {
  globalVar = globalVar + 10;
}

// Second global for multi-variable tests
let globalVar2: number = 0;

/**
 * Copy value from one global to another
 * @require globalVar -> v1 * globalVar2 -> v2
 * @ensure globalVar -> v1 * globalVar2 -> v1
 */
function copyGlobal_true(): void {
  globalVar2 = globalVar;
}

/**
 * Swap two globals
 * @require globalVar -> v1 * globalVar2 -> v2
 * @ensure globalVar -> v2 * globalVar2 -> v1
 */
function swapGlobals_true(): void {
  const temp: number = globalVar;
  globalVar = globalVar2;
  globalVar2 = temp;
}

// ========== NEGATIVE TESTS ==========

/**
 * Wrong increment spec: claims no change (should fail)
 * @require globalVar -> v
 * @ensure globalVar -> v
 */
function incrementWrong_false(): void {
  globalVar = globalVar + 1;
}

/**
 * Wrong add spec: claims wrong increment (should fail)
 * @require globalVar -> v
 * @ensure globalVar -> v + 20
 */
function addTenWrong_false(): void {
  globalVar = globalVar + 10;
}

/**
 * Wrong swap: claims values unchanged (should fail)
 * @require globalVar -> v1 * globalVar2 -> v2
 * @ensure globalVar -> v1 * globalVar2 -> v2
 */
function swapWrong_false(): void {
  const temp: number = globalVar;
  globalVar = globalVar2;
  globalVar2 = temp;
}
