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

function Model.newIndex(id, name)
  return { version = 1, active = id, workspaces = { { id = id, name = name } } }
end

function Model.addEntry(index, id, name)
  index.workspaces[#index.workspaces + 1] = { id = id, name = name }
  index.active = id
end

function Model.renameEntry(index, id, name)
  for _, entry in ipairs(index.workspaces) do
    if entry.id == id then
      entry.name = name
    end
  end
end

-- Removing the active entry activates its left neighbor, or the new first one.
function Model.removeEntry(index, id)
  for i, entry in ipairs(index.workspaces) do
    if entry.id == id then
      table.remove(index.workspaces, i)
      if index.active == id then
        local neighbor = index.workspaces[math.max(1, i - 1)]
        index.active = neighbor and neighbor.id or nil
      end
      return true
    end
  end
  return false
end

function Model.cleanTitle(text)
  local trimmed = string.gsub(text, "^%s+", "")
  trimmed = string.gsub(trimmed, "%s+$", "")
  return trimmed ~= "" and trimmed or nil
end

function Model.findTask(workspace, taskId)
  for _, task in ipairs(workspace.tasks) do
    if task.id == taskId then
      return task
    end
  end
  return nil
end

-- Rows follow the board order: workspaces, then columns, then tasks.
function Model.listTasks(workspaces, query)
  local needle = string.lower(query or "")
  local rows = {}
  for _, workspace in ipairs(workspaces) do
    for _, column in ipairs(workspace.columns) do
      for _, task in ipairs(Model.tasksIn(workspace, column.id)) do
        if needle == "" or string.find(string.lower(task.title), needle, 1, true) then
          rows[#rows + 1] = { task = task, column = column, workspace = workspace }
        end
      end
    end
  end
  return rows
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

function Model.renameTask(workspace, taskId, title)
  local task = Model.findTask(workspace, taskId)
  if task == nil then
    return false
  end
  task.title = title
  return true
end

function Model.setDetail(task, text)
  task.detail = text
end

function Model.deleteTask(workspace, taskId)
  local task = Model.findTask(workspace, taskId)
  if task == nil then
    return false
  end
  table.remove(workspace.tasks, table.find(workspace.tasks, task))
  renumber(Model.tasksIn(workspace, task.columnId))
  return true
end

local function findSubtask(task, subtaskId)
  for i, subtask in ipairs(task.subtasks) do
    if subtask.id == subtaskId then
      return subtask, i
    end
  end
  return nil
end

function Model.addSubtask(task, id, title)
  task.subtasks[#task.subtasks + 1] = { id = id, title = title, done = false }
end

function Model.renameSubtask(task, subtaskId, title)
  local subtask = findSubtask(task, subtaskId)
  if subtask == nil then
    return false
  end
  subtask.title = title
  return true
end

function Model.setSubtaskDone(task, subtaskId, done)
  local subtask = findSubtask(task, subtaskId)
  if subtask == nil then
    return false
  end
  subtask.done = done
  return true
end

function Model.deleteSubtask(task, subtaskId)
  local _, i = findSubtask(task, subtaskId)
  if i == nil then
    return false
  end
  table.remove(task.subtasks, i)
  return true
end

function Model.subtaskProgress(task)
  local left = 0
  for _, subtask in ipairs(task.subtasks) do
    if not subtask.done then
      left += 1
    end
  end
  return left, #task.subtasks
end

-- Moves a task one slot up (-1) or down (1) inside its column.
function Model.shiftTask(workspace, taskId, delta)
  local task = Model.findTask(workspace, taskId)
  if task == nil then
    return false
  end
  local siblings = Model.tasksIn(workspace, task.columnId)
  local target = table.find(siblings, task) + delta
  if target < 1 or target > #siblings then
    return false
  end
  -- moveTask reads the slot before the move, so going down skips one extra.
  return Model.moveTask(workspace, taskId, task.columnId, delta < 0 and target or target + 1)
end

function Model.addColumn(workspace, id, name)
  workspace.columns[#workspace.columns + 1] = { id = id, name = name }
end

function Model.renameColumn(workspace, columnId, name)
  for _, column in ipairs(workspace.columns) do
    if column.id == columnId then
      column.name = name
      return true
    end
  end
  return false
end

function Model.moveColumn(workspace, columnId, delta)
  for i, column in ipairs(workspace.columns) do
    if column.id == columnId then
      local j = i + delta
      if j < 1 or j > #workspace.columns then
        return false
      end
      workspace.columns[i], workspace.columns[j] = workspace.columns[j], workspace.columns[i]
      return true
    end
  end
  return false
end

-- Without force, a column with tasks cannot be deleted; with it, the tasks go
-- too. The last column always stays.
function Model.deleteColumn(workspace, columnId, force)
  if #workspace.columns <= 1 then
    return false
  end
  local tasks = Model.tasksIn(workspace, columnId)
  if #tasks > 0 and not force then
    return false
  end
  for i, column in ipairs(workspace.columns) do
    if column.id == columnId then
      table.remove(workspace.columns, i)
      for _, task in ipairs(tasks) do
        table.remove(workspace.tasks, table.find(workspace.tasks, task))
      end
      return true
    end
  end
  return false
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
