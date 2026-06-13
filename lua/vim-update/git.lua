local M = {}

local function run_sync(cmd, cwd, timeout)
  local obj = vim.system(cmd, {
    cwd = cwd,
    text = true,
    timeout = timeout,
  }):wait()
  return {
    code = obj.code,
    stdout = vim.trim(obj.stdout or ""),
    stderr = vim.trim(obj.stderr or ""),
  }
end

function M.git_exists()
  return vim.fn.executable("git") == 1
end

function M.is_git_repo(path)
  local result = run_sync({ "git", "rev-parse", "--git-dir" }, path, 5000)
  return result.code == 0
end

function M.get_upstream(path)
  local result = run_sync({ "git", "rev-parse", "--abbrev-ref", "@{upstream}" }, path, 5000)
  if result.code ~= 0 or result.stdout == "" then
    return nil, nil
  end
  local upstream = result.stdout
  local remote, branch = upstream:match("^([^/]+)/(.+)$")
  return remote, branch
end

function M.fetch(path, remote, branch, timeout, callback)
  local args = { "git", "fetch", remote, branch }
  vim.system(args, {
    cwd = path,
    text = true,
    timeout = timeout,
  }, function(obj)
    local result = {
      code = obj.code,
      stdout = vim.trim(obj.stdout or ""),
      stderr = vim.trim(obj.stderr or ""),
    }
    callback(result)
  end)
end

function M.check_behind_ahead(path, remote, branch)
  local behind_count = M.get_rev_count(path, "HEAD.." .. remote .. "/" .. branch)

  local ahead_count = M.get_rev_count(path, remote .. "/" .. branch .. "..HEAD")

  if behind_count == nil or ahead_count == nil then
    return nil
  end

  return {
    behind = behind_count,
    ahead = ahead_count,
    forked = behind_count > 0 and ahead_count > 0,
  }
end

function M.get_rev_count(path, range)
  local result = run_sync({ "git", "rev-list", "--count", range }, path, 5000)
  if result.code ~= 0 then
    return nil
  end
  return tonumber(result.stdout) or 0
end

function M.pull_rebase(path, remote, branch, timeout, callback)
  local args = { "git", "pull", "--rebase", remote, branch }
  vim.system(args, {
    cwd = path,
    text = true,
    timeout = timeout,
  }, function(obj)
    local result = {
      code = obj.code,
      stdout = vim.trim(obj.stdout or ""),
      stderr = vim.trim(obj.stderr or ""),
    }
    callback(result)
  end)
end

function M.rebase_abort(path, timeout)
  local result = run_sync({ "git", "rebase", "--abort" }, path, timeout)
  return result.code == 0
end

function M.push(path, remote, branch, timeout, callback)
  local args = { "git", "push", remote, branch }
  vim.system(args, {
    cwd = path,
    text = true,
    timeout = timeout,
  }, function(obj)
    local result = {
      code = obj.code,
      stdout = vim.trim(obj.stdout or ""),
      stderr = vim.trim(obj.stderr or ""),
    }
    callback(result)
  end)
end

function M.get_log(path, remote, branch, count)
  count = count or 20
  local range = "HEAD.." .. remote .. "/" .. branch
  local result = run_sync({ "git", "log", range, "--oneline", "-n", tostring(count) }, path, 5000)
  if result.code ~= 0 then
    return {}
  end
  if result.stdout == "" then
    return {}
  end
  local lines = {}
  for line in result.stdout:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  return lines
end

function M.get_earliest_unpushed_author_date(path, remote, branch)
  local range = remote .. "/" .. branch .. "..HEAD"
  local result = run_sync(
    { "git", "log", range, "--format=%at", "--reverse", "-n", "1" },
    path,
    5000
  )
  if result.code ~= 0 or result.stdout == "" then
    return nil
  end
  return tonumber(result.stdout)
end

function M.get_unpushed_log(path, remote, branch, count)
  count = count or 20
  local range = remote .. "/" .. branch .. "..HEAD"
  local result = run_sync({ "git", "log", range, "--oneline", "-n", tostring(count) }, path, 5000)
  if result.code ~= 0 then
    return {}
  end
  if result.stdout == "" then
    return {}
  end
  local lines = {}
  for line in result.stdout:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  return lines
end

function M.get_current_branch(path)
  local result = run_sync({ "git", "rev-parse", "--abbrev-ref", "HEAD" }, path, 5000)
  if result.code ~= 0 then
    return nil
  end
  local branch = result.stdout
  if branch == "HEAD" then
    return nil
  end
  return branch
end

return M
