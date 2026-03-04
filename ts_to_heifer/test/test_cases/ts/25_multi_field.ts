type Ref<T> = { value: T };
type Pair<A, B> = { first: A; second: B };

// No specs — let the prover infer. Tests that multi-field types
// use CGetField/CSetField while single-field Ref still uses CRead/CWrite.

function swapRef(x: Ref<number>, y: Ref<number>): number {
    let tmp: number = x.value;
    x.value = y.value;
    y.value = tmp;
    return x.value;
}

function readFirst(p: Pair<number, string>): number {
    return p.first;
}
