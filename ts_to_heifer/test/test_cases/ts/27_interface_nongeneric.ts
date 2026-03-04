// Non-generic interface — per-field decomposition
interface Point { x: number; y: number }

/**
 * @require p.x -> vx * p.y -> vy
 * @ensure p.x -> vy * p.y -> vx
 */
function swapPoint(p: Point): void {
    let tmp: number = p.x;
    p.x = p.y;
    p.y = tmp;
}
