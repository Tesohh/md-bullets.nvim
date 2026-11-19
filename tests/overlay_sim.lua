-- Pure-Lua check of the fixed-window-column overlay logic used by set_mark.
-- Every '#' glyph of a heading must be covered by exactly one extmark cell,
-- both standalone (offset 0) and with an md-indent inline shift.

local function simulate(line, offset)
  local level = #line:match("^(#+)%s")
  -- '#' number k (0-based) sits at window column offset + k
  local covered = {}
  for col = 0, level - 2 do
    covered[offset + col] = (covered[offset + col] or 0) + 1 -- space cover
  end
  covered[offset + level - 1] = (covered[offset + level - 1] or 0) + 1 -- bullet
  return covered, level
end

local function check(line, offset)
  local covered, level = simulate(line, offset)
  for k = 0, level - 1 do
    local cell = offset + k
    if not covered[cell] or covered[cell] ~= 1 then
      print(string.format("FAIL %q offset=%d: '#' %d at col %d covered %d times", line, offset, k, cell, covered[cell] or 0))
      return false
    end
    if covered[cell] > 1 then
      print(string.format("FAIL %q offset=%d: cell %d covered twice", line, offset, cell))
      return false
    end
  end
  if covered[offset + level] then
    print(string.format("FAIL %q offset=%d: cell past last '#' covered", line, offset))
    return false
  end
  print(string.format("ok   %q offset=%d: %d '#' cells, each covered exactly once", line, offset, level))
  return true
end

local passed, failed = 0, 0
for _, line in ipairs({ "# H", "### T", "########## Long" }) do
  for _, offset in ipairs({ 0, 1, 3 }) do
    if check(line, offset) then
      passed = passed + 1
    else
      failed = failed + 1
    end
  end
end

print(("done: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
