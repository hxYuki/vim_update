local config = require("vim-update.config")

local M = {}

local I18N = {
  en = {
    dialog_title = "Neovim Config Update",
    behind_msg = "Remote has %d new commit(s):",
    update_btn = "[Y] Update",
    view_btn = "[D] View Changes",
    ignore_btn = "[N] Ignore",
    forked_title = "Neovim Config Update",
    forked_msg = "Remote: %d commit(s), Local: %d commit(s)",
    forked_local = "Local:",
    forked_remote = "Remote:",
    forked_desc = "Config has diverged. Manual resolution required.",
    terminal_btn = "[T] Open Terminal",
    update_success = "Update successful. Please restart Neovim.",
    update_noop = "Already up to date.",
    update_forked = "Config has diverged. Manual resolution required.",
    conflict_title = "Update Conflict",
    conflict_msg = "Conflict detected during update.",
    abort_btn = "[A] Abort",
    terminal_conflict_btn = "[T] Open Terminal",
    conflict_aborted = "Update aborted.",
    fetching = "Checking for updates...",
    fetch_failed = "Failed to check for updates.",
    auto_pushing = "Pushing local commits...",
    auto_push_success = "Local commits pushed.",
    auto_push_failed = "Failed to push local commits.",
    ahead_notify = "Local is %d commit(s) ahead of remote.",
    behind_notify = "Remote has %d new commit(s). Run :VimUpdate to update.",
    forked_notify = "Config has diverged. Manual resolution required.",
    busy = "Update already in progress.",
    view_title = "Vim Update - Changes",
  },
  zh = {
    dialog_title = "Neovim 配置更新",
    behind_msg = "远程有 %d 个新提交:",
    update_btn = "[Y] 更新",
    view_btn = "[D] 查看变更",
    ignore_btn = "[N] 忽略",
    forked_title = "Neovim 配置更新",
    forked_msg = "远程: %d 提交, 本地: %d 提交",
    forked_local = "本地:",
    forked_remote = "远程:",
    forked_desc = "配置已分叉，建议手动处理",
    terminal_btn = "[T] 打开终端",
    update_success = "更新成功，请重启 Neovim",
    update_noop = "已是最新",
    update_forked = "配置已分叉，请手动处理",
    conflict_title = "更新冲突",
    conflict_msg = "更新时检测到冲突",
    abort_btn = "[A] 中止",
    terminal_conflict_btn = "[T] 打开终端",
    conflict_aborted = "更新已中止",
    fetching = "正在检查更新...",
    fetch_failed = "检查更新失败",
    auto_pushing = "正在推送本地提交...",
    auto_push_success = "本地提交已推送",
    auto_push_failed = "推送本地提交失败",
    ahead_notify = "本地领先远程 %d 个提交",
    behind_notify = "远程有 %d 个新提交，执行 :VimUpdate 更新",
    forked_notify = "配置已分叉，请手动处理",
    busy = "更新已在进行中",
    view_title = "Vim Update - 变更",
  },
}

function M.t(key)
  local lang = config.options.lang or "en"
  local t = I18N[lang] or I18N["en"]
  return t[key] or I18N["en"][key] or key
end

function M.open_terminal(cmd)
  vim.cmd("split")
  vim.cmd("terminal " .. (cmd or ""))
  vim.cmd("startinsert")
end

function M.view_changes(log_lines, remote, branch)
  if vim.fn.exists(":LazyGit") == 2 then
    vim.cmd("LazyGit")
    return
  end
  if vim.fn.exists(":Neogit") == 2 then
    vim.cmd("Neogit")
    return
  end
  if vim.fn.exists(":Git") == 2 then
    vim.cmd("Git log")
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false

  local lines = { M.t("view_title"), "", "" }
  for _, line in ipairs(log_lines) do
    table.insert(lines, line)
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local width = 80
  local height = #lines
  if height > 20 then
    height = 20
  end

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = 2,
    col = 2,
    style = "minimal",
    border = "rounded",
  })

  vim.bo[buf].modifiable = false

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, nowait = true })
end

