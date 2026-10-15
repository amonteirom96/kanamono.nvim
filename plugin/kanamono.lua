if vim.g.loaded_kanamono then
  return
end
vim.g.loaded_kanamono = true

local cmd = vim.api.nvim_create_user_command

cmd("KanamonoCompile", function()
  require("kanamono").compile()
end, { desc = "kanamono: rebuild the compiled highlight cache" })

cmd("KanamonoClearCache", function()
  require("kanamono").clear_cache()
end, { desc = "kanamono: delete the compiled highlight cache" })

cmd("KanamonoExtras", function(args)
  local out = require("kanamono").extras(args.args ~= "" and args.args or nil)
  vim.notify("kanamono: extras written to " .. out)
end, { nargs = "?", complete = "dir", desc = "kanamono: generate ghostty/kitty/lazygit themes" })
