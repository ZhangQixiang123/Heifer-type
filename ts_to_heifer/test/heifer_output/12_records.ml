=== Translation Successful ===

Heifer IR:
let point = { x = 10; y = 20 } in
let getX = fun p -> (p).x in
let getY = fun p -> (p).y in
let moveRight = fun p -> (p).x <- let tmp7 = (p).x in
(tmp7 + 1) in
let moveUp = fun p -> (p).y <- let tmp6 = (p).y in
(tmp6 + 1) in
let person = { name = "Alice"; age = 30; active = true } in
let getName = fun p -> (p).name in
let getAge = fun p -> (p).age in
let isActive = fun p -> (p).active in
let rectangle = { topLeft = { x = 0; y = 0 }; bottomRight = { x = 100; y = 100 } } in
let getRectWidth = fun r -> let tmp3 = ((r).bottomRight).x in
let tmp5 = ((r).topLeft).x in
(tmp3 - tmp5) in
let makePoint = fun x y -> { x = x; y = y } in
let translate = fun p dx dy -> (p).x <- let tmp2 = (p).x in
