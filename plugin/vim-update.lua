if vim.g.loaded_vim_update then
  return
end
vim.g.loaded_vim_update = true

local vim_update = require("vim-update")

vim.api.nvim_create_user_command("VimUpdate", function()
  vim_update.execute_command()
end, {})

local group = vim.api.nvim_create_augroup("VimUpdateStartup", { clear = true })

vim.api.nvim_create_autocmd("VimEnter", {
  group = group,
  callback = function()
    vim.defer_fn(function()
      vim_update.start_check()
    end, 100)
  end,
})
