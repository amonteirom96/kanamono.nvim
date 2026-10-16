-- nvim --headless -u NONE --cmd "set rtp^=." -l tests/smoke.lua
local ok_all = true
local function check(cond, msg)
  if not cond then ok_all = false; print("FAIL: " .. msg) end
end

vim.env.XDG_CACHE_HOME = vim.fn.tempname()
local ex = require("kanamono")

for _, name in ipairs({ "kanamono-light", "kanamono-dark", "kanamono" }) do
  local ok, err = pcall(vim.cmd.colorscheme, name)
  check(ok, name .. ": " .. tostring(err))
  check(vim.g.colors_name == name, name .. ": colors_name=" .. tostring(vim.g.colors_name))
  local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
  check(normal.fg and normal.bg, name .. ": Normal has fg/bg")
  -- Kanagawa syntax roles, with red reserved for errors and deletions.
  local c = ex.colors(vim.o.background)
  local want = {
    String = c.green, ["@string"] = c.green,
    Function = c.blue, ["@function.call"] = c.blue, ["@function.method"] = c.blue,
    Type = c.cyan, ["@type"] = c.cyan, ["@type.builtin"] = c.cyan, ["@constructor"] = c.cyan,
    Number = c.orange, Boolean = c.orange, ["@constant"] = c.orange, ["@constant.builtin"] = c.orange, ["@number"] = c.orange,
  }
  want.Keyword, want["@keyword"], want["@operator"] = c.code.keyword, c.code.keyword, c.code.operator
  want.Comment, want["@comment"] = c.comment, c.comment
  for _, g in ipairs({ "@variable", "@property", "@module" }) do
    want[g] = c.fg
  end
  for g, color in pairs(want) do
    local h = vim.api.nvim_get_hl(0, { name = g, link = false })
    check(h.fg == tonumber(color:sub(2), 16), ("%s: %s fg %s ~= %s"):format(name, g, tostring(h.fg), color))
  end
  for _, group in ipairs({ "LineNr", "LineNrAbove", "LineNrBelow", "CursorLineNr", "SignColumn", "FoldColumn", "CursorLineSign", "CursorLineFold", "DiagnosticSignError" }) do
    local h = vim.api.nvim_get_hl(0, { name = group, link = false })
    check(h.bg == tonumber(c.gutter:sub(2), 16) and h.bg == normal.bg, name .. ": uniform gutter " .. group)
  end
  local ranges = vim.api.nvim_get_hl(0, { name = "MiniPickMatchRanges", link = false })
  check(ranges.fg ~= normal.fg and ranges.bg == nil, name .. ": picker matches have colored text without background")
  check(not ranges.nocombine, name .. ": picker matches combine with row selection")
  local current = vim.api.nvim_get_hl(0, { name = "MiniPickMatchCurrent", link = false })
  check(current.bg ~= normal.bg and current.bg ~= ranges.bg, name .. ": picker selected row distinct from matches")
  check(current.fg == nil, name .. ": picker selected row preserves match and icon colors")
  local contrast = require("kanamono.util").contrast
  local match_color = ("#%06x"):format(ranges.fg)
  check(contrast(match_color, c.bg) >= 4.5, name .. ": picker match text readable")
  check(contrast(match_color, ("#%06x"):format(current.bg)) >= 4.5, name .. ": selected picker match text readable")
  -- color where it matters
  local add = vim.api.nvim_get_hl(0, { name = "GitSignsAdd" }).fg
  local del = vim.api.nvim_get_hl(0, { name = "GitSignsDelete" }).fg
  check(add and del and add ~= del and add ~= normal.fg, name .. ": gitsigns colored")
  check(vim.api.nvim_get_hl(0, { name = "BlinkCmpKindFunction" }).fg ~= vim.api.nvim_get_hl(0, { name = "BlinkCmpKindVariable" }).fg, name .. ": kinds differ")
  check(vim.api.nvim_get_hl(0, { name = "MiniIconsRed" }).fg ~= nil, name .. ": mini.icons")
  check(vim.g.terminal_color_1 ~= nil, name .. ": terminal colors")
end

-- background switch follows for "kanamono"
vim.cmd.colorscheme("kanamono")
vim.o.background = "light"
local light_bg = vim.api.nvim_get_hl(0, { name = "Normal" }).bg
check(light_bg == tonumber(ex.colors("light").bg:sub(2), 16), "auto variant follows background=light")
vim.o.background = "dark"
check(vim.api.nvim_get_hl(0, { name = "Normal" }).bg == tonumber(ex.colors("dark").bg:sub(2), 16), "auto variant follows background=dark")

