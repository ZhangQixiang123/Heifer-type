=== Translation Successful ===

Heifer IR:
let abs = fun x (*@ req x:int; ens res:int @*) -> if x<0 then (0 - x) else (()) in
let max = fun a b (*@ req a:int/\b:int; ens res:int @*) -> if a>b then a else (b) in
let min = fun a b (*@ req a:int/\b:int; ens res:int @*) -> if a<b then a else (b) in
let sign = fun x (*@ req x:int; ens res:Str @*) -> if x>0 then "positive" else (if x<0 then "negative" else ("zero")) in
let classify = fun x y (*@ req x:int/\y:int; ens res:Str @*) -> if x>0 then if y>0 then "quadrant_1" else ("quadrant_4") else (if y>0 then "quadrant_2" else ("quadrant_3")) in
let safe_divide = fun a b (*@ req a:int/\b:int; ens res:int @*) -> if b=0 then 0 else (()) in
()

Type: unit

✓ Output is in Heifer's native format
