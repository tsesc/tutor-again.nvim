local M = {}

local db = require("tutor-again.db")

function M.get_api_key()
  local config = require("tutor-again").config
  local key = config.ai and config.ai.api_key
  if not key or key == "" then
    key = vim.env.GEMINI_API_KEY or vim.env.OPENROUTER_API_KEY
  end
  return key
end

function M._read_config_files(include_config)
  if not include_config then return nil end

  local paths = {}
  if type(include_config) == "table" then
    paths = include_config
  elseif include_config == true then
    paths = { vim.fn.stdpath("config") .. "/init.lua" }
  else
    return nil
  end

  local sections = {}
  for _, path in ipairs(paths) do
    local expanded = vim.fn.expand(path)
    if vim.fn.filereadable(expanded) == 1 then
      local file_lines = vim.fn.readfile(expanded)
      if #file_lines > 0 then
        if #file_lines > 200 then
          file_lines = vim.list_slice(file_lines, 1, 200)
          table.insert(file_lines, "-- ... (truncated at 200 lines)")
        end
        table.insert(sections, "## " .. vim.fn.fnamemodify(expanded, ":~") .. "\n```lua\n" .. table.concat(file_lines, "\n") .. "\n```")
      end
    end
  end

  if #sections == 0 then return nil end
  return "# User's Neovim Config\n\n" .. table.concat(sections, "\n\n")
end

