// Base interface
interface Shape { x: number; y: number }

// Derived interface — inherits x, y from Shape, adds radius
interface Circle extends Shape { radius: number }

/**
 * @require c.radius -> r * c.x -> _cx * c.y -> _cy
 * @ensure c.radius -> r * c.x -> _cx * c.y -> _cy /\ res = r
 */
function getRadius(c: Circle): number {
    return c.radius;
}

/**
 * @require c.x -> vx * c.y -> _cy * c.radius -> _r
 * @ensure c.x -> vx+dx * c.y -> _cy * c.radius -> _r
 */
function moveCircle(c: Circle, dx: number): void {
    c.x = c.x + dx;
}
