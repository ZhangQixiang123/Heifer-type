=== Translation Successful ===

Heifer IR:
let const_variable = fun  (*@ req emp; ens res:int @*) -> let x = 10 in
(x + 5) in
let immutable_let = fun  (*@ req emp; ens res:int @*) -> let x = ref 10 in
let y = ref 20 in
let tmp18 = !x in
let tmp20 = !y in
(tmp18 + tmp20) in
let mutable_variable = fun  (*@ req emp; ens res:int @*) -> let x = ref 10 in
let tmp17 = let tmp16 = !x in
(tmp16 + 5) in
x := tmp17 in
let multiple_mutations = fun  (*@ req emp; ens res:int @*) -> let sum = ref 0 in
let tmp15 = let tmp14 = !sum in
(tmp14 + 10) in
sum := tmp15 in
let mixed_variables = fun  (*@ req emp; ens res:int @*) -> let a = 10 in
let b = ref 20 in
let tmp9 = let tmp8 = !b in
(tmp8 + a) in
b := tmp9 in
let shadowing = fun  (*@ req emp; ens res:int @*) -> let x = ref 10 in
let x = ref 20 in
!x;
!x in
let increment_pattern = fun  (*@ req emp; ens res:int @*) -> let count = ref 0 in
let tmp6 = let tmp5 = !count in
(tmp5 + 1) in
count := tmp6 in
()

Type: unit

✓ Output is in Heifer's native format
