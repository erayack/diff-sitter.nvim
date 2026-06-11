std = "lua51"

-- Neovim plugin globals and the tiny headless test harness helpers.
globals = {
  "vim",
  "test",
  "eq",
  "ok",
  "run_tests",
}

files["tests/minimal_init.lua"] = {
  globals = {
    "vim",
    "test",
    "eq",
    "ok",
    "run_tests",
  },
}

-- Keep lint focused on correctness for this small plugin; formatting is not
-- enforced here because stylua is not currently installed in this environment.
max_line_length = false