function M.build_system_prompt(lang)
  lang = lang or "zh-TW"
  local entries = db.all()
  local lines = {}

  -- Role & persona (always English)
  table.insert(lines, "# Role")
  table.insert(lines, "You are the tutor-again AI teaching assistant for Vim/Neovim.")
  table.insert(lines, "The user is learning Vim and may be a beginner or intermediate user.")

  -- Language instruction
  table.insert(lines, "")
  table.insert(lines, "# Language")
  if lang == "zh-TW" then
    table.insert(lines, "Reply in **Traditional Chinese (繁體中文)**.")
    table.insert(lines, "Keep technical terms in English (e.g. motion, operator, text object, register, buffer).")
  else
    table.insert(lines, "Reply in **English**.")
  end

  -- Neovim core knowledge
  table.insert(lines, "")
  table.insert(lines, "# Neovim Core Knowledge")
  table.insert(lines, "Use this context when answering questions about Neovim setup, config, or architecture.")
  table.insert(lines, "")
  table.insert(lines, "## Config File Structure")
  table.insert(lines, "- Entry point: `~/.config/nvim/init.lua`")
  table.insert(lines, "- Lua modules: `~/.config/nvim/lua/` (loaded via `require()`)")
  table.insert(lines, "- Plugin specs: `~/.config/nvim/lua/plugins/` (one file per plugin, when using lazy.nvim)")
  table.insert(lines, "- Data directory: `~/.local/share/nvim/` (plugins, shada, undo, swap)")
  table.insert(lines, "- State directory: `~/.local/state/nvim/` (logs)")
  table.insert(lines, "")
  table.insert(lines, "## Vim vs Neovim Differences")
  table.insert(lines, "- Neovim uses Lua as first-class config language (init.lua replaces .vimrc)")
  table.insert(lines, "- `vim.opt.xxx = val` replaces `set xxx=val`")
  table.insert(lines, "- `vim.keymap.set(mode, lhs, rhs, opts)` replaces `:map`/`:noremap`")
  table.insert(lines, "- `vim.api.nvim_*` for low-level API, `vim.fn.*` for Vimscript functions")
  table.insert(lines, "- Built-in LSP client (`vim.lsp`), Treesitter (`vim.treesitter`), diagnostics (`vim.diagnostic`)")
  table.insert(lines, "- Neovim-only: floating windows, `vim.ui.input/select`, `vim.notify`")
  table.insert(lines, "")
  table.insert(lines, "## Core Concepts")
  table.insert(lines, "- Modes: Normal, Insert, Visual (v/V/Ctrl-V), Command-line, Terminal")
  table.insert(lines, "- Buffer = file content in memory; Window = viewport into a buffer; Tab = collection of windows")
  table.insert(lines, "- A single buffer can be shown in multiple windows")
  table.insert(lines, "- Operator + Motion/Text-Object: `d` + `iw` = delete inner word, `c` + `a(` = change around parens")
  table.insert(lines, "- Registers: `\"` default, `+` system clipboard, `0` yank, `1-9` delete history, `_` black hole")
  table.insert(lines, "- Marks: `m{a-z}` local, `m{A-Z}` global, `` `{mark} `` jump to exact position")
  table.insert(lines, "")
  table.insert(lines, "## Common Lua Config Patterns")
  table.insert(lines, "- `vim.opt.number = true` (boolean option)")
  table.insert(lines, "- `vim.opt.tabstop = 4` (number option)")
  table.insert(lines, "- `vim.opt.clipboard = 'unnamedplus'` (string option)")
  table.insert(lines, "- `vim.opt.completeopt = { 'menu', 'menuone', 'noselect' }` (list option)")
  table.insert(lines, "- `vim.g.mapleader = ' '` (global variable, must be set before plugin setup)")
  table.insert(lines, "- `vim.keymap.set('n', '<leader>ff', function() ... end, { desc = '...' })`")
  table.insert(lines, "")
  table.insert(lines, "## Plugin Ecosystem (lazy.nvim)")
  table.insert(lines, "- Plugin manager: lazy.nvim (lazy-loading, lock file, UI)")
  table.insert(lines, "- Plugin spec: `{ 'user/repo', config = function() ... end }`")
  table.insert(lines, "- Common plugins: telescope.nvim (fuzzy finder), nvim-treesitter (syntax), nvim-lspconfig (LSP),")
  table.insert(lines, "  nvim-cmp (completion), which-key.nvim (keymap hints), gitsigns.nvim (git)")

  -- Scope restriction
  table.insert(lines, "")
  table.insert(lines, "# Scope")
  table.insert(lines, "You ONLY answer questions about Vim, Neovim, and their ecosystem (plugins, config, keymaps).")
  table.insert(lines, "If the user asks about anything unrelated to Vim/Neovim, reply with ONLY:")
  table.insert(lines, '"I can only help with Vim/Neovim questions."')
  table.insert(lines, "Do NOT attempt to answer non-Vim questions. No exceptions.")

  -- Response rules (always English)
  table.insert(lines, "")
  table.insert(lines, "# Response Rules")
  table.insert(lines, "- KEEP IT SHORT. Maximum 5-8 lines per answer. Users read this in a small floating window.")
  table.insert(lines, "- SIMPLEST FIRST. Always lead with the easiest, most practical approach.")
  table.insert(lines, "- If the user mentions a specific context (e.g. file explorer, telescope, terminal), prioritize that context's solution.")
  table.insert(lines, "- Prefer built-in features and common plugin shortcuts over command-line tricks.")
  table.insert(lines, "- Lead with the exact key sequence, then a one-line explanation.")
  table.insert(lines, "- Wrap key sequences in backticks, e.g. `dd`, `ciw`")
  table.insert(lines, "- Show at most ONE before/after example if needed")
  table.insert(lines, "- Only mention 2-3 most relevant related commands, not exhaustive lists")
  table.insert(lines, "- No verbose introductions, no summaries, no 'here are some tips' padding")

  table.insert(lines, "")
  table.insert(lines, "# Response Format")
  table.insert(lines, "1. Simplest method: key sequence + one-line explanation (1-2 lines)")
  table.insert(lines, "2. If a simpler alternative exists: mention it first, even if less \"Vim-like\"")
  table.insert(lines, "3. If example needed: add ONE short before/after block (2-3 lines)")
  table.insert(lines, "4. Related commands: list 2-3 max, inline like: See also: `ci(`, `ca(`")

  -- Command reference, grouped by category (always English for consistency)
  table.insert(lines, "")
  table.insert(lines, "# Vim Command Reference")
  table.insert(lines, "The user has access to these commands in their learning database:")
  table.insert(lines, "")

  -- Group entries by top-level category
  local categories = {}
  local cat_order = {}
  for _, entry in ipairs(entries) do
    local cat = entry.category or "other"
    local top = cat:match("^([^.]+)") or cat
    if not categories[top] then
      categories[top] = {}
      table.insert(cat_order, top)
    end
    table.insert(categories[top], entry)
  end

  for _, cat in ipairs(cat_order) do
    table.insert(lines, "## " .. cat)
    for _, entry in ipairs(categories[cat]) do
      local parts = { string.format("`%s`", entry.keys) }
      table.insert(parts, entry.name)
      if entry.mnemonic then
        table.insert(parts, "[" .. entry.mnemonic .. "]")
      end
      if entry.related and #entry.related > 0 then
        table.insert(parts, "-> " .. table.concat(entry.related, ", "))
      end
      table.insert(lines, "- " .. table.concat(parts, " -- "))
    end
    table.insert(lines, "")
  end

  -- Append user config if opted in
  local config = require("tutor-again").config
  local include_config = config.ai and config.ai.include_config
  local config_section = M._read_config_files(include_config)
  if config_section then
    table.insert(lines, "")
    table.insert(lines, config_section)
  end

  return table.concat(lines, "\n")
