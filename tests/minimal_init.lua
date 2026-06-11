vim.opt.runtimepath:prepend(vim.fn.getcwd())

local tests = {}

function _G.test(name, fn)
  table.insert(tests, { name = name, fn = fn })
end

function _G.eq(actual, expected)
  assert(vim.deep_equal(actual, expected), string.format("expected %s, got %s", vim.inspect(expected), vim.inspect(actual)))
end

function _G.ok(value, message)
  assert(value, message or "expected truthy value")
end

function _G.run_tests()
  local failed = 0
  for _, t in ipairs(tests) do
    local ok_, err = pcall(t.fn)
    if ok_ then
      print("ok - " .. t.name)
    else
      failed = failed + 1
      print("not ok - " .. t.name .. ": " .. tostring(err))
    end
  end
  if failed > 0 then
    error(failed .. " test(s) failed")
  end
end
