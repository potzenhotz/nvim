return {
  "sphamba/smear-cursor.nvim",

  opts = {
    -- Smear cursor color. Defaults to Cursor GUI color if not set.
    -- Set to "none" to match the text color at the target cursor position.
    cursor_color = "#8D148F",
    stiffness = 0.3,
    trailing_stiffness = 0.15,
    damping = 0.85,
    trailing_exponent = 5,
    never_draw_over_target = true,
    hide_target_hack = true,
    gamma = 1,
  },
}
