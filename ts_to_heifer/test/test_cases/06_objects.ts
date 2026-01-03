// Test 6: Object types and interfaces
// Testing how parser handles object type annotations

// Simple interface
interface Point {
  x: number;
  y: number;
}

// Function with object parameter
function get_x(p: Point): number {
  return p.x;
}

// Function that mutates object field
function set_x(p: Point, value: number): void {
  p.x = value;
}

// Function with multiple field accesses
function distance_from_origin(p: Point): number {
  return Math.sqrt(p.x * p.x + p.y * p.y);
}

// Object literal type annotation
function process_config(cfg: { host: string; port: number }): string {
  return cfg.host + ":" + cfg.port.toString();
}

// Nested objects
interface Address {
  street: string;
  city: string;
}

interface Person {
  name: string;
  address: Address;
}

function get_city(person: Person): string {
  return person.address.city;
}

// Object creation and return
function make_point(x: number, y: number): Point {
  return { x: x, y: y };
}

// Multiple object mutations
function move_point(p: Point, dx: number, dy: number): void {
  p.x = p.x + dx;
  p.y = p.y + dy;
}
