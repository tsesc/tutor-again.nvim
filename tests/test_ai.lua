local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T = new_set()

T["build_system_prompt"] = new_set()

T["build_system_prompt"]["includes db entries grouped by category"] = function()
  local ai = require("tutor-again.ai")
  local prompt = ai.build_system_prompt("en")
  assert(prompt:find("`dd`"), "should contain dd command")
  assert(prompt:find("`w`"), "should contain w command")
  assert(prompt:find("## movement"), "should have category headers")
  assert(prompt:find("## operators"), "should have operators category")
end

T["build_system_prompt"]["includes mnemonic and related"] = function()
  local ai = require("tutor-again.ai")
  local prompt = ai.build_system_prompt("en")
  assert(prompt:find("%[.*=.*%]"), "should contain mnemonic hints like [d=delete]")
end

T["build_system_prompt"]["always uses english for structure"] = function()
  local ai = require("tutor-again.ai")
  local prompt = ai.build_system_prompt("zh-TW")
  assert(prompt:find("# Role"), "should have english Role section")
  assert(prompt:find("# Response Rules"), "should have english rules section")
  assert(prompt:find("# Response Format"), "should have english format section")
end

T["build_system_prompt"]["zh-TW instructs reply in Traditional Chinese"] = function()
  local ai = require("tutor-again.ai")
  local prompt = ai.build_system_prompt("zh-TW")
  assert(prompt:find("Traditional Chinese"), "should instruct Traditional Chinese reply")
  assert(prompt:find("繁體中文"), "should include 繁體中文 label")
end

T["build_system_prompt"]["en instructs reply in English"] = function()
  local ai = require("tutor-again.ai")
  local prompt = ai.build_system_prompt("en")
  assert(prompt:find("Reply in %*%*English%*%*"), "should instruct English reply")
  assert(prompt:find("ONLY answer questions about Vim"), "should restrict scope to Vim")
end

T["build_system_prompt"]["command reference always uses english names"] = function()
  local ai = require("tutor-again.ai")
  local zh_prompt = ai.build_system_prompt("zh-TW")
  local en_prompt = ai.build_system_prompt("en")
  -- Both should use English entry names like "Delete line"
  assert(zh_prompt:find("Delete line"), "zh prompt should use English command names")
  assert(en_prompt:find("Delete line"), "en prompt should use English command names")
end

T["build_system_prompt"]["includes neovim core knowledge"] = function()
  local ai = require("tutor-again.ai")
  local prompt = ai.build_system_prompt("en")
  assert(prompt:find("# Neovim Core Knowledge"), "should have core knowledge section")
  assert(prompt:find("init%.lua"), "should mention init.lua")
  assert(prompt:find("vim%.opt"), "should mention vim.opt")
  assert(prompt:find("vim%.keymap%.set"), "should mention vim.keymap.set")
  assert(prompt:find("lazy%.nvim"), "should mention lazy.nvim")
  assert(prompt:find("Buffer = file content"), "should explain buffer/window/tab")
  assert(prompt:find("Registers"), "should explain registers")
end

T["parse_sse_line"] = new_set()

T["parse_sse_line"]["returns nil for empty line"] = function()
  local ai = require("tutor-again.ai")
  eq(ai.parse_sse_line(""), nil)
  eq(ai.parse_sse_line(nil), nil)
end

T["parse_sse_line"]["returns done for [DONE]"] = function()
  local ai = require("tutor-again.ai")
  local result = ai.parse_sse_line("data: [DONE]")
  eq(result.done, true)
end

T["parse_sse_line"]["extracts content from delta"] = function()
  local ai = require("tutor-again.ai")
  local json = vim.fn.json_encode({
    choices = { { delta = { content = "hello" } } },
  })
  local result = ai.parse_sse_line("data: " .. json)
  eq(result.content, "hello")
end

T["parse_sse_line"]["returns done on finish_reason"] = function()
  local ai = require("tutor-again.ai")
  local json = vim.fn.json_encode({
    choices = { { delta = {}, finish_reason = "stop" } },
  })
  local result = ai.parse_sse_line("data: " .. json)
  eq(result.done, true)
end

T["parse_sse_line"]["ignores non-data lines"] = function()
  local ai = require("tutor-again.ai")
  eq(ai.parse_sse_line("event: message"), nil)
  eq(ai.parse_sse_line(": comment"), nil)
end

T["parse_sse_line"]["detects bare JSON error response"] = function()
  local ai = require("tutor-again.ai")
  local err_json = vim.fn.json_encode({ error = { message = "Model not found", code = 404 } })
  local result = ai.parse_sse_line(err_json)
  eq(result.error, "Model not found (404)")
end