function M.show_dialog(log_lines, behind_count, on_update, on_view, on_dismiss)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false

  local lines = {
    M.t("dialog_title"),
    "",
    M.t("behind_msg"):format(behind_count),
    "",
  }

  local shown_lines = log_lines
  if #log_lines > 10 then
    shown_lines = {}
    for i = 1, 10 do
      shown_lines[i] = log_lines[i]
    end
  end
  for _, line in ipairs(shown_lines) do
    table.insert(lines, "  " .. line)
  end

  table.insert(lines, "")
  table.insert(lines, "  " .. M.t("update_btn") .. "  " .. M.t("view_btn") .. "  " .. M.t("ignore_btn"))

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  local max_width = 0
  for _, line in ipairs(lines) do
    local len = vim.fn.strdisplaywidth(line)
    if len > max_width then
      max_width = len
    end
  end
  local width = math.max(max_width + 4, 40)
  local height = #lines

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    focusable = true,
  })

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  local function safe_on_update()
    close()
    if on_update then
      on_update()
    end
  end

  local function safe_on_view()
    close()
    if on_view then
      on_view()
    end
  end

  local function safe_on_dismiss()
    close()
    if on_dismiss then
      on_dismiss()
    end
  end

  vim.keymap.set("n", "y", safe_on_update, { buffer = buf, nowait = true })
  vim.keymap.set("n", "Y", safe_on_update, { buffer = buf, nowait = true })
  vim.keymap.set("n", "d", safe_on_view, { buffer = buf, nowait = true })
  vim.keymap.set("n", "D", safe_on_view, { buffer = buf, nowait = true })
  vim.keymap.set("n", "n", safe_on_dismiss, { buffer = buf, nowait = true })
  vim.keymap.set("n", "N", safe_on_dismiss, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", safe_on_dismiss, { buffer = buf, nowait = true })
  vim.keymap.set("n", "q", safe_on_dismiss, { buffer = buf, nowait = true })
end

function M.show_forked_dialog(remote_log, local_log, remote_count, local_count, on_terminal, on_dismiss)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false

  local lines = {
    M.t("forked_title"),
    "",
    M.t("forked_msg"):format(remote_count, local_count),
    "",
    M.t("forked_remote"),
  }

  local shown_remote = #remote_log > 5 and vim.list_slice(remote_log, 1, 5) or remote_log
  for _, line in ipairs(shown_remote) do
    table.insert(lines, "  " .. line)
  end

  table.insert(lines, "")
  table.insert(lines, M.t("forked_local"))

  local shown_local = #local_log > 5 and vim.list_slice(local_log, 1, 5) or local_log
  for _, line in ipairs(shown_local) do
    table.insert(lines, "  " .. line)
  end

  table.insert(lines, "")
  table.insert(lines, M.t("forked_desc"))
  table.insert(lines, "")
  table.insert(lines, "  " .. M.t("terminal_btn") .. "  " .. M.t("ignore_btn"))

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  local max_width = 0
  for _, line in ipairs(lines) do
    local len = vim.fn.strdisplaywidth(line)
    if len > max_width then
      max_width = len
    end
  end
  local width = math.max(max_width + 4, 40)
  local height = #lines

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    focusable = true,
  })

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  local function safe_on_terminal()
    close()
    if on_terminal then
      on_terminal()
    end
  end

  local function safe_on_dismiss()
    close()
    if on_dismiss then
      on_dismiss()
    end
  end

  vim.keymap.set("n", "t", safe_on_terminal, { buffer = buf, nowait = true })
  vim.keymap.set("n", "T", safe_on_terminal, { buffer = buf, nowait = true })
  vim.keymap.set("n", "n", safe_on_dismiss, { buffer = buf, nowait = true })
  vim.keymap.set("n", "N", safe_on_dismiss, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", safe_on_dismiss, { buffer = buf, nowait = true })
  vim.keymap.set("n", "q", safe_on_dismiss, { buffer = buf, nowait = true })
end

function M.show_conflict_dialog(on_abort, on_terminal)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false

  local lines = {
    M.t("conflict_title"),
    "",
    M.t("conflict_msg"),
    "",
    "  " .. M.t("abort_btn") .. "  " .. M.t("terminal_conflict_btn"),
  }

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  local max_width = 0
  for _, line in ipairs(lines) do
    local len = vim.fn.strdisplaywidth(line)
    if len > max_width then
      max_width = len
    end
  end
  local width = math.max(max_width + 4, 40)
  local height = #lines

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    focusable = true,
  })

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  local function safe_on_abort()
    close()
    if on_abort then
      on_abort()
    end
  end

  local function safe_on_terminal()
    close()
    if on_terminal then
      on_terminal()
    end
  end

  vim.keymap.set("n", "a", safe_on_abort, { buffer = buf, nowait = true })
  vim.keymap.set("n", "A", safe_on_abort, { buffer = buf, nowait = true })
  vim.keymap.set("n", "t", safe_on_terminal, { buffer = buf, nowait = true })
  vim.keymap.set("n", "T", safe_on_terminal, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", safe_on_abort, { buffer = buf, nowait = true })
  vim.keymap.set("n", "q", safe_on_abort, { buffer = buf, nowait = true })
end

function M.notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Vim Update" })
end

return M
