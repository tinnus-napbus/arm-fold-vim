local M = {}

local function indent_width(text)
  return vim.fn.strdisplaywidth(text:match("^%s*"))
end

local function is_core(text)
  return text:match("^%s*|[_%%%^@]%s") or text:match("^%s*|[_%%%^@]$")
end

local function inline_arm_start(text)
  return text:match("^%s*|[_%%%^@]%s+()%+[+%$%*]%s")
    or text:match("^%s*|[_%%%^@]%s+()%+[+%$%*]$")
end

local function is_arm(text)
  return text:match("^%s*%+[+%$%*]%s") or text:match("^%s*%+[+%$%*]$")
end

local function is_end(text)
  return text:match("^%s*%-%-%s") or text:match("^%s*%-%-$")
end

local function find_core(cores, indent)
  for index = #cores, 1, -1 do
    if cores[index].indent == indent then
      return index
    end
  end
end

local function find_arm_core(cores, indent)
  for index = #cores, 1, -1 do
    local core = cores[index]
    if core.arm_indent == indent or (core.arm_indent < 0 and core.indent == indent) then
      return index
    end
  end
end

local function remove_cores(cores, first, active_arm_count)
  for index = #cores, first, -1 do
    if cores[index].has_arm then
      active_arm_count = active_arm_count - 1
    end
    table.remove(cores, index)
  end
  return active_arm_count
end

function M.build_levels()
  local levels = {}
  local cores = {}
  local active_arm_count = 0

  for _, text in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    local indent = indent_width(text)

    if is_core(text) then
      table.insert(levels, active_arm_count)
      local inline_start = inline_arm_start(text)
      local has_arm = inline_start ~= nil
      table.insert(cores, {
        indent = indent,
        arm_indent = has_arm and vim.fn.strdisplaywidth(text:sub(1, inline_start - 1)) or -1,
        has_arm = has_arm,
      })
      if has_arm then
        active_arm_count = active_arm_count + 1
      end
    elseif is_arm(text) then
      local core_index = find_arm_core(cores, indent)
      if core_index then
        active_arm_count = remove_cores(cores, core_index + 1, active_arm_count)
        if cores[core_index].has_arm then
          active_arm_count = active_arm_count - 1
        end
        cores[core_index].has_arm = false
        table.insert(levels, active_arm_count)
        cores[core_index].arm_indent = indent
        cores[core_index].has_arm = true
        active_arm_count = active_arm_count + 1
      else
        table.insert(levels, active_arm_count)
      end
    elseif is_end(text) then
      local core_index = find_core(cores, indent)
      if core_index then
        active_arm_count = remove_cores(cores, core_index, active_arm_count)
      end
      table.insert(levels, active_arm_count)
    else
      local closed_arm_count = 0
      if text:match("%S") then
        for index = #cores, 1, -1 do
          local core = cores[index]
          if core.has_arm and indent <= core.arm_indent then
            core.has_arm = false
            closed_arm_count = closed_arm_count + 1
          end
        end
        active_arm_count = active_arm_count - closed_arm_count
      end

      if closed_arm_count > 0 then
        table.insert(levels, active_arm_count)
      else
        table.insert(levels, active_arm_count > 0 and active_arm_count + 1 or 0)
      end
    end
  end

  return levels
end

return M
