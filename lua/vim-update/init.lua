local config = require("vim-update.config")
local git = require("vim-update.git")
local state = require("vim-update.state")
local ui = require("vim-update.ui")

local M = {}

local function get_config_dir()
  return vim.fn.stdpath("config")
end

local function get_remote_and_branch(config_dir)
  local remote = config.options.fetch.remote
  local branch = config.options.fetch.branch

  if not remote or not branch then
    local upstream_remote, upstream_branch = git.get_upstream(config_dir)
    remote = remote or upstream_remote
    branch = branch or upstream_branch
  end

  return remote, branch
end

local function is_insert_mode()
  return vim.fn.mode() == "i"
end

local function should_show_dialog()
  return config.options.dialog and not is_insert_mode()
end

local function do_fetch_with_retry(config_dir, remote, branch, attempt, callback)
  if attempt > config.options.retry.count then
    if not config.options.retry.suppress_errors then
      ui.notify(ui.t("fetch_failed"), vim.log.levels.ERROR)
    end
    state.transition(state.State.ERROR)
    state.set_busy(false)
    return
  end

  state.transition(state.State.FETCHING)

  git.fetch(config_dir, remote, branch, config.options.fetch.timeout, function(result)
    if result.code == 0 then
      callback(true)
    else
      vim.defer_fn(function()
        do_fetch_with_retry(config_dir, remote, branch, attempt + 1, callback)
      end, config.options.retry.interval * 1000)
    end
  end)
end

local function handle_check_result(config_dir, remote, branch, status)
  if status == nil then
    if not config.options.retry.suppress_errors then
      ui.notify(ui.t("fetch_failed"), vim.log.levels.ERROR)
    end
    state.transition(state.State.ERROR)
    state.set_busy(false)
    return
  end

  if status.forked then
    state.transition(state.State.FORKED)
    handle_forked(config_dir, remote, branch, status.behind, status.ahead)
  elseif status.behind > 0 then
    state.transition(state.State.BEHIND)
    handle_behind(config_dir, remote, branch, status.behind)
  elseif status.ahead > 0 then
    state.transition(state.State.AHEAD)
    handle_ahead(config_dir, remote, branch, status.ahead)
  else
    state.transition(state.State.UP_TO_DATE)
    state.set_busy(false)
  end
end

local function handle_behind(config_dir, remote, branch, behind_count)
  local log_lines = git.get_log(config_dir, remote, branch)

  if should_show_dialog() then
    state.transition(state.State.SHOWING_DIALOG)
    ui.show_dialog(
      log_lines,
      behind_count,
      function()
        do_pull(config_dir, remote, branch)
      end,
      function()
        do_view_changes(config_dir, remote, branch)
      end,
      function()
        state.transition(state.State.IDLE)
        state.set_busy(false)
      end
    )
  else
    ui.notify(ui.t("behind_notify"):format(behind_count), vim.log.levels.INFO)
    state.transition(state.State.IDLE)
    state.set_busy(false)
  end
end

local function handle_ahead(config_dir, remote, branch, ahead_count)
  local delay = config.options.ahead.auto_push_delay
  if delay then
    local earliest_author = git.get_earliest_unpushed_author_date(config_dir, remote, branch)
    if earliest_author then
      local now = os.time()
      local elapsed_hours = (now - earliest_author) / 3600
      if elapsed_hours >= delay then
        ui.notify(ui.t("auto_pushing"), vim.log.levels.INFO)
        state.transition(state.State.PUSHING)
        git.push(config_dir, remote, branch, config.options.fetch.timeout, function(result)
          if result.code == 0 then
            ui.notify(ui.t("auto_push_success"), vim.log.levels.INFO)
          else
            ui.notify(ui.t("auto_push_failed"), vim.log.levels.ERROR)
          end
          state.transition(state.State.IDLE)
          state.set_busy(false)
        end)
        return
      end
    end
  end

  ui.notify(ui.t("ahead_notify"):format(ahead_count), vim.log.levels.INFO)
  state.transition(state.State.IDLE)
  state.set_busy(false)
end

