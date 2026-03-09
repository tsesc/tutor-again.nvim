# AI 對話歷史紀錄

## 目標

讓使用者可以查看過去的 AI 對話紀錄，並從歷史中載入對話繼續操作。完全存本地。

## 設計決策

- **方案**：新增獨立 `ai_history.lua` 模組（仿照 `history.lua` 模式）
- **瀏覽方式**：AI 模式下 input 為空時自動顯示歷史列表（與 search 模式一致）
- **對話模式**：維持單輪對話，從歷史載入後可重新提問
- **儲存**：完全本地，JSON 檔案

## 資料結構

**檔案路徑**：`~/.local/state/nvim/tutor-again/ai_history.json`

```lua
-- 單筆紀錄
{
  id = 1709971200,        -- os.time() 作為 ID
  question = "怎麼刪除一行？",
  response = "在 Vim 中...",
  lang = "zh-TW",
  timestamp = 1709971200, -- unix timestamp
}
```

## 設定項

```lua
ai = {
  history_max_entries = 100,  -- AI 歷史最大筆數，0 = 停用
}
```

## UI 互動

### 歷史列表（AI 模式 input 為空時）

```
  怎麼刪除一行？                          5分前
  如何用 macro 重複操作？                  2小時前
  neovim lsp 設定方法                     3天前
```

### 操作

- `<Up>`/`<Down>` 上下選擇
- `<CR>` 載入選中的歷史對話 → 結果視窗顯示完整問答
- `<C-d>` 刪除選中的歷史紀錄
- `<C-y>` 複製回答（載入歷史後可用）

### 載入歷史後

- 結果視窗顯示完整問答（Q: 問題 + 回答內容）
- 使用者可在 input 輸入新問題

## 模組設計

### 新增 `lua/tutor-again/ai_history.lua`

- `M.add(question, response, lang)` — 新增紀錄
- `M.get_all()` — 取得所有紀錄（lazy load from disk）
- `M.delete(id)` — 刪除單筆
- `M.save()` — debounced write（1 秒延遲）
- `M.clear()` — 清除全部

儲存策略：
- 超過 `history_max_entries` 時刪除最舊紀錄
- Atomic write（temp file + rename）
- Multi-instance merge（讀取磁碟合併其他 instance 紀錄）

### 修改 `lua/tutor-again/ui.lua`

- AI 模式 input 為空 → 呼叫 `ai_history.get_all()` 渲染列表
- `<CR>` 在歷史列表上 → 載入對話到結果視窗
- `<C-d>` → 刪除歷史紀錄
- AI 回答完成 → 呼叫 `ai_history.add()`

### 修改 `lua/tutor-again/config.lua`

- 新增 `ai.history_max_entries` 預設值（100）

## 測試計畫

`tests/test_ai_history.lua`：
- 新增/讀取/刪除紀錄
- 超過上限自動裁剪
- Debounced write
- JSON 序列化/反序列化
- 空檔案/損壞檔案處理