-- cache written and setup invalidates key
local dir = vim.fn.stdpath("cache") .. "/kanamono"
check(#vim.fn.readdir(dir) >= 3, "cache files exist")
ex.setup({ transparent = true })
vim.cmd.colorscheme("kanamono-dark")
check(vim.api.nvim_get_hl(0, { name = "Normal" }).bg == nil, "transparent applied after setup")
ex.setup({ on_highlights = function(hl) hl.Normal.fg = "#ff0000" end })
vim.cmd.colorscheme("kanamono-dark")
check(vim.api.nvim_get_hl(0, { name = "Normal" }).fg == 0xff0000, "on_highlights applied")

-- Red is reserved for errors/deletions and picker query matches.
for _, v in ipairs({ "light", "dark" }) do
  local c = ex.colors(v)
  local allowed = {
    Error = true, ErrorMsg = true, StderrMsg = true, NvimInternalError = true, SpellBad = true,
    healthError = true, RedrawDebugRecompose = true, MasonError = true, LazyTaskError = true,
    MiniPickMatchRanges = true,
    ["@comment.error"] = true, ["@lsp.type.unresolvedReference"] = true,
  }
  for n, spec in pairs(ex.highlights(v)) do
    local red = spec.fg == c.red or spec.bg == c.red or spec.sp == c.red
    local meaning = n:find("Error") or n:find("Delete") or n:find("Removed") or n:find("Remove") or n:find("[Dd]iff") or n:find("minus") or n:find("Topdelete")
    check(not red or allowed[n] or meaning, ("%s: %s uses red outside errors/deletions"):format(v, n))
  end
  check(c.comment ~= c.fg and require("kanamono.util").contrast(c.comment, c.bg) >= 4.5, v .. ": comment dimmer than fg, still AA")
end

-- ANSI: TUIs draw borders/text in white and put black text on colored
-- highlights (lazysql, htop), so both must stay readable in both variants
for _, v in ipairs({ "light", "dark" }) do
  local c = ex.colors(v)
  local a = require("kanamono.terminal").ansi(c)
  local contrast = require("kanamono.util").contrast
  for _, i in ipairs({ 7, 15 }) do
    check(contrast(a[i], c.bg) >= 4.5, ("%s: ansi %d readable on bg"):format(v, i))
  end
  for i = 1, 6 do
    check(contrast(a[0], a[i]) >= 4.5, ("%s: ansi 0 readable on ansi %d"):format(v, i))
  end
end

-- mono = true: pure monochrome
ex.setup({ mono = true })
vim.cmd.colorscheme("kanamono-dark")
local nfg = vim.api.nvim_get_hl(0, { name = "Normal" }).fg
check(vim.api.nvim_get_hl(0, { name = "String", link = false }).fg == nfg, "mono: String in fg")
check(vim.api.nvim_get_hl(0, { name = "@function.call", link = false }).fg == nfg, "mono: @function.call in fg")
check(vim.api.nvim_get_hl(0, { name = "@type", link = false }).fg == nfg, "mono: @type in fg")
check(vim.api.nvim_get_hl(0, { name = "@constant.builtin", link = false }).fg == nfg, "mono: @constant.builtin in fg")
ex.setup({})

-- Uncached loading must produce the same highlights as compiled loading.
ex.setup({})
vim.cmd.colorscheme("kanamono-light")
local cached = vim.api.nvim_get_hl(0, { name = "Keyword", link = false })
ex.setup({ cache = false })
vim.cmd.colorscheme("kanamono-light")
check(vim.deep_equal(cached, vim.api.nvim_get_hl(0, { name = "Keyword", link = false })), "cached and uncached syntax agree")
ex.setup({ transparent = true, cache = false })
vim.cmd.colorscheme("kanamono-dark")
for _, group in ipairs({ "Normal", "LineNr", "CursorLineNr", "SignColumn", "FoldColumn", "DiagnosticSignError" }) do
  check(vim.api.nvim_get_hl(0, { name = group, link = false }).bg == nil, "transparent gutter: " .. group)
end
ex.setup({})

-- highlights never produce invalid specs
for _, v in ipairs({ "light", "dark" }) do
  for n, spec in pairs(ex.highlights(v)) do
    for _, k in ipairs({ "fg", "bg", "sp" }) do
      local x = spec[k]
      check(x == nil or x == "NONE" or (type(x) == "string" and x:match("^#%x%x%x%x%x%x$")), ("%s %s.%s=%s"):format(v, n, k, tostring(x)))
    end
  end
end

print(ok_all and "ALL OK" or "FAILURES")
if not ok_all then os.exit(1) end
