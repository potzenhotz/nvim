-- LLM selection chat via OpenRouter API
-- Keymaps: <leader>ce (explain), <leader>cp (custom prompt), <leader>cx (refactor),
--          <leader>ct (tests), <leader>cM (switch model), <leader>cf (follow-up),
--          <leader>cn (new chat)

local model = "anthropic/claude-opus-4.6"
local history_buf = nil
local conversation_messages = {}

local MODELS = {
  "anthropic/claude-opus-4.6",
  "anthropic/claude-sonnet-4",
  "anthropic/claude-haiku-4-5",
  "google/gemini-2.5-pro-preview",
  "deepseek/deepseek-chat-v3",
}

local SYSTEM_PROMPT = "You are a helpful coding assistant. You receive code snippets from the user. "
  .. "Be concise and precise. When showing code changes, show only the relevant parts unless asked for the full rewrite."

local function get_visual_selection()
  -- Save and restore register a
  local saved = vim.fn.getreg("a")
  vim.cmd('noautocmd normal! "ay')
  local text = vim.fn.getreg("a")
  vim.fn.setreg("a", saved)
  return text
end

local function get_or_create_history_buf()
  if history_buf and vim.api.nvim_buf_is_valid(history_buf) then
    return history_buf
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.api.nvim_buf_set_name(buf, "LLM History")
  history_buf = buf
  return buf
end

local function open_history_window()
  local buf = get_or_create_history_buf()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      vim.api.nvim_set_current_win(win)
      return buf
    end
  end
  vim.cmd("vsplit")
  vim.api.nvim_win_set_buf(0, buf)
  return buf
end

local function scroll_history_to_bottom(buf)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
    end
  end
end

local function append_to_history(buf, lines)
  vim.bo[buf].modifiable = true
  local count = vim.api.nvim_buf_line_count(buf)
  -- avoid leading blank line on empty buffer
  if count == 1 and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == "" then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  else
    vim.api.nvim_buf_set_lines(buf, count, -1, false, lines)
  end
  vim.bo[buf].modifiable = false
  scroll_history_to_bottom(buf)
end

local function replace_history_lines(buf, from, to, lines)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, from, to, false, lines)
  vim.bo[buf].modifiable = false
  scroll_history_to_bottom(buf)
end

local function send_to_llm(selection, prompt)
  local api_key = vim.env.OPENROUTER_API_KEY
  if not api_key or api_key == "" then
    vim.notify("LLM: OPENROUTER_API_KEY is not set", vim.log.levels.ERROR)
    return
  end

  local user_content
  if selection and selection ~= "" then
    user_content = prompt .. "\n\n```\n" .. selection .. "\n```"
  else
    user_content = prompt
  end

  table.insert(conversation_messages, { role = "user", content = user_content })

  local messages = { { role = "system", content = SYSTEM_PROMPT } }
  vim.list_extend(messages, conversation_messages)

  local body = vim.json.encode({
    model = model,
    messages = messages,
  })

  local buf = open_history_window()
  local prompt_lines = vim.split("**[" .. model .. "]** " .. prompt, "\n", { plain = true })
  local header = { "", "---" }
  vim.list_extend(header, prompt_lines)
  table.insert(header, "")
  table.insert(header, "_Thinking..._")
  append_to_history(buf, header)
  local thinking_line = vim.api.nvim_buf_line_count(buf) - 1 -- 0-indexed line of "_Thinking..._"

  local result_chunks = {}

  vim.fn.jobstart({
    "curl",
    "--silent",
    "--show-error",
    "-X",
    "POST",
    "https://openrouter.ai/api/v1/chat/completions",
    "-H",
    "Authorization: Bearer " .. api_key,
    "-H",
    "Content-Type: application/json",
    "-d",
    body,
  }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, chunk in ipairs(data) do
          if chunk ~= "" then
            table.insert(result_chunks, chunk)
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            vim.schedule(function()
              vim.notify("LLM curl error: " .. line, vim.log.levels.ERROR)
            end)
          end
        end
      end
    end,
    on_exit = function(_, code)
      vim.schedule(function()
        if code ~= 0 then
          replace_history_lines(
            buf,
            thinking_line,
            thinking_line + 1,
            { "_Error: curl exited with code " .. code .. "_" }
          )
          return
        end

        local raw = table.concat(result_chunks, "")
        if raw == "" then
          replace_history_lines(buf, thinking_line, thinking_line + 1, { "_Error: empty response from API_" })
          return
        end

        local ok, decoded = pcall(vim.json.decode, raw)
        if not ok then
          replace_history_lines(
            buf,
            thinking_line,
            thinking_line + 1,
            { "_Error: failed to parse JSON response_", "", raw }
          )
          return
        end

        if decoded.error then
          local msg = decoded.error.message or vim.inspect(decoded.error)
          replace_history_lines(buf, thinking_line, thinking_line + 1, { "_API error: " .. msg .. "_" })
          return
        end

        local content = vim.tbl_get(decoded, "choices", 1, "message", "content")
        if not content then
          replace_history_lines(
            buf,
            thinking_line,
            thinking_line + 1,
            { "_Error: unexpected response structure_", "", raw }
          )
          return
        end

        table.insert(conversation_messages, { role = "assistant", content = content })
        local lines = vim.split(content, "\n", { plain = true })
        replace_history_lines(buf, thinking_line, thinking_line + 1, lines)
      end)
    end,
  })
