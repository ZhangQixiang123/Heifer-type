// Test 7: Array types
// Testing array type annotations and operations

// Simple array parameter
function first_element(arr: number[]): number {
  return arr[0];
}

// Array with nullable return
function safe_first(arr: number[]): number | null {
  if (arr.length > 0) {
    return arr[0];
  }
  return null;
}

// Array of strings
function join_strings(arr: string[]): string {
  let result: string = "";
  for (let i = 0; i < arr.length; i++) {
    result = result + arr[i];
  }
  return result;
}

// Array element access
function get_element(arr: number[], index: number): number {
  return arr[index];
}

// Array mutation
function set_element(arr: number[], index: number, value: number): void {
  arr[index] = value;
}

// Array length
function array_size(arr: number[]): number {
  return arr.length;
}

// 2D array
function get_matrix_element(matrix: number[][], row: number, col: number): number {
  return matrix[row][col];
}

// Array of objects
interface Item {
  id: number;
  name: string;
}

function get_item_name(items: Item[], index: number): string {
  return items[index].name;
}
