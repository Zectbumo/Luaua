--!strict
--!nolint

-- Luaua zero-based / half-open semantic conformance suite.
--
-- Run every mode; all must pass:
--   luau -O0 tests/conformance/zero_based.luau
--   luau -O2 tests/conformance/zero_based.luau
--   luau --codegen-cold -O2 tests/conformance/zero_based.luau
--   luau --codegen-lazy -O2 tests/conformance/zero_based.luau
--   luau-analyze tests/conformance/zero_based.luau
--
-- Contract:
--   * Every Lua-visible sequence position starts at 0.
--   * Every positional range is [start, end).
--   * Lengths and counts remain counts.
--   * Negative string/UTF-8 positions retain from-end meaning.
--   * Existing not-found APIs return nil.
--   * table.maxn({}) returns nil because every number, including -1 and 0,
--     can be a valid numeric table key.
--   * Numeric for loops use an exclusive end for either step direction.
--   * C API stack indexes, stack levels, bit widths, and pattern %1 references
--     are not sequence positions and remain unchanged.
--
-- This is a Lua-visible semantic completion gate. It cannot prove physical
-- array-part placement, performance, documentation, or editor autocomplete.

type function luauaTypeRuntimeConformance()
  local constructed = {"a", "b"}
  assert(constructed[0] == "a")
  assert(constructed[1] == "b")
  assert(constructed[2] == nil)
  assert(#constructed == 2)

  local generator, state, control = ipairs({[0] = "a"})
  local first = generator(state, control)
  assert(first == 0)

  local unionComponents = types.unionof(types.string, types.number):components()
  assert(unionComponents[0] ~= nil)
  assert(unionComponents[1] ~= nil)
  assert(unionComponents[2] == nil)

  local generic = types.generic("T")
  local fn = types.newfunction(
    {head = {[0] = types.string, [1] = types.number}},
    {head = {[0] = types.boolean}},
    {[0] = generic}
  )

  local parameters = fn:parameters().head
  local returns = fn:returns().head
  local generics = fn:generics()

  assert(parameters ~= nil)
  assert(parameters[0] == types.string)
  assert(parameters[1] == types.number)
  assert(parameters[2] == nil)

  assert(returns ~= nil)
  assert(returns[0] == types.boolean)
  assert(returns[1] == nil)

  assert(generics[0] == generic)
  assert(generics[1] == nil)

  return types.boolean
end

type _LuauaTypeRuntimeConformance = luauaTypeRuntimeConformance<>

local passed = 0
local failed = 0
local serial = 0

local function equal(actual: any, expected: any)
  assert(
    actual == expected,
    "expected " .. tostring(expected) .. ", got " .. tostring(actual)
  )
end

local function test(name: string, body: () -> ())
  serial += 1

  local ok, message = pcall(body)
  if ok then
    passed += 1
    print("ok", serial, "-", name)
  else
    failed += 1
    print("not ok", serial, "-", name, "-", message)
  end
end

-- Core table representation and bytecode paths.

test("table literal starts at index 0", function()
  local t = {"a", "b"}
  equal(t[0], "a")
  equal(t[1], "b")
  equal(t[2], nil)
end)

test("multi-batch list constructor remains zero-based", function()
  local t = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16}
  equal(t[0], 0)
  equal(t[16], 16)
  equal(#t, 17)
end)

test("constructor tail multireturn starts at the next index", function()
  local function tail()
    return "b", "c"
  end

  local t = {"a", tail()}
  equal(t[0], "a")
  equal(t[1], "b")
  equal(t[2], "c")
  equal(#t, 3)
end)

test("mixed constructors assign list fields from index 0", function()
  local t = {[1] = "b", "a"}
  equal(t[0], "a")
  equal(t[1], "b")
end)

test("array growth and rehash preserve index 0", function()
  local t = {}
  local index = 0

  while index < 128 do
    t[index] = index
    index += 1
  end

  index = 0
  while index < 128 do
    equal(t[index], index)
    index += 1
  end

  equal(#t, 128)
end)

test("constant small-index read and write accept 0", function()
  local t = {}
  t[0] = "x"
  equal(t[0], "x")
end)

test("small-index bytecode boundary preserves adjacent keys", function()
  local t = {}
  t[255] = "small"
  t[256] = "generic"
  equal(t[255], "small")
  equal(t[256], "generic")
end)

test("dynamic integer read and write accept 0", function()
  local t = {}
  local index = 0
  t[index] = "x"
  equal(t[index], "x")
end)

test("rawget and rawset accept index 0", function()
  local t = {}
  rawset(t, 0, "x")
  equal(rawget(t, 0), "x")
end)

test("__index receives key 0 unchanged", function()
  local t: any = setmetatable({}, {
    __index = function(_, key)
      return key
    end,
  })

  equal(t[0], 0)
end)

test("__newindex receives key 0 unchanged", function()
  local received = -1
  local t: any = setmetatable({}, {
    __newindex = function(_, key)
      received = key
    end,
  })

  t[0] = "x"
  equal(received, 0)
end)

test("table length is the dense element count", function()
  local t = {[0] = "a", [1] = "b", [2] = "c"}
  equal(#t, 3)
end)

test("length cache tracks insertion and removal at index 0", function()
  local t = {}
  t[0] = "a"
  equal(#t, 1)
  t[0] = nil
  equal(#t, 0)
end)

test("rawlen returns counts and bypasses __len", function()
  local t = setmetatable({[0] = "a"}, {
    __len = function(_self)
      return 9
    end,
  })

  equal(#t, 9)
  equal(rawlen(t), 1)
  equal(rawlen("ab"), 2)
end)

test("table.clone preserves index 0", function()
  local copy = table.clone({[0] = "a"})
  equal(copy[0], "a")
  equal(#copy, 1)
end)

test("table.clear removes index 0", function()
  local t = {[0] = "a"}
  table.clear(t)
  equal(t[0], nil)
  equal(#t, 0)
end)

-- Iteration paths.

test("the ipairs generator returns index 0 first", function()
  local iterator, state, control = ipairs({[0] = "a"})
  local index, value = (iterator :: any)(state, control)
  equal(index, 0)
  equal(value, "a")
end)

test("optimized ipairs starts at 0 and stops at the first hole", function()
  local count = 0

  for index, value in ipairs({[0] = "a", [2] = "c"}) do
    equal(index, 0)
    equal(value, "a")
    count += 1
  end

  equal(count, 1)
end)

test("next treats key 0 as data, not its initial sentinel", function()
  local t = {[0] = "a"}

  local key, value = next(t, nil)
  equal(key, 0)
  equal(value, "a")
  equal(next(t, 0), nil)
end)

test("pairs exposes key 0", function()
  local count = 0

  for key, value in pairs({[0] = "a"}) do
    equal(key, 0)
    equal(value, "a")
    count += 1
  end

  equal(count, 1)
end)

test("generalized table iteration visits dense indexes in 0-based order", function()
  local expected = 0

  for index, value in {[0] = "a", [1] = "b"} do
    equal(index, expected)
    equal(value, if index == 0 then "a" else "b")
    expected += 1
  end

  equal(expected, 2)
end)

test("table.foreach exposes key 0", function()
  local seen = false

  table.foreach({[0] = "a"}, function(key, value)
    equal(key, 0)
    equal(value, "a")
    seen = true
  end)

  equal(seen, true)
end)

test("table.foreachi starts at index 0", function()
  local seen = false

  table.foreachi({[0] = "a"}, function(index, value)
    equal(index, 0)
    equal(value, "a")
    seen = true
  end)

  equal(seen, true)
end)

-- Table standard library.

test("table.getn returns a count", function()
  equal(table.getn({[0] = "a", [1] = "b"}), 2)
end)

test("table.maxn distinguishes empty, -1, and 0", function()
  equal(table.maxn({}), nil)
  equal(table.maxn({[-1] = "negative"}), -1)
  equal(table.maxn({[0] = "zero"}), 0)
end)

test("table.concat defaults to [0, #t)", function()
  equal(table.concat({[0] = "a", [1] = "b"}, ","), "a,b")
end)

test("table.concat uses an exclusive end", function()
  equal(
    table.concat({[0] = "a", [1] = "b", [2] = "c", [3] = "d"}, ",", 1, 3),
    "b,c"
  )
end)

test("table.insert append writes at index #t", function()
  local t = {}
  table.insert(t, "a")
  equal(t[0], "a")
  equal(#t, 1)
end)

test("table.insert accepts positions 0 and #t", function()
  local t = {[0] = "b"}
  table.insert(t, 0, "a")
  table.insert(t, #t, "c")
  equal(table.concat(t, ""), "abc")
end)

test("table.remove without an index removes #t - 1", function()
  local t = {[0] = "a", [1] = "b"}
  equal(table.remove(t), "b")
  equal(t[0], "a")
  equal(#t, 1)
end)

test("table.remove accepts index 0", function()
  local t = {[0] = "a", [1] = "b"}
  equal(table.remove(t, 0), "a")
  equal(t[0], "b")
  equal(#t, 1)
end)

test("table.remove handles an empty sequence without underflow", function()
  equal(table.remove({}), nil)
end)

test("table.sort sorts [0, #t)", function()
  local t = {[0] = 2, [1] = 1}
  table.sort(t)
  equal(t[0], 1)
  equal(t[1], 2)
end)

test("table.sort handles an empty sequence", function()
  local t = {}
  table.sort(t)
  equal(#t, 0)
end)

test("table.pack stores varargs from index 0", function()
  local t = table.pack("a", nil, "c")
  equal(t[0], "a")
  equal(t[1], nil)
  equal(t[2], "c")
  equal(t.n, 3)
end)

test("table.unpack defaults to [0, #t)", function()
  local a, b, c =
    table.unpack({[0] = "a", [1] = "b", [2] = "c"})
  equal(a, "a")
  equal(b, "b")
  equal(c, "c")
end)

test("table.unpack uses an exclusive end", function()
  local b, c, d =
    table.unpack({[0] = "a", [1] = "b", [2] = "c", [3] = "d"}, 1, 3)
  equal(b, "b")
  equal(c, "c")
  equal(d, nil)
end)

test("table.unpack handles [0, 0) as no values", function()
  equal(select("#", table.unpack({})), 0)
end)

test("global unpack defaults to [0, #t)", function()
  local a, b = unpack({[0] = "a", [1] = "b"})
  equal(a, "a")
  equal(b, "b")
end)

test("table.move copies [start, end) to destination index 0", function()
  local destination = {}
  table.move({[0] = "a", [1] = "b", [2] = "c"}, 1, 3, 0, destination)
  equal(destination[0], "b")
  equal(destination[1], "c")
  equal(destination[2], nil)
end)

test("table.move preserves overlapping half-open copies", function()
  local t = {[0] = "a", [1] = "b", [2] = "c"}
  table.move(t, 0, 2, 1)
  equal(t[0], "a")
  equal(t[1], "a")
  equal(t[2], "b")
end)

test("table.create fills [0, n)", function()
  local t = table.create(3, "x")
  equal(t[0], "x")
  equal(t[2], "x")
  equal(t[3], nil)
  equal(#t, 3)
end)

test("table.find defaults to index 0", function()
  equal(table.find({[0] = "x", [1] = "y"}, "x"), 0)
end)

test("table.find starts at its explicit start index", function()
  equal(table.find({[0] = "x", [1] = "y", [2] = "x"}, "x", 1), 2)
end)

test("table.find returns nil when absent", function()
  equal(table.find({[0] = "x"}, "missing"), nil)
end)

-- Numeric for loops.

test("positive numeric for uses an exclusive end", function()
  local output = ""

  for index = 0, 3 do
    output ..= tostring(index)
  end

  equal(output, "012")
end)

test("numeric for performs zero iterations when start equals end", function()
  local function count(startValue: number, endValue: number)
    local result = 0

    for _ = startValue, endValue do
      result += 1
    end

    return result
  end

  equal(count(2, 2), 0)
end)

test("negative numeric for excludes its end", function()
  local output = ""

  for index = 3, 0, -1 do
    output ..= tostring(index)
  end

  equal(output, "321")
end)

test("non-unit numeric for excludes its end", function()
  local output = ""

  for index = 0, 5, 2 do
    output ..= tostring(index)
  end

  equal(output, "024")
end)

test("fractional numeric for excludes its end", function()
  local count = 0

  for _ = 0, 1, 0.5 do
    count += 1
  end

  equal(count, 2)
end)

-- Vararg indexing.

test("select is zero-based while counts and negative indexes remain intact", function()
  local function check(...)
    local a, b, c = select(0, ...)
    equal(a, "a")
    equal(b, "b")
    equal(c, "c")
    equal(select(1, ...), "b")
    equal(select(-1, ...), "c")
    equal(select("#", ...), 3)
  end

  check("a", "b", "c")
end)

-- String positions and pattern engine.

test("string method suffix defaults its end to #s", function()
  local name = "Lua"
  equal(name:sub(1), "ua")
end)

test("string length APIs remain byte counts", function()
  equal(#"abc", 3)
  equal(string.len("abc"), 3)
end)

test("string.sub uses [start, end)", function()
  equal(string.sub("abcd", 1, 3), "bc")
end)

test("string.sub permits an empty half-open range", function()
  equal(string.sub("abc", 1, 1), "")
end)

test("negative string positions remain relative to the end", function()
  equal(string.sub("abcd", -2), "cd")
  equal(string.sub("abcd", 0, -1), "abc")
end)

test("string.byte defaults to the one-byte range [0, 1)", function()
  local first, second = string.byte("ab")
  equal(first, string.byte("a"))
  equal(second, nil)
end)

test("string.byte uses [start, end)", function()
  local a, b, c = string.byte("abc", 0, 2)
  equal(a, string.byte("a"))
  equal(b, string.byte("b"))
  equal(c, nil)
end)

test("plain string.find returns [start, end)", function()
  local start, finish = string.find("Luajito", "jito", 0, true)
  equal(start, 3)
  equal(finish, 7)
end)

test("pattern string.find returns [start, end)", function()
  local start, finish = string.find("aa1", "a+")
  equal(start, 0)
  equal(finish, 2)
end)

test("string.find honors an explicit start index", function()
  local start, finish = string.find("aba", "a", 1, true)
  equal(start, 2)
  equal(finish, 3)
end)

test("string.find returns nil when absent", function()
  equal(string.find("nowhere", "tobe"), nil)
end)

test("an empty match at index 0 returns [0, 0)", function()
  local start, finish = string.find("", "")
  equal(start, 0)
  equal(finish, 0)
end)

test("string.find accepts a negative relative start", function()
  local start, finish = string.find("aba", "a", -1, true)
  equal(start, 2)
  equal(finish, 3)
end)

test("string.match uses a zero-based start index", function()
  equal(string.match("1a2", "%d", 1), "2")
end)

test("pattern position captures are zero-based", function()
  local start, finish = string.match("ab", "()a()")
  equal(start, 0)
  equal(finish, 1)
end)

test("string.gmatch advances through zero-length position captures", function()
  local iterator = string.gmatch("a", "()")
  equal(iterator(), 0)
  equal(iterator(), 1)
  equal(iterator(), nil)
end)

test("string.gsub passes zero-based position captures", function()
  local position = -1
  local result, count = string.gsub("ab", "()a", function(captured)
    position = captured
    return "x"
  end)

  equal(result, "xb")
  equal(count, 1)
  equal(position, 0)
end)

test("string.split returns a zero-based array", function()
  local parts = string.split("a,b", ",")
  equal(parts[0], "a")
  equal(parts[1], "b")
  equal(parts[2], nil)
  equal(#parts, 2)
end)

test("string.unpack defaults to start index 0 and returns the next boundary", function()
  local value, nextPosition = string.unpack("I1", string.char(10, 20))
  equal(value, 10)
  equal(nextPosition, 1)
end)

test("string.unpack accepts an explicit zero-based start", function()
  local value, nextPosition = string.unpack("I1", string.char(10, 20), 1)
  equal(value, 20)
  equal(nextPosition, 2)
end)

test("empty string.unpack returns valid boundary 0", function()
  equal(string.unpack("", "", 0), 0)
end)

test("pattern capture references remain 1-based ordinals", function()
  equal(string.match("aa", "(a)%1"), "a")
end)

-- UTF-8 byte positions.

test("utf8.codes returns zero-based byte offsets", function()
  local count = 0

  for offset, codepoint in utf8.codes("汉字") do
    if count == 0 then
      equal(offset, 0)
      equal(codepoint, 27721)
    else
      equal(offset, 3)
      equal(codepoint, 23383)
    end

    count += 1
  end

  equal(count, 2)
end)

test("utf8.codepoint uses [start, end)", function()
  local first, second = utf8.codepoint("汉字", 0, 3)
  equal(first, 27721)
  equal(second, nil)
end)

test("utf8.len uses [start, end)", function()
  equal(utf8.len("汉字", 0, 3), 1)
end)

test("utf8.len defaults to the full [0, #s) range", function()
  equal(utf8.len("汉字"), 2)
end)

test("utf8.len reports malformed byte position 0 without sentinel collision", function()
  local count, badPosition = utf8.len(string.char(255))
  equal(count, nil)
  equal(badPosition, 0)
end)

test("utf8.offset defaults its byte position to 0", function()
  equal(utf8.offset("汉字", 1), 0)
end)

test("utf8.offset keeps n = 0 current-codepoint semantics", function()
  equal(utf8.offset("汉字", 0, 4), 3)
end)

test("utf8.offset handles negative codepoint movement", function()
  equal(utf8.offset("汉字", -1, 3), 0)
end)

test("negative utf8.offset defaults from the end boundary", function()
  equal(utf8.offset("汉字", -1), 3)
end)

test("utf8.offset returns nil when no codepoint exists", function()
  equal(utf8.offset("汉", 2, 0), nil)
end)

-- APIs that are already zero-based and must remain so.

test("buffer offsets stay zero-based and length stays a count", function()
  local bytes = buffer.create(2)
  buffer.writeu8(bytes, 0, 42)
  equal(buffer.readu8(bytes, 0), 42)
  equal(buffer.len(bytes), 2)
end)

test("buffer ranges remain offset-plus-count", function()
  local source = buffer.fromstring("ab")
  local target = buffer.create(2)
  buffer.copy(target, 0, source, 0, 2)
  equal(buffer.tostring(target), "ab")
end)

test("bit32 fields remain zero-based", function()
  equal(bit32.extract(1, 0), 1)
  equal(bit32.replace(0, 1, 0), 1)
end)

if failed > 0 then
  error(
    string.format(
      "Luaua zero-base conformance failed: %d passed, %d failed",
      passed,
      failed
    ),
    0
  )
end

print(string.format("Luaua zero-base conformance passed: %d tests", passed))

return "OK"