end

local function extract_error_message(err)
  if not err then return "Unknown API error" end
  local msg = err.message or "Unknown API error"
  -- OpenRouter puts the useful detail in metadata.raw
  if err.metadata and err.metadata.raw and err.metadata.raw ~= "" then
    msg = err.metadata.raw
  end
  if err.code then
    msg = msg .. " (" .. err.code .. ")"
  end
  return msg
end

function M.parse_sse_line(line)
  if not line or line == "" then return nil end
  if line == "data: [DONE]" then return { done = true } end

  -- Detect bare JSON error response (not SSE formatted)
  if line:match("^{") then
    local ok, data = pcall(vim.fn.json_decode, line)
    if ok and data and data.error then
      return { error = extract_error_message(data.error) }
    end
    return nil
  end

  if not line:match("^data: ") then return nil end

  local json_str = line:sub(7)
  local ok, data = pcall(vim.fn.json_decode, json_str)
  if not ok or not data then return nil end

  -- Check for error in SSE data
  if data.error then
    return { error = extract_error_message(data.error) }
  end

  local choices = data.choices
  if not choices or not choices[1] then return nil end

  local delta = choices[1].delta
  if delta and delta.content then
    return { content = delta.content }
  end

  if choices[1].finish_reason then
    return { done = true }
  end

  return nil
end

function M.wrap_text(text, width)
  width = width or 66
  local lines = {}

  for paragraph in (text .. "\n"):gmatch("(.-)\n") do
    if paragraph == "" then
      table.insert(lines, "")
    else
      local current_line = ""
      for word in paragraph:gmatch("%S+") do
        if current_line == "" then
          current_line = word
        elseif #current_line + 1 + #word <= width then
          current_line = current_line .. " " .. word
        else
          table.insert(lines, current_line)
          current_line = word
        end
      end
      if current_line ~= "" then
        table.insert(lines, current_line)
      end
    end
  end

  return lines
end

