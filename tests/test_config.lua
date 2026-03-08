local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T = new_set()

T["defaults"] = new_set()

T["defaults"]["has expected keys"] = function()
  local config = require("tutor-again.config")
  local d = config.defaults
  assert(d.keymap, "missing keymap")
  assert(d.lang, "missing lang")
  assert(d.history, "missing history")
  assert(d.ai, "missing ai")
end

T["defaults"]["ai has required fields"] = function()
  local config = require("tutor-again.config")
  local ai = config.defaults.ai
  assert(ai.base_url, "missing base_url")
  assert(ai.model, "missing model")
  assert(ai.mode_key, "missing mode_key")
  eq(type(ai.enabled), "boolean")
end

T["build"] = new_set()

T["build"]["returns defaults when no opts"] = function()
  local config = require("tutor-again.config")
  local c = config.build()
  eq(c.lang, "zh-TW")
  eq(c.ai.model, "gemini-2.5-flash-lite")
end

T["build"]["merges user opts"] = function()
  local config = require("tutor-again.config")
  local c = config.build({ lang = "en" })
  eq(c.lang, "en")
  -- Other defaults preserved
  assert(c.ai.base_url, "ai.base_url should be preserved")
end

T["build"]["deep merges ai config"] = function()
  local config = require("tutor-again.config")
  local c = config.build({ ai = { model = "custom-model" } })
  eq(c.ai.model, "custom-model")
  -- Other ai defaults preserved
  assert(c.ai.base_url, "ai.base_url should be preserved")
  assert(c.ai.mode_key, "ai.mode_key should be preserved")
end

T["config"] = new_set()

T["config"]["ai history_max_entries default"] = function()
  local config = require("tutor-again.config")
  local result = config.build({})
  eq(result.ai.history_max_entries, 100)
end

T["config"]["ai history_max_entries override"] = function()
  local config = require("tutor-again.config")
  local result = config.build({ ai = { history_max_entries = 50 } })
  eq(result.ai.history_max_entries, 50)
end

T["config"]["ai history_max_entries zero disables"] = function()
  local config = require("tutor-again.config")
  local result = config.build({ ai = { history_max_entries = 0 } })
  eq(result.ai.history_max_entries, 0)
end

return T
