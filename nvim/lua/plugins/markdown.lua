-- render-markdown.nvim (from the lang.markdown extra) swaps in its own window
-- options while a buffer is rendered: conceallevel 3, so concealed text is
-- hidden completely, and concealcursor '' so it reappears on the cursor line.
-- That is the flicker where ``` fences and [](link) brackets vanish as you
-- move around.
--
-- Setting `rendered = 0` keeps every one of its decorations -- code-block
-- backgrounds, heading colours, bullet icons -- while never hiding characters.

return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {
      win_options = {
        conceallevel = { rendered = 0 },
      },
    },
  },
}
