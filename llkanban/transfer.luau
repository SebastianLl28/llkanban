--!nonstrict
local Model = require("./model.luau")

local Transfer = {}

local FORMAT = "llkanban-export"
local FORMAT_VERSION = 1

function Transfer.encode(workspaces)
  return noctalia.json.encode({ format = FORMAT, version = FORMAT_VERSION, workspaces = workspaces }, true)
end

local function isText(value)
  return type(value) == "string" and value ~= ""
end

local function validWorkspace(workspace)
  if type(workspace) ~= "table" or not isText(workspace.name) then
    return false
  end
  if type(workspace.columns) ~= "table" or #workspace.columns == 0 or type(workspace.tasks) ~= "table" then
    return false
  end
  local columnIds = {}
  for _, column in ipairs(workspace.columns) do
    if type(column) ~= "table" or not isText(column.id) or not isText(column.name) then
      return false
    end
    columnIds[column.id] = true
  end
  for _, task in ipairs(workspace.tasks) do
    if type(task) ~= "table" or not isText(task.title) or not columnIds[task.columnId] then
      return false
    end
    if type(task.subtasks) ~= "table" then
      return false
    end
    for _, subtask in ipairs(task.subtasks) do
      if type(subtask) ~= "table" or not isText(subtask.title) then
        return false
      end
    end
  end
  return true
end

-- Returns the workspaces of an export, or nil and a translation key saying why the file was rejected.
function Transfer.decode(raw)
  local ok, value = pcall(noctalia.json.decode, raw)
  if not ok or type(value) ~= "table" or value.format ~= FORMAT then
    return nil, "transfer.error_format"
  end
  if value.version ~= FORMAT_VERSION then
    return nil, "transfer.error_version"
  end
  if type(value.workspaces) ~= "table" or #value.workspaces == 0 then
    return nil, "transfer.error_empty"
  end
  for _, workspace in ipairs(value.workspaces) do
    if type(workspace) == "table" and workspace.version == 1 and type(workspace.columns) == "table" then
      Model.upgradeWorkspace(workspace)
    end
    if not validWorkspace(workspace) then
      return nil, "transfer.error_format"
    end
  end
  return value.workspaces
end

local function uniqueName(name, takenNames)
  local candidate = name
  local n = 1
  while takenNames[candidate] do
    n += 1
    candidate = string.format("%s (%d)", name, n)
  end
  takenNames[candidate] = true
  return candidate
end

-- Fresh ids keep an import from ever overwriting an existing workspace file.
function Transfer.adopt(workspace, newId, takenNames)
  local columnIds = {}
  local columns = {}
  for i, column in ipairs(workspace.columns) do
    columnIds[column.id] = newId("c")
    columns[i] = { id = columnIds[column.id], name = column.name, closed = column.closed == true }
  end

  local tasks = {}
  for i, task in ipairs(workspace.tasks) do
    local subtasks = {}
    for j, subtask in ipairs(task.subtasks) do
      subtasks[j] = { id = newId("s"), title = subtask.title, done = subtask.done == true }
    end
    tasks[i] = {
      id = newId("t"),
      columnId = columnIds[task.columnId],
      order = tonumber(task.order) or i,
      title = task.title,
      detail = type(task.detail) == "string" and task.detail or "",
      subtasks = subtasks,
    }
  end

  return {
    version = Model.WORKSPACE_VERSION,
    id = newId("ws"),
    name = uniqueName(workspace.name, takenNames),
    columns = columns,
    tasks = tasks,
  }
end

return Transfer
