std = "luajit"
codes = true

-- Don't complain about the `vim` global (injected by Neovim)
globals = {
    "vim",
}

-- Ignore the spec/ files importing `describe`, `it`, etc.
files["spec/**/*.lua"] = {
    std = "+busted",
}

-- Allow some common warnings to be suppressed
ignore = {
    "212", -- Unused argument
    "631", -- Line is too long
}
