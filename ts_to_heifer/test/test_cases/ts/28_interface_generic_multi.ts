// Generic multi-field interface
interface IPair<A, B> { first: A; second: B }

/**
 * @require p.first -> v * p.second -> w
 * @ensure p.first -> v * p.second -> w /\ res = v
 */
function readFirst(p: IPair<number, string>): number {
    return p.first;
}