local function handle_forked(config_dir, remote, branch, remote_count, local_count)
  local remote_log = git.get_log(config_dir, remote, branch)
  local local_log_lines = git.get_unpushed_log(config_dir, remote, branch)

  if should_show_dialog() then
    state.transition(state.State.SHOWING_DIALOG)
    ui.show_forked_dialog(
      remote_log,
      local_log_lines,
      remote_count,
      local_count,
      function()
        ui.open_terminal()
        state.transition(state.State.IDLE)
        state.set_busy(false)
      end,
      function()
        state.transition(state.State.IDLE)
        state.set_busy(false)
      end
    )
  else
    ui.notify(ui.t("forked_notify"), vim.log.levels.WARN)
    state.transition(state.State.IDLE)
    state.set_busy(false)
  end
end

local function do_pull(config_dir, remote, branch)
  state.transition(state.State.PULLING)
  git.pull_rebase(config_dir, remote, branch, config.options.fetch.timeout, function(result)
    if result.code == 0 then
      ui.notify(ui.t("update_success"), vim.log.levels.INFO)
      state.transition(state.State.IDLE)
      state.set_busy(false)
    else
      state.transition(state.State.CONFLICT)
      ui.show_conflict_dialog(
        function()
          git.rebase_abort(config_dir, config.options.fetch.timeout)
          ui.notify(ui.t("conflict_aborted"), vim.log.levels.WARN)
          state.transition(state.State.IDLE)
          state.set_busy(false)
        end,
        function()
          ui.open_terminal()
          state.transition(state.State.IDLE)
          state.set_busy(false)
        end
      )
    end
  end)
end

local function do_view_changes(config_dir, remote, branch)
  local log_lines = git.get_log(config_dir, remote, branch)
  vim.schedule(function()
    ui.view_changes(log_lines, remote, branch)
    state.transition(state.State.IDLE)
    state.set_busy(false)
  end)
end

function M.start_check()
  if not state.can_start_check() then
    return
  end

  local config_dir = get_config_dir()

  if not git.git_exists() then
    return
  end

  if not git.is_git_repo(config_dir) then
    return
  end

  local remote, branch = get_remote_and_branch(config_dir)
  if not remote or not branch then
    return
  end

  state.set_busy(true)
  do_fetch_with_retry(config_dir, remote, branch, 1, function(success)
    if not success then
      return
    end

    local status = git.check_behind_ahead(config_dir, remote, branch)
    handle_check_result(config_dir, remote, branch, status)
  end)
end

function M.execute_command()
  if not state.can_execute_command() then
    ui.notify(ui.t("busy"), vim.log.levels.WARN)
    return
  end

  local config_dir = get_config_dir()

  if not git.git_exists() then
    return
  end

  if not git.is_git_repo(config_dir) then
    return
  end

  local remote, branch = get_remote_and_branch(config_dir)
  if not remote or not branch then
    return
  end

  state.set_busy(true)
  state.transition(state.State.FETCHING)

  git.fetch(config_dir, remote, branch, config.options.fetch.timeout, function(result)
    if result.code ~= 0 then
      if not config.options.retry.suppress_errors then
        ui.notify(ui.t("fetch_failed"), vim.log.levels.ERROR)
      end
      state.transition(state.State.ERROR)
      state.set_busy(false)
      return
    end

    local status = git.check_behind_ahead(config_dir, remote, branch)
    if status == nil then
      state.set_busy(false)
      return
    end

    if status.forked then
      ui.notify(ui.t("update_forked"), vim.log.levels.WARN)
      state.transition(state.State.IDLE)
      state.set_busy(false)
    elseif status.behind > 0 then
      do_pull(config_dir, remote, branch)
    elseif status.ahead > 0 then
      state.transition(state.State.PUSHING)
      git.push(config_dir, remote, branch, config.options.fetch.timeout, function(push_result)
        if push_result.code == 0 then
          ui.notify(ui.t("auto_push_success"), vim.log.levels.INFO)
        else
          ui.notify(ui.t("auto_push_failed"), vim.log.levels.ERROR)
        end
        state.transition(state.State.IDLE)
        state.set_busy(false)
      end)
    else
      ui.notify(ui.t("update_noop"), vim.log.levels.INFO)
      state.transition(state.State.IDLE)
      state.set_busy(false)
    end
  end)
end

return M
