local M = {}

M.defaults = {
  retry = {
    count = 3,
    interval = 3,
    suppress_errors = false,
  },
  fetch = {
    remote = nil,
    branch = nil,
    timeout = 30000,
  },
  dialog = true,
  ahead = {
    auto_push_delay = nil,
  },
  lang = "en",
}

M.options = vim.deepcopy(M.defaults)

function M.setup(user_opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), user_opts or {})

  if M.options.fetch.remote and type(M.options.fetch.remote) ~= "string" then
    M.options.fetch.remote = nil
  end
  if M.options.fetch.branch and type(M.options.fetch.branch) ~= "string" then
    M.options.fetch.branch = nil
  end

  if M.options.ahead.auto_push_delay and type(M.options.ahead.auto_push_delay) ~= "number" then
    M.options.ahead.auto_push_delay = nil
  end
  if M.options.ahead.auto_push_delay and M.options.ahead.auto_push_delay <= 0 then
    M.options.ahead.auto_push_delay = nil
  end

  if not vim.tbl_contains({ "en", "zh" }, M.options.lang) then
    M.options.lang = "en"
  end
end

return M