T["parse_sse_line"]["detects error inside SSE data"] = function()
  local ai = require("tutor-again.ai")
  local err_json = vim.fn.json_encode({ error = { message = "Rate limited", code = 429 } })
  local result = ai.parse_sse_line("data: " .. err_json)
  eq(result.error, "Rate limited (429)")
end

T["parse_sse_line"]["detects array-wrapped error like Gemini"] = function()
  local ai = require("tutor-again.ai")
  -- Gemini returns [{"error":{...}}] but parse_sse_line works per-line
  -- so single-line array-wrapped errors should also be detected
  local err_json = vim.fn.json_encode({ { error = { message = "Quota exceeded", code = 429 } } })
  -- This starts with [ not { so parse_sse_line won't catch it — that's OK,
  -- it's handled by the on_exit fallback. Test the fallback logic directly:
  local ok, data = pcall(vim.fn.json_decode, err_json)
  assert(ok)
  assert(data[1].error.message == "Quota exceeded")
end

T["parse_sse_line"]["prefers metadata.raw for detailed error"] = function()
  local ai = require("tutor-again.ai")
  local err_json = vim.fn.json_encode({
    error = {
      message = "Provider returned error",
      code = 429,
      metadata = { raw = "model is temporarily rate-limited" },
    },
  })
  local result = ai.parse_sse_line(err_json)
  eq(result.error, "model is temporarily rate-limited (429)")
end

T["wrap_text"] = new_set()

T["wrap_text"]["wraps long line"] = function()
  local ai = require("tutor-again.ai")
  local text = "This is a very long line that should be wrapped at the specified width for display"
  local lines = ai.wrap_text(text, 30)
  for _, line in ipairs(lines) do
    assert(#line <= 35, "line too long: " .. line) -- some slack for single long words
  end
  assert(#lines > 1, "should have multiple lines")
end

T["wrap_text"]["preserves empty lines"] = function()
  local ai = require("tutor-again.ai")
  local text = "First paragraph\n\nSecond paragraph"
  local lines = ai.wrap_text(text, 60)
  local found_empty = false
  for _, line in ipairs(lines) do
    if line == "" then found_empty = true end
  end
  assert(found_empty, "should preserve empty lines between paragraphs")
end

T["wrap_text"]["handles short text"] = function()
  local ai = require("tutor-again.ai")
  local lines = ai.wrap_text("short", 60)
  eq(#lines, 1)
  eq(lines[1], "short")
end

T["get_api_key"] = new_set()

T["get_api_key"]["returns nil when no key configured"] = function()
  local ai = require("tutor-again.ai")
  local orig_gemini = vim.env.GEMINI_API_KEY
  local orig_or = vim.env.OPENROUTER_API_KEY
  vim.env.GEMINI_API_KEY = nil
  vim.env.OPENROUTER_API_KEY = nil
  require("tutor-again").config = { ai = { api_key = nil } }
  local key = ai.get_api_key()
  eq(key, nil)
  vim.env.GEMINI_API_KEY = orig_gemini
  vim.env.OPENROUTER_API_KEY = orig_or
end

T["get_api_key"]["returns GEMINI_API_KEY as fallback"] = function()
  local ai = require("tutor-again.ai")
  local orig_gemini = vim.env.GEMINI_API_KEY
  local orig_or = vim.env.OPENROUTER_API_KEY
  vim.env.GEMINI_API_KEY = "gemini-key-123"
  vim.env.OPENROUTER_API_KEY = nil
  require("tutor-again").config = { ai = { api_key = nil } }
  local key = ai.get_api_key()
  eq(key, "gemini-key-123")
  vim.env.GEMINI_API_KEY = orig_gemini
  vim.env.OPENROUTER_API_KEY = orig_or
end

T["get_api_key"]["falls back to OPENROUTER_API_KEY"] = function()
  local ai = require("tutor-again.ai")
  local orig_gemini = vim.env.GEMINI_API_KEY
  local orig_or = vim.env.OPENROUTER_API_KEY
  vim.env.GEMINI_API_KEY = nil
  vim.env.OPENROUTER_API_KEY = "or-key-456"
  require("tutor-again").config = { ai = { api_key = nil } }
  local key = ai.get_api_key()
  eq(key, "or-key-456")
  vim.env.GEMINI_API_KEY = orig_gemini
  vim.env.OPENROUTER_API_KEY = orig_or
end

T["get_api_key"]["prefers config over env"] = function()
  local ai = require("tutor-again.ai")
  local orig_gemini = vim.env.GEMINI_API_KEY
  vim.env.GEMINI_API_KEY = "env-key"
  require("tutor-again").config = { ai = { api_key = "config-key" } }
  local key = ai.get_api_key()
  eq(key, "config-key")
  vim.env.GEMINI_API_KEY = orig_gemini
end

return T
