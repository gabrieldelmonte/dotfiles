-- nvim-lint ships with LazyVim, so this file only adds linters for Markdown and TeX.
-- Required binaries: markdownlint-cli2 (npm), vale (brew), chktex (apt install chktex).

-- Neovim gives ".mdx" files no filetype, so lint them as Markdown
vim.filetype.add({ extension = { mdx = "markdown.mdx" } })

local fallback_dir = vim.fn.stdpath("config") .. "/lint/"

-- Both markdownlint-cli2 and Vale read the buffer from stdin, so they cannot find
-- the project configuration on their own. Look it up from the file being edited and
-- fall back to a global configuration outside of projects that ship one.
local function config_path(names, fallback)
  return function()
    local path = vim.api.nvim_buf_get_name(0)
    if path == "" then
      path = assert(vim.uv.cwd())
    end
    return vim.fs.find(names, { path = path, upward = true })[1] or fallback_dir .. fallback
  end
end

local function buffer_extension()
  return "." .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":e")
end

return {
  {
    "mfussenegger/nvim-lint",
    opts = {
      -- Lint while typing, not only on save. LazyVim debounces this by 100 ms.
      events = { "BufWritePost", "BufReadPost", "InsertLeave", "TextChanged", "TextChangedI" },
      linters_by_ft = {
        markdown = { "markdownlint-cli2", "vale" },
        -- A ".tex" file is detected as "plaintex" until it has a LaTeX preamble
        tex = { "chktex" },
        plaintex = { "chktex" },
      },
      linters = {
        ["markdownlint-cli2"] = {
          args = {
            "--config",
            config_path({
              ".markdownlint-cli2.jsonc",
              ".markdownlint-cli2.yaml",
              ".markdownlint-cli2.cjs",
              ".markdownlint.jsonc",
              ".markdownlint.json",
              ".markdownlint.yaml",
              ".markdownlint.yml",
            }, "markdownlint.jsonc"),
            "-",
          },
        },
        vale = {
          -- Half-typed MDX components make Vale's parser fail while you type,
          -- so drop its exit code instead of showing a notification per keystroke
          ignore_exitcode = true,
          args = {
            "--config",
            config_path({ ".vale.ini", "_vale.ini" }, "vale.ini"),
            "--no-exit",
            "--output",
            "JSON",
            "--ext",
            buffer_extension,
          },
        },
      },
    },
    keys = {
      {
        "<leader>cL",
        function()
          require("lint").try_lint()
        end,
        desc = "Lint Buffer",
      },
    },
  },

  {
    -- The lang.markdown extra registers markdownlint-cli2 for markdown as well.
    -- LazyVim concatenates linters_by_ft lists when it merges opts, so the same
    -- linter would run twice on every keystroke. Dedupe after the merge.
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      for ft, linters in pairs(opts.linters_by_ft or {}) do
        local seen, unique = {}, {}
        for _, linter in ipairs(linters) do
          if not seen[linter] then
            seen[linter] = true
            unique[#unique + 1] = linter
          end
        end
        opts.linters_by_ft[ft] = unique
      end
      return opts
    end,
  },
}
