local M = {}

function M.check()
  vim.health.start("Vim Update")

  local config_dir = vim.fn.stdpath("config")
  vim.health.info("Config directory: " .. config_dir)

  local git_ok = vim.fn.executable("git") == 1
  if git_ok then
    vim.health.ok("git executable found")
  else
    vim.health.error("git executable not found")
    return
  end

  local result = vim.system({ "git", "rev-parse", "--git-dir" }, {
    cwd = config_dir,
    text = true,
    timeout = 5000,
  }):wait()

  if result.code == 0 then
    vim.health.ok("Config directory is a git repository")
  else
    vim.health.error("Config directory is not a git repository")
    return
  end

  local upstream_result = vim.system({ "git", "rev-parse", "--abbrev-ref", "@{upstream}" }, {
    cwd = config_dir,
    text = true,
    timeout = 5000,
  }):wait()

  if upstream_result.code == 0 and upstream_result.stdout then
    local upstream = vim.trim(upstream_result.stdout)
    vim.health.ok("Upstream tracked: " .. upstream)
  else
    vim.health.warn("No upstream configured for current branch")
  end

  local remote_result = vim.system({ "git", "remote", "get-url", "origin" }, {
    cwd = config_dir,
    text = true,
    timeout = 5000,
  }):wait()

  if remote_result.code == 0 and remote_result.stdout then
    local remote_url = vim.trim(remote_result.stdout)
    vim.health.ok("Remote 'origin' available: " .. remote_url)
  else
    vim.health.error("Remote 'origin' not found")
  end
end

return M