-- Single request to a specific model. Returns job_id.
-- on_api_error is called with error message for retryable API errors (4xx/5xx).
-- on_chunk/on_done/on_error are the user-facing callbacks.
function M._request(model, body_table, api_key, base_url, callbacks)
  body_table.model = model
  local body = vim.fn.json_encode(body_table)
  local partial_line = ""
  local got_content = false
  local got_api_error = nil
  local raw_output = {} -- collect all stdout for fallback error parsing

  local function process_line(line)
    if line == "" then return end
    local result = M.parse_sse_line(line)
    if not result then return end
    if result.error then
      got_api_error = result.error
    elseif result.done then
      -- handled by on_exit
    elseif result.content then
      got_content = true
      if callbacks.on_chunk then
        vim.schedule(function() callbacks.on_chunk(result.content) end)
      end
    end
  end

  -- Write auth header to temp file to avoid exposing API key in process args
  local header_file = vim.fn.tempname()
  vim.fn.writefile({ 'header = "Authorization: Bearer ' .. api_key .. '"' }, header_file)

  local job_id = vim.fn.jobstart({
    "curl", "-s", "-N",
    "-X", "POST",
    base_url .. "/chat/completions",
    "-H", "Content-Type: application/json",
    "--config", header_file,
    "-d", body,
  }, {
    stdout_buffered = false,
    on_stdout = function(_, data, _)
      if not data then return end
      for i, line in ipairs(data) do
        if i == 1 then
          line = partial_line .. line
          partial_line = ""
        end
        if i == #data then
          partial_line = line
        else
          table.insert(raw_output, line)
          process_line(line)
        end
      end
    end,
    on_stderr = function() end,
    on_exit = function(_, exit_code, _)
      -- Clean up temp header file
      pcall(vim.fn.delete, header_file)

      if partial_line ~= "" then
        table.insert(raw_output, partial_line)
        process_line(partial_line)
        partial_line = ""
      end

      -- If no content and no parsed error, try parsing full output as JSON error
      -- Handles multi-line JSON responses, including array-wrapped ones like Gemini's [{"error":...}]
      if not got_content and not got_api_error then
        local full = table.concat(raw_output, "\n")
        if full ~= "" then
          local ok, data = pcall(vim.fn.json_decode, full)
          if ok and data then
            -- Handle array-wrapped error: [{"error": {...}}]
            if type(data) == "table" and data[1] and data[1].error then
              got_api_error = extract_error_message(data[1].error)
            elseif data.error then
              got_api_error = extract_error_message(data.error)
            end
          end
          -- If JSON parse failed, show raw output as error
          if not ok and not got_api_error then
            got_api_error = full:sub(1, 200)
          end
        end
      end

      vim.schedule(function()
        if got_api_error and not got_content then
          if callbacks.on_api_error then
            callbacks.on_api_error(got_api_error)
          end
        elseif exit_code ~= 0 and callbacks.on_error then
          callbacks.on_error("curl exited with code " .. exit_code)
        elseif callbacks.on_done then
          callbacks.on_done()
        end
      end)
    end,
  })

  return job_id
end

M._max_query_length = 500

function M.ask(question, lang, opts)
  opts = opts or {}
  local on_chunk = opts.on_chunk
  local on_done = opts.on_done
  local on_error = opts.on_error

  if #question > M._max_query_length then
    if on_error then
      local msg = lang == "zh-TW"
        and ("問題過長（上限 " .. M._max_query_length .. " 字元）")
        or ("Query too long (max " .. M._max_query_length .. " characters)")
      on_error(msg)
    end
    return nil
  end

  local api_key = M.get_api_key()
  if not api_key or api_key == "" then
    if on_error then
      local msg = lang == "zh-TW"
        and "未設定 API key。請設定 GEMINI_API_KEY 環境變數或 config ai.api_key"
        or "No API key. Set GEMINI_API_KEY env var or config ai.api_key"
      on_error(msg)
    end
    return nil
  end

  local config = require("tutor-again").config
  local base_url = config.ai.base_url
  local model_cfg = config.ai.model

  -- Normalize to list
  local models = type(model_cfg) == "table" and model_cfg or { model_cfg }

  local system_prompt = M.build_system_prompt(lang)
  local body_table = {
    stream = true,
    messages = {
      { role = "system", content = system_prompt },
      { role = "user", content = question },
    },
  }

  local current_idx = 1
  local job_id_ref = { id = nil }

  local function try_next_model()
    if current_idx > #models then
      if on_error then
        local msg = lang == "zh-TW"
          and "所有模型皆遭限流，請稍後再試。"
          or "All models rate-limited. Try again later."
        on_error(msg)
      end
      return
    end
    local model = models[current_idx]
    if on_chunk and current_idx > 1 then
      local retry_msg = lang == "zh-TW"
        and ("\n[正在切換至 " .. model .. "...]\n")
        or ("\n[Retrying with " .. model .. "...]\n")
      on_chunk(retry_msg)
    end
    current_idx = current_idx + 1
    job_id_ref.id = M._request(model, body_table, api_key, base_url, {
      on_chunk = on_chunk,
      on_done = on_done,
      on_error = on_error,
      on_api_error = function(_)
        try_next_model()
      end,
    })
  end

  try_next_model()
  return job_id_ref
end

function M.cancel(job_id_ref)
  if not job_id_ref then return end
  -- Support both raw number (legacy) and ref table
  if type(job_id_ref) == "number" then
    pcall(vim.fn.jobstop, job_id_ref)
  elseif type(job_id_ref) == "table" and job_id_ref.id then
    pcall(vim.fn.jobstop, job_id_ref.id)
    job_id_ref.id = nil
  end
end

return M
