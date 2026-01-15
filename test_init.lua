-- Minimal init for haiku.nvim testing
-- This file sets up the minimal environment needed for tests

-- Add plugin to runtime path
local project_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
vim.opt.rtp:prepend(project_root)

-- Add plenary to runtime path (check multiple locations)
local plenary_paths = {
  project_root .. "/plenary.nvim",
  vim.fn.expand("~/.local/share/nvim/lazy/plenary.nvim"),
  vim.fn.expand("~/.local/share/nvim/site/pack/packer/start/plenary.nvim"),
}

local plenary_found = false
for _, path in ipairs(plenary_paths) do
  if vim.fn.isdirectory(path) == 1 then
    vim.opt.rtp:prepend(path)
    plenary_found = true
    break
  end
end

if not plenary_found then
  print("ERROR: plenary.nvim not found. Run 'task deps' first.")
  vim.cmd("qa!")
end

-- Minimal settings
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.undofile = false

-- Disable plugins that might interfere
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Set up test environment variables
vim.env.HAIKU_API_KEY = "test-api-key-for-testing"

-- Load plenary
vim.cmd("runtime plugin/plenary.vim")
