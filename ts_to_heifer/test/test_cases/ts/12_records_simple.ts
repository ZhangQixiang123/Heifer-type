// Simple record test for type inference

/**
 * @requires true
 * @ensures res.x = x /\ res.y = y
 */
function makePoint(x: number, y: number): { x: number; y: number } {
  return { x: x, y: y };
}

/**
 * @requires true
 * @ensures res = p.x
 */
function getX(p: { x: number; y: number }): number {
  return p.x;
}
