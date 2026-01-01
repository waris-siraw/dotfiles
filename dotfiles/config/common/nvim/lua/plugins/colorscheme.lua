return {
  -- Installa il plugin gruvbox
  {
    "ellisonleao/gruvbox.nvim",
    priority = 1000, -- Assicura che venga caricato prima degli altri plugin
    config = true,
    opts = {
      transparent_mode = false, -- Imposta a true se vuoi lo sfondo trasparente
    },
  },

  -- Imposta il tema predefinito di LazyVim
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "gruvbox",
    },
  },
}
