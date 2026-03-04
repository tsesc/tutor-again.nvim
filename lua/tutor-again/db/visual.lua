return {
  { keys = "v", name = "Visual character", name_zh = "字元選取模式", tags = { "visual", "character", "select", "選取", "字元" }, category = "visual", mnemonic = "v=visual", description = "Enter visual mode (character-wise selection)", related = { "V", "Ctrl-v" } },
  { keys = "V", name = "Visual line", name_zh = "行選取模式", tags = { "visual", "line", "select", "選取", "行" }, category = "visual", mnemonic = "V=Visual line", description = "Enter visual line mode (select entire lines)", related = { "v", "Ctrl-v" } },
  { keys = "Ctrl-v", name = "Visual block", name_zh = "區塊選取模式", tags = { "visual", "block", "column", "select", "選取", "區塊", "行列" }, category = "visual", mnemonic = "Ctrl-v = visual block (column)", description = "Enter visual block mode (rectangular selection)", related = { "v", "V", "I", "A" } },
  { keys = "gv", name = "Reselect last visual", name_zh = "重新選取上次的選取範圍", tags = { "visual", "reselect", "last", "previous", "選取", "重新", "上次" }, category = "visual", mnemonic = "gv = go back to visual", description = "Reselect the last visual selection", related = { "v" } },
  { keys = "o", name = "Move to other end", name_zh = "跳到選取範圍的另一端", tags = { "visual", "other", "end", "swap", "選取", "另一端" }, category = "visual", mnemonic = "o = other end (in visual)", description = "In visual mode: move cursor to the other end of selection", related = { "O" } },
}