end

local function llm_with_prompt(prompt)
  local selection = get_visual_selection()
  if selection == "" then
    vim.notify("LLM: no text selected", vim.log.levels.WARN)
    return
  end
  send_to_llm(selection, prompt)
end

local function get_current_line()
  return vim.api.nvim_get_current_line()
end

local function llm_custom_prompt(text)
  vim.ui.input({ prompt = "LLM prompt: " }, function(input)
    if input and input ~= "" then
      send_to_llm(text, input)
    end
  end)
end

local function llm_custom_prompt_visual()
  local selection = get_visual_selection()
  if selection == "" then
    vim.notify("LLM: no text selected", vim.log.levels.WARN)
    return
  end
  llm_custom_prompt(selection)
end

local function llm_custom_prompt_normal()
  local line = get_current_line()
  if line == "" then
    vim.notify("LLM: current line is empty", vim.log.levels.WARN)
    return
  end
  llm_custom_prompt(line)
end

local function check_credits()
  local api_key = vim.env.OPENROUTER_API_KEY
  if not api_key or api_key == "" then
    vim.notify("LLM: OPENROUTER_API_KEY is not set", vim.log.levels.ERROR)
    return
  end

  vim.notify("LLM: fetching credit balance...", vim.log.levels.INFO)

  local result_chunks = {}

  vim.fn.jobstart({
    "curl",
    "--silent",
    "--show-error",
    "https://openrouter.ai/api/v1/auth/key",
    "-H",
    "Authorization: Bearer " .. api_key,
  }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, chunk in ipairs(data) do
          if chunk ~= "" then
            table.insert(result_chunks, chunk)
          end
        end
      end
    end,
    on_exit = function(_, code)
      vim.schedule(function()
        if code ~= 0 then
          vim.notify("LLM: curl failed (code " .. code .. ")", vim.log.levels.ERROR)
          return
        end

        local raw = table.concat(result_chunks, "")
        local ok, decoded = pcall(vim.json.decode, raw)
        if not ok or not decoded or not decoded.data then
          vim.notify("LLM: failed to parse credit response", vim.log.levels.ERROR)
          return
        end

        local d = decoded.data
        local limit = d.limit
        local used = d.usage or 0

        local msg
        if limit == nil then
          msg = string.format("LLM credits: $%.4f used (unlimited plan)", used)
        else
          local remaining = limit - used
          msg = string.format("LLM credits: $%.4f remaining / $%.4f limit ($%.4f used)", remaining, limit, used)
        end

        vim.notify(msg, vim.log.levels.INFO)
      end)
    end,
  })
end

local function llm_followup()
  if #conversation_messages == 0 then
    vim.notify("LLM: no conversation to follow up on — ask a question first", vim.log.levels.WARN)
    return
  end
  vim.ui.input({ prompt = "LLM follow-up: " }, function(input)
    if input and input ~= "" then
      send_to_llm(nil, input)
    end
  end)
end

local function llm_new_chat()
  conversation_messages = {}
  if history_buf and vim.api.nvim_buf_is_valid(history_buf) then
    vim.bo[history_buf].modifiable = true
    vim.api.nvim_buf_set_lines(history_buf, 0, -1, false, { "" })
    vim.bo[history_buf].modifiable = false
  end
  vim.notify("LLM: new conversation started", vim.log.levels.INFO)
end

local function switch_model()
  vim.ui.select(MODELS, {
    prompt = "Select LLM model:",
    format_item = function(item)
      return item
    end,
  }, function(choice)
    if choice then
      model = choice
      vim.notify("LLM model set to: " .. model, vim.log.levels.INFO)
    end
  end)
end

return {
  {
    -- No actual plugin to install; use a dummy spec to register keymaps via lazy
    "nvim-lua/plenary.nvim",
    optional = true,
    keys = {
      {
        "<leader>ce",
        function()
          llm_with_prompt("Explain this code and suggest improvements")
        end,
        mode = "x",
        desc = "LLM: Explain & suggest improvements",
      },
      {
        "<leader>cp",
        function()
          llm_custom_prompt_visual()
        end,
        mode = "x",
        desc = "LLM: Custom prompt",
      },
      {
        "<leader>cp",
        function()
          llm_custom_prompt_normal()
        end,
        mode = "n",
        desc = "LLM: Custom prompt (current line)",
      },
      {
        "<leader>cx",
        function()
          llm_with_prompt("Refactor this code for readability and clean style")
        end,
        mode = "x",
        desc = "LLM: Refactor for readability",
      },
      {
        "<leader>ct",
        function()
          llm_with_prompt("Write unit tests for this code")
        end,
        mode = "x",
        desc = "LLM: Write unit tests",
      },
      {
        "<leader>cf",
        function()
          llm_followup()
        end,
        mode = "n",
        desc = "LLM: Follow-up question",
      },
      {
        "<leader>cn",
        function()
          llm_new_chat()
        end,
        mode = "n",
        desc = "LLM: New conversation",
      },
      {
        "<leader>cM",
        function()
          switch_model()
        end,
        mode = "n",
        desc = "LLM: Switch model",
      },
      {
        "<leader>c$",
        function()
          check_credits()
        end,
        mode = "n",
        desc = "LLM: Check credit balance",
      },
    },
  },
}
