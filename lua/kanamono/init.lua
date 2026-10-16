---@class kanamono
local M = {}

--- Bump to invalidate every user's compiled cache after changing highlights.
M.version = "0.1.2"

local cache_dir = vim.fn.stdpath("cache") .. "/kanamono"
local configured = false
local key ---@type string?

---@param opts? kanamono.Config
function M.setup(opts)
  require("kanamono.config").set(opts)
  configured = true
  key = nil
end

---@return kanamono.Config
local function options()
  return require("kanamono.config").options
end

---@return string
local function cache_key()
  if not key then
    key = configured and require("kanamono.config").hash() or ("default-" .. M.version)
  end
  return key
end

---@param name string
---@return kanamono.Variant
local function resolve_variant(name)
  if name == "kanamono-light" then
    return "light"
  elseif name == "kanamono-dark" then
    return "dark"
  end
  local v = options().variant
  if v == "light" or v == "dark" then
    return v
  end
  return vim.o.background == "light" and "light" or "dark"
end

--- Full palette (base + derived) for a variant, after `on_colors`.
---@param variant? kanamono.Variant defaults to the current 'background'
---@return kanamono.Colors
function M.colors(variant)
  return require("kanamono.palette").get(variant or resolve_variant("kanamono"), options())
end

--- Final highlight table for a variant, after `on_highlights`.
---@param variant? kanamono.Variant
---@return table<string, kanamono.Style>
function M.highlights(variant)
  local o = options()
  return require("kanamono.groups").get(M.colors(variant), o)
end

---@param name string
---@param variant kanamono.Variant
---@return string
local function build(name, variant)
  local o = options()
  local c = require("kanamono.palette").get(variant, o)
  local hl = require("kanamono.groups").get(c, o)
  local term = o.terminal_colors and require("kanamono.terminal").ansi(c) or nil
  return require("kanamono.compiler").source(name, variant, hl, term)
end

---@param prefix string
---@param keep string
local function prune(prefix, keep)
  for file in vim.fs.dir(cache_dir) do
    if vim.startswith(file, prefix) and file ~= keep then
      os.remove(cache_dir .. "/" .. file)
    end
  end
end

--- Entry point used by `colors/*.lua`.
---@param name? "kanamono"|"kanamono-light"|"kanamono-dark"
function M.load(name)
  name = name or "kanamono"
  local variant = resolve_variant(name)

  if not options().cache then
    return assert(load(build(name, variant), "=kanamono"))()
  end

  local prefix = name .. "_" .. variant .. "_"
  local file = prefix .. cache_key()
  local path = cache_dir .. "/" .. file
  local fn = loadfile(path)
  if not fn then
    fn = require("kanamono.compiler").write(build(name, variant), path)
    prune(prefix, file)
  end
  fn()
end

--- Rebuild the cache for the active colorscheme (e.g. after editing an
--- `on_highlights` closure whose upvalues changed).
function M.compile()
  M.clear_cache()
  local name = vim.g.colors_name
  if name and vim.startswith(name, "kanamono") then
    vim.cmd.colorscheme(name)
  end
end

function M.clear_cache()
  vim.fn.delete(cache_dir, "rf")
  key = nil
end

--- Generate terminal/tool themes (ghostty, kitty, lazygit) from the palette.
---@param dir? string output directory, defaults to `<plugin>/extras`
function M.extras(dir)
  return require("kanamono.extras").generate(dir)
end

return M
