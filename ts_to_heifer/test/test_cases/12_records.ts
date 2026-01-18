/**
 * Test Cases for Record/Object Support
 *
 * This file tests various record operations:
 * 1. Simple record creation
 * 2. Field access
 * 3. Field update (mutation)
 * 4. Nested records
 * 5. Records with different field types
 */

// Test 1: Simple point record
const point = { x: 10, y: 20 };

// Test 2: Field access
function getX(p: { x: number; y: number }): number {
    return p.x;
}

function getY(p: { x: number; y: number }): number {
    return p.y;
}

// Test 3: Field mutation
function moveRight(p: { x: number; y: number }): void {
    p.x = p.x + 1;
}

function moveUp(p: { x: number; y: number }): void {
    p.y = p.y + 1;
}

// Test 4: Record with multiple field types
const person = {
    name: "Alice",
    age: 30,
    active: true
};

// Test 5: Accessing different field types
function getName(p: { name: string; age: number; active: boolean }): string {
    return p.name;
}

function getAge(p: { name: string; age: number; active: boolean }): number {
    return p.age;
}

function isActive(p: { name: string; age: number; active: boolean }): boolean {
    return p.active;
}

// Test 6: Nested records
const rectangle = {
    topLeft: { x: 0, y: 0 },
    bottomRight: { x: 100, y: 100 }
};

// Test 7: Accessing nested fields
function getRectWidth(r: { topLeft: { x: number; y: number }; bottomRight: { x: number; y: number } }): number {
    return r.bottomRight.x - r.topLeft.x;
}

// Test 8: Creating records in functions
function makePoint(x: number, y: number): { x: number; y: number } {
    return { x: x, y: y };
}

// Test 9: Multiple field updates
function translate(p: { x: number; y: number }, dx: number, dy: number): void {
    p.x = p.x + dx;
    p.y = p.y + dy;
}

// Test 10: Record with computed values
function makeSquare(size: number): { width: number; height: number; area: number } {
    return {
        width: size,
        height: size,
        area: size * size
    };
}
