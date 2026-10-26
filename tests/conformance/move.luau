-- This file is part of the Luau programming language and is licensed under MIT License; see LICENSE.txt for details
-- This file is based on Lua 5.x tests -- https://github.com/lua/lua/tree/master/testes
local function checkerror (msg, f, ...)
  local s, err = pcall(f, ...)
  assert(not s and string.find(err, msg))
end

print("testing move")

local maxI = 2147483647
local minI = -2147483648

-- testing move
do

  checkerror("table expected", table.move, 1, 2, 3, 4)
  checkerror("table expected", table.move, {}, 2, 3, 4, "foo")

  local function eqT (a, b)
    for k, v in pairs(a) do assert(b[k] == v) end 
    for k, v in pairs(b) do assert(a[k] == v) end 
  end

  local a = table.move({10,20,30}, 0, 3, 1)  -- move forward
  eqT(a, {10,10,20,30})

  -- move forward with overlap of 1
  a = table.move({10, 20, 30}, 0, 3, 2)
  eqT(a, {10, 20, 10, 20, 30})

  -- moving to the same table (not being explicit about it)
  a = {10, 20, 30, 40}
  table.move(a, 0, 4, 1, a)
  eqT(a, {10, 10, 20, 30, 40})

  a = table.move({10,20,30}, 1, 3, 0)   -- move backward
  eqT(a, {20,30,30})

  a = {}   -- move to new table
  assert(table.move({10,20,30}, 0, 3, 0, a) == a)
  eqT(a, {10,20,30})

  a = {}
  assert(table.move({10,20,30}, 0, 0, 2, a) == a)  -- empty move (no move)
  eqT(a, {})

  a = table.move({10,20,30}, 0, 10, 0)   -- move to the same place
  eqT(a, {10,20,30})

  -- moving on the fringes
  a = table.move({[maxI - 3] = 1, [maxI - 2] = 2, [maxI - 1] = 3},
                 maxI - 3, maxI, -10, {})
  eqT(a, {[-10] = 1, [-9] = 2, [-8] = 3})

  a = table.move({[minI] = 1, [minI + 1] = 2, [minI + 2] = 3},
                 minI, minI + 3, -10, {})
  eqT(a, {[-10] = 1, [-9] = 2, [-8] = 3})

  a = table.move({45}, 0, 1, maxI)
  eqT(a, {45, [maxI] = 45})

  a = table.move({[maxI - 1] = 100}, maxI - 1, maxI, minI)
  eqT(a, {[minI] = 100, [maxI - 1] = 100})

  a = table.move({[minI] = 100}, minI, minI + 1, maxI)
  eqT(a, {[minI] = 100, [maxI] = 100})

  -- moving small amount of elements (array/hash) using a wide range
  a = {}
  table.move({1, 2, 3, 4, 5}, -100000000, 100000001, -100000000, a)
  eqT(a, {1, 2, 3, 4, 5})

  a = {}
  table.move({1, 2}, -100000000, 100000001, 0, a)
  eqT(a, {[100000000] = 1, [100000001] = 2})

  -- hash part copy
  a = {}
  table.move({[-1000000] = 1, [-100] = 2, [100] = 3, [100000] = 4}, -100000000, 100000001, 0, a)
  eqT(a, {[99000000] = 1, [99999900] = 2, [100000100] = 3, [100100000] = 4})

  -- precise hash part bounds
  a = {}
  table.move({[-100000000 - 1] = -1, [-100000000] = 1, [-100] = 2, [100] = 3, [100000000] = 4, [100000000 + 1] = -1}, -100000000, 100000001, 0, a)
  eqT(a, {[0] = 1, [99999900] = 2, [100000100] = 3, [200000000] = 4})

  -- no integer undeflow in corner hash part case
  a = {}
  table.move({[minI] = 100, [-100] = 2}, minI, minI + 100000001, minI, a)
  eqT(a, {[minI] = 100})

  -- hash part skips array slice
  a = {}
  table.move({[-1] = 1, [0] = 2, [1] = 3, [2] = 4}, -1, 3, 0, a)
  eqT(a, {1, 2, 3, 4})

  a = {}
  table.move({[-1] = 1, [0] = 2, [1] = 3, [2] = 4, [10] = 5, [100] = 6, [1000] = 7}, -1, 3, 0, a)
  eqT(a, {1, 2, 3, 4})

  -- moving ranges containing nil values into tables with values
  a = {1, 2, 3, 4, 5}
  table.move({10}, 0, 3, 1, a)
  eqT(a, {1, 10, nil, nil, 5})

  a = {1, 2, 3, 4, 5}
  table.move({10}, -2, 1, 1, a)
  eqT(a, {1, nil, nil, 10, 5})

  a = {[-1000] = 1, [1000] = 2, [0] = 3}
  table.move({10}, -1000, 1001, -1000, a)
  eqT(a, {10})

  -- sparse moves only consider numeric integer keys
  a = {}
  table.move({["0"] = "string key"}, -100, 101, -100, a)
  eqT(a, {})

  a = {["0"] = "keep", [0] = "clear"}
  table.move({}, -100, 101, -100, a)
  eqT(a, {["0"] = "keep"})

  -- sparse moves within the same table preserve the source before clearing overlapping destinations
  a = {[-100] = "left", [20] = "hole", [100] = "right", [500] = "outside"}
  table.move(a, -100, 101, -99, a)
  eqT(a, {[-100] = "left", [-99] = "left", [21] = "hole", [101] = "right", [500] = "outside"})

  -- destination array growth must not hide a sparse move
  a = {1, 2, 3}
  table.move({[0] = "first", [9999999] = "last"}, 0, 10000000, 1, a)
  eqT(a, {1, "first", [10000000] = "last"})

  -- a huge sparse move starting at destination index 0 must not allocate the full range
  a = {}
  table.move({[0] = "first", [9999999] = "last"}, 0, 10000000, 0, a)
  eqT(a, {[0] = "first", [9999999] = "last"})

  -- sparse moving on the fringes
  a = table.move({[maxI - 101] = 1, [maxI - 51] = 2, [maxI - 1] = 3},
                 maxI - 101, maxI, -100, {})
  eqT(a, {[-100] = 1, [-50] = 2, [0] = 3})

  a = table.move({[minI] = 1, [minI + 50] = 2, [minI + 100] = 3},
                 minI, minI + 101, -100, {})
  eqT(a, {[-100] = 1, [-50] = 2, [0] = 3})

  a = table.move({[-100] = 1, [-50] = 2, [0] = 3},
                 -100, 1, maxI - 100, {})
  eqT(a, {[maxI - 100] = 1, [maxI - 50] = 2, [maxI] = 3})

  a = table.move({[-100] = 1, [-50] = 2, [0] = 3},
                 -100, 1, minI, {})
  eqT(a, {[minI] = 1, [minI + 50] = 2, [minI + 100] = 3})
end

checkerror("too many", table.move, {}, -1, maxI, 0)
checkerror("too many", table.move, {}, -2, maxI - 1, 0)
checkerror("too many", table.move, {}, minI, 0, 0)
checkerror("too many", table.move, {}, minI, maxI, 1)
checkerror("wrap around", table.move, {}, 0, maxI, 2)
checkerror("wrap around", table.move, {}, 0, 2, maxI)
checkerror("wrap around", table.move, {}, minI, -1, 2)

checkerror("readonly", table.move, table.freeze({}), 0, 1, 0)

return"OK"
