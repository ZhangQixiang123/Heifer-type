// Generic interface — structurally equivalent to type alias
interface IRef<T> { value: T }

/**
 * @require x -> v
 * @ensure x -> v /\ res = v
 */
function readIRef(x: IRef<number>): number {
    return x.value;
}

/**
 * @require x -> _old
 * @ensure x -> n
 */
function writeIRef(x: IRef<number>, n: number): void {
    x.value = n;
}
