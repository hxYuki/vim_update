local M = {}

M.State = {
  IDLE = "idle",
  FETCHING = "fetching",
  UP_TO_DATE = "up_to_date",
  BEHIND = "behind",
  AHEAD = "ahead",
  FORKED = "forked",
  ERROR = "error",
  PULLING = "pulling",
  PUSHING = "pushing",
  CONFLICT = "conflict",
  SHOWING_DIALOG = "showing_dialog",
}

M.current = M.State.IDLE
M.busy = false
M.last_error = nil
M.retry_count = 0

function M.transition(new_state)
  M.current = new_state
end

function M.is_busy()
  return M.busy
end

function M.set_busy(busy)
  M.busy = busy
end

function M.can_start_check()
  return M.current == M.State.IDLE and not M.busy
end

function M.can_execute_command()
  return not M.busy
end

return M
