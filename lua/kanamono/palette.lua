local util = require("kanamono.util")

local M = {}

--- Wave and Lotus colors adapted from rebelot/kanagawa.nvim (MIT).
--- Lotus accents are darkened for readable text on paper and UI surfaces.
M.base = {
  light = {
    bg = "#f2ecbc", fg = "#353545",
    red = "#a52b3d", orange = "#915000", yellow = "#68602f",
    green = "#46612f", cyan = "#3d625c", azure = "#624c83", blue = "#3b5685",
  },
  dark = {
    bg = "#1f1f28", fg = "#dcd7ba",
    red = "#ed7b86", orange = "#ffa066", yellow = "#e6c384",
    green = "#98bb6c", cyan = "#7aa89f", azure = "#ad99ce", blue = "#7e9cd8",
  },
}

---@class kanamono.BasePalette
---@field bg string
---@field fg string
---@field red string
---@field orange string
---@field yellow string
---@field green string
---@field cyan string
---@field azure string
---@field blue string

---@class kanamono.Colors: kanamono.BasePalette
---@field variant "light"|"dark"
---@field none "NONE"
---@field gutter string     distinct number/sign/fold column background
---@field bg_float string
---@field bg_dim string      background for inactive windows (dim_inactive)
---@field surface1 string    cursorline, subtle rows
---@field surface2 string    selection, active tab, statusline
---@field surface3 string    stronger selection / match paren
---@field select string      current item in lists: popup menu, pickers, file explorers
---@field border string
---@field muted string       UI chrome only (line numbers, whitespace) — never code
---@field comment string     comments: fg faded toward bg, still WCAG AA
---@field accent string      single UI focal color (matches, prompts)
---@field search string      background for search matches
---@field code { string: string, func: string, type: string, constant: string, keyword: string, operator: string }
---@field git { add: string, change: string, delete: string }
---@field diag { error: string, warn: string, info: string, hint: string, ok: string }

--- Build the full, derived color table for a variant.
---@param variant "light"|"dark"
---@param opts kanamono.Config
---@return kanamono.Colors
function M.get(variant, opts)
  local b = vim.deepcopy(M.base[variant])
  local c = b --[[@as kanamono.Colors]]
  local is_light = variant == "light"
  local blend = util.blend

  c.variant = variant
  c.none = "NONE"

  -- Soft tinted surfaces keep the Wave/Lotus character.
  local tint = blend(c.azure, c.fg, 0.5)
  c.surface1 = blend(tint, c.bg, is_light and 0.05 or 0.06)
  c.surface2 = blend(tint, c.bg, is_light and 0.08 or 0.085)
  c.surface3 = blend(tint, c.bg, is_light and 0.14 or 0.13)
  -- Current item in every list (Pmenu, pickers, explorers). surface2 is too
  -- faint to spot at a glance, so both variants use surface3 (about the same
  -- perceived lightness step from bg in light and dark).
  c.select = c.surface3
  c.border = blend(tint, c.bg, is_light and 0.24 or 0.22)
  c.muted = blend(c.fg, c.bg, is_light and 0.64 or 0.50)
  -- Comments step back from the code without dropping below AA (4.5:1): fg
  -- with the UI's blue lean, faded toward bg. Italic does the rest.
  c.comment = blend(blend(tint, c.fg, 0.35), c.bg, is_light and 0.84 or 0.7)
  c.bg_dim = is_light and blend(c.fg, c.bg, 0.03) or util.darken(c.bg, 0.12)
  c.gutter = is_light and "#e7dfb0" or "#2a2a37"
  c.bg_float = c.bg
  c.accent = c.blue
  -- Tinted accent, same hue family as the UI so it stays clean. Stronger than
  -- surface3 so it reads apart from Visual.
  c.search = blend(c.accent, c.bg, is_light and 0.25 or 0.32)

  local mono = opts.mono
  c.code = {
    keyword = mono and c.fg or c.azure,
    operator = mono and c.fg or c.yellow,
    string = mono and c.fg or c.green,
    func = mono and c.fg or c.blue,
    type = mono and c.fg or c.cyan,
    constant = mono and c.fg or c.orange,
  }
  c.git = { add = c.green, change = c.blue, delete = c.red }
  c.diag = { error = c.red, warn = c.yellow, info = c.blue, hint = c.cyan, ok = c.green }

  if opts.on_colors then
    opts.on_colors(c, variant)
  end
  return c
end

return M
