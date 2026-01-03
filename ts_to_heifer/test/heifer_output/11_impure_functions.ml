=== Translation Successful ===

Heifer IR:
let globalCounter = ref 0 in
let getCounter = fun  (*@ req globalCounter->v_globalCounter; ens globalCounter->v_globalCounter/\res:int @*) -> !globalCounter in
let incrementCounter = fun  (*@ req globalCounter->v_globalCounter; ens globalCounter->v_globalCounter'/\res:() @*) -> let tmp15 = let tmp14 = !globalCounter in
(tmp14 + 1) in
globalCounter := tmp15 in
let incrementAndReturn = fun  (*@ req globalCounter->v_globalCounter; ens globalCounter->v_globalCounter'/\res:int @*) -> let tmp13 = let tmp12 = !globalCounter in
(tmp12 + 1) in
globalCounter := tmp13 in
let addToCounter = fun x (*@ req globalCounter->v_globalCounter/\x:int; ens globalCounter->v_globalCounter'/\res:() @*) -> let tmp11 = let tmp10 = !globalCounter in
(tmp10 + x) in
globalCounter := tmp11 in
let incrementIfPositive = fun x (*@ req globalCounter->v_globalCounter/\x:int; ens globalCounter->v_globalCounter'/\res:() @*) -> if x>0 then let tmp9 = let tmp8 = !globalCounter in
(tmp8 + 1) in
globalCounter := tmp9 else (()) in
let total = ref 0 in
let count = ref 0 in
let addToAverage = fun value (*@ req count->v_count*total->v_total/\value:int; ens count->v_count'*total->v_total'/\res:() @*) -> let tmp7 = let tmp6 = !total in
(tmp6 + value) in
total := tmp7 in
let getAverage = fun  (*@ req total->v_total*count->v_count; ens total->v_total*count->v_count/\res:int @*) -> if count>0 then let tmp1 = !total in
let tmp3 = !count in
(tmp1 / tmp3) else (()) in
let sharedValue = ref 42 in
let swapWithGlobal = fun x (*@ req sharedValue->v_sharedValue/\x:int; ens sharedValue->v_sharedValue'/\res:int @*) -> let temp = !sharedValue in
sharedValue := x in
let doubleIncrement = fun  (*@ req emp; ens res:() @*) -> incrementCounter  in
()

Type: unit

✓ Output is in Heifer's native format
