--- Simplified structured logger for lsp-overloads.nvim.
--- Provides debug/info/warn/error log levels.
--- Output is controlled by vim.g.lsp_overloads_log_level (or config).
--- When file logging is enabled, writes to stdpath("log")/lsp-overloads.log.

---@class lsp-overloads.Logger
---@field name string The logger name / prefix
---@field _level integer The numeric log level threshold

local M = {}

---@enum lsp-overloads.LogLevel
M.levels = {
  debug = vim.log.levels.DEBUG,
  info = vim.log.levels.INFO,
  warn = vim.log.levels.WARN,
  error = vim.log.levels.ERROR,
}

local _level_names = {
  [vim.log.levels.DEBUG] = "DEBUG",
  [vim.log.levels.INFO] = "INFO",
  [vim.log.levels.WARN] = "WARN",
  [vim.log.levels.ERROR] = "ERROR",
}

local _log_file = nil

local function _get_file_handle()
  if _log_file then
    return _log_file
  end
  local log_dir = vim.fn.stdpath("log")
  local path = log_dir .. "/lsp-overloads.log"
  local fh = io.open(path, "a")
  _log_file = fh
  return fh
end

local function _resolve_level()
  local g = vim.g.lsp_overloads_log_level
  if type(g) == "string" then
    return M.levels[g:lower()] or vim.log.levels.WARN
  elseif type(g) == "number" then
    return g
  end
  return vim.log.levels.WARN
end

---@param name string The logger name used as prefix in output
---@return lsp-overloads.Logger
function M.new(name)
  local logger = {
    name = name,
    _level = nil, -- resolved lazily
  }

  local function _log(level, msg)
    local threshold = logger._level or _resolve_level()
    if level < threshold then
      return
    end
    local entry = string.format("[lsp-overloads/%s] %s: %s", _level_names[level] or "?", logger.name, msg)
    if vim.g.lsp_overloads_log_file then
      local fh = _get_file_handle()
      if fh then
        fh:write(os.date("%Y-%m-%d %H:%M:%S") .. " " .. entry .. "\n")
        fh:flush()
      end
    end
    if level >= vim.log.levels.WARN then
      vim.notify(entry, level)
    elseif vim.g.lsp_overloads_log_console then
      vim.notify(entry, level)
    end
  end

  ---@param msg string
  function logger.debug(msg)
    _log(vim.log.levels.DEBUG, msg)
  end

  ---@param fmt string
  ---@param ... any
  function logger.fmt_debug(fmt, ...)
    _log(vim.log.levels.DEBUG, string.format(fmt, ...))
  end

  ---@param msg string
  function logger.info(msg)
    _log(vim.log.levels.INFO, msg)
  end

  ---@param fmt string
  ---@param ... any
  function logger.fmt_info(fmt, ...)
    _log(vim.log.levels.INFO, string.format(fmt, ...))
  end

  ---@param msg string
  function logger.warn(msg)
    _log(vim.log.levels.WARN, msg)
  end

  ---@param fmt string
  ---@param ... any
  function logger.fmt_warn(fmt, ...)
    _log(vim.log.levels.WARN, string.format(fmt, ...))
  end

  ---@param msg string
  function logger.error(msg)
    _log(vim.log.levels.ERROR, msg)
  end

  ---@param fmt string
  ---@param ... any
  function logger.fmt_error(fmt, ...)
    _log(vim.log.levels.ERROR, string.format(fmt, ...))
  end

  return logger
end

return M
