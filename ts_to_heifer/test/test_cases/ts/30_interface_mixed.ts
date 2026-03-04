// Interface with mixed fields — some parameterized, some concrete
interface Cell<T> { value: T; dirty: boolean }

/**
 * @require c.value -> v * c.dirty -> _d
 * @ensure c.value -> v * c.dirty -> _d /\ res = v
 */
function readCell(c: Cell<number>): number {
    return c.value;
}
