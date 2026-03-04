// Test 15: Conditional branching with disjunction
// NOTE: Current system uses existential semantics for branches
// Both branches must satisfy spec for it to be sound

let cell: number = 0;
let cell2: number = 0;

// ========== BOTH BRANCHES SAME EFFECT ==========

/**
 * Both branches write same constant
 * @require cell -> v
 * @ensure cell -> 100
 */
function write_constant_true(flag: boolean): void {
  if (flag) {
    cell = 100;
  } else {
    cell = 100;
  }
}

/**
 * Both branches increment
 * @require cell -> v
 * @ensure cell -> v + 1
 */
function increment_true(flag: boolean): void {
  if (flag) {
    cell = cell + 1;
  } else {
    cell = cell + 1;
  }
}

/**
 * Both branches add parameter
 * @require cell -> v
 * @ensure cell -> v + n
 */
function add_n_true(flag: boolean, n: number): void {
  if (flag) {
    cell = cell + n;
  } else {
    cell = cell + n;
  }
}

/**
 * Both branches preserve (identity)
 * @require cell -> v1 * cell2 -> v2
 * @ensure cell -> v1 * cell2 -> v2
 */
function identity_true(flag: boolean): void {
  if (flag) {
    // no-op
  } else {
    // no-op
  }
}

/**
 * Nested conditionals - all paths increment
 * @require cell -> v
 * @ensure cell -> v + 1
 */
function nested_increment_true(a: boolean, b: boolean): void {
  if (a) {
    if (b) {
      cell = cell + 1;
    } else {
      cell = cell + 1;
    }
  } else {
    cell = cell + 1;
  }
}

// ========== NEGATIVE: BRANCHES DIFFER ==========

/**
 * Branches write different constants - SHOULD FAIL
 * One branch writes 100, other writes 200
 * With universal disjunction semantics, BOTH branches must satisfy spec
 * @require cell -> v
 * @ensure cell -> 100
 */
function branch_mismatch_false(flag: boolean): void {
  if (flag) {
    cell = 100;
  } else {
    cell = 200;
  }
}

/**
 * Branches differ: one increments, other decrements - SHOULD FAIL
 * @require cell -> v
 * @ensure cell -> v + 1
 */
function increment_vs_decrement_false(flag: boolean): void {
  if (flag) {
    cell = cell + 1;
  } else {
    cell = cell - 1;
  }
}

/**
 * One branch modifies, other doesn't - SHOULD FAIL
 * @require cell -> v
 * @ensure cell -> 100
 */
function partial_update_false(flag: boolean): void {
  if (flag) {
    cell = 100;
  } else {
    // no-op: cell keeps value v
  }
}

// ========== DISJUNCTIVE DECLARED SPECS ==========

/**
 * Branches write different values, but spec allows EITHER
 * Disjunction in declared spec: cell->100 \/ cell->200
 * @require cell -> v
 * @ensure cell -> 100 \/ cell -> 200
 */
function disjunctive_spec_true(flag: boolean): void {
  if (flag) {
    cell = 100;
  } else {
    cell = 200;
  }
}

/**
 * One branch writes 100, other writes 300
 * But spec only allows 100 or 200 - SHOULD FAIL
 * @require cell -> v
 * @ensure cell -> 100 \/ cell -> 200
 */
function disjunctive_mismatch_false(flag: boolean): void {
  if (flag) {
    cell = 100;
  } else {
    cell = 300;  // 300 not in {100, 200}
  }
}
