--!nonstrict
local Model = {}

local DEFAULT_COLUMNS = { "To do", "In progress", "Done" }

function Model.newWorkspace(id, name, columnIds)
  local columns = {}
  for i, columnName in ipairs(DEFAULT_COLUMNS) do
    columns[i] = { id = columnIds[i], name = columnName }
  end
  return { version = 1, id = id, name = name, columns = columns, tasks = {} }
end

function Model.findTask(workspace, taskId)
  for _, task in ipairs(workspace.tasks) do
    if task.id == taskId then
      return task
    end
  end
  return nil
end

function Model.hasColumn(workspace, columnId)
  for _, column in ipairs(workspace.columns) do
    if column.id == columnId then
      return true
    end
  end
  return false
end

function Model.tasksIn(workspace, columnId)
  local list = {}
  for _, task in ipairs(workspace.tasks) do
    if task.columnId == columnId then
      list[#list + 1] = task
    end
  end
  table.sort(list, function(a, b)
    return a.order < b.order
  end)
  return list
end

local function renumber(list)
  for i, task in ipairs(list) do
    task.order = i
  end
end

function Model.addTask(workspace, columnId, title, id)
  if not Model.hasColumn(workspace, columnId) then
    return nil
  end
  local task = {
    id = id,
    title = title,
    columnId = columnId,
    order = #Model.tasksIn(workspace, columnId) + 1,
    detail = "",
    subtasks = {},
  }
  workspace.tasks[#workspace.tasks + 1] = task
  return task
end

-- index is the 1-based slot in the target column as seen before the move,
-- matching what the drop zones report; nil appends.
function Model.moveTask(workspace, taskId, columnId, index)
  local task = Model.findTask(workspace, taskId)
  if task == nil or not Model.hasColumn(workspace, columnId) then
    return false
  end

  local source = Model.tasksIn(workspace, task.columnId)
  local fromIndex = table.find(source, task)
  table.remove(source, fromIndex)

  local sameColumn = columnId == task.columnId
  local target = sameColumn and source or Model.tasksIn(workspace, columnId)
  local insertAt = index or (#target + 1)
  if sameColumn and index ~= nil and fromIndex < index then
    insertAt -= 1
  end
  insertAt = math.max(1, math.min(insertAt, #target + 1))

  task.columnId = columnId
  table.insert(target, insertAt, task)
  renumber(target)
  if not sameColumn then
    renumber(source)
  end
  return true
end

return Model
