// Test 6: Object types and record operations
// Testing record field read/write with separation logic specs

// Simple Point interface
interface Point {
  x: number;
  y: number;
}

/**
 * Read x field from point
 * @require p -> {x: vx, y: vy}
 * @ensure p -> {x: vx, y: vy} /\ res = vx
 */
function get_x_true(p: Point): number {
  return p.x;
}

/**
 * Read y field from point
 * @require p -> {x: vx, y: vy}
 * @ensure p -> {x: vx, y: vy} /\ res = vy
 */
function get_y_true(p: Point): number {
  return p.y;
}

/**
 * Set x field on point
 * @require p -> {x: oldx, y: vy}
 * @ensure p -> {x: value, y: vy}
 */
function set_x_true(p: Point, value: number): void {
  p.x = value;
}

/**
 * Set y field on point
 * @require p -> {x: vx, y: oldy}
 * @ensure p -> {x: vx, y: value}
 */
function set_y_true(p: Point, value: number): void {
  p.y = value;
}

/**
 * Create a new point with given coordinates
 * @ensure res -> {x: x, y: y}
 */
function make_point_true(x: number, y: number): Point {
  return { x: x, y: y };
}

/**
 * Move point by dx in x direction
 * @require p -> {x: vx, y: vy}
 * @ensure p -> {x: vx + dx, y: vy}
 */
function move_x_true(p: Point, dx: number): void {
  p.x = p.x + dx;
}

/**
 * Move point by dy in y direction
 * @require p -> {x: vx, y: vy}
 * @ensure p -> {x: vx, y: vy + dy}
 */
function move_y_true(p: Point, dy: number): void {
  p.y = p.y + dy;
}

/**
 * Move point by dx and dy
 * @require p -> {x: vx, y: vy}
 * @ensure p -> {x: vx + dx, y: vy + dy}
 */
function move_point_true(p: Point, dx: number, dy: number): void {
  p.x = p.x + dx;
  p.y = p.y + dy;
}

// ========== NEGATIVE TESTS ==========

/**
 * Wrong read spec: claims x equals y (should fail)
 * @require p -> {x: vx, y: vy}
 * @ensure p -> {x: vx, y: vy} /\ res = vy
 */
function get_x_wrong_false(p: Point): number {
  return p.x;
}

/**
 * Wrong write spec: claims field unchanged (should fail)
 * @require p -> {x: oldx, y: vy}
 * @ensure p -> {x: oldx, y: vy}
 */
function set_x_wrong_false(p: Point, value: number): void {
  p.x = value;
}

/**
 * Wrong move spec: claims only x changed when both change (should fail)
 * @require p -> {x: vx, y: vy}
 * @ensure p -> {x: vx + dx, y: vy}
 */
function move_point_wrong_false(p: Point, dx: number, dy: number): void {
  p.x = p.x + dx;
  p.y = p.y + dy;
}
