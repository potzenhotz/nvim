-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = LazyVim.safe_keymap_set

-- Famouse esc sequence
map("i", "jk", "<Esc>")

-- Perusing code faster with K and J
map({ "n", "v" }, "K", "5k", { noremap = true, desc = "Up faster" })
map({ "n", "v" }, "J", "5j", { noremap = true, desc = "Down faster" })

-- Remap K and J
map({ "n", "v" }, "<leader>k", "K", { noremap = true, desc = "Keyword" })
map({ "n", "v" }, "<leader>j", "J", { noremap = true, desc = "Join lines" })
