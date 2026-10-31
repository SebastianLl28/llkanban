--!nonstrict
local Model = require("./model.luau")
local Store = require("./store.luau")
local Board = require("./views/board.luau")
local Detail = require("./views/detail.luau")

local workspace = nil
local index = nil
local closeButton = true
local state = { editing = nil, inputRev = 0, force = false, openTaskId = nil }
local actions = {}

local function notifyFailure()
  noctalia.notify(noctalia.tr("board.save_failed"))
end

local function persist()
  if not Store.saveWorkspace(workspace) then
    notifyFailure()
  end
end

local function persistIndex()
  if not Store.saveIndex(index) then
    notifyFailure()
  end
end

local function createWorkspace(name)
  local columnIds = { Store.newId("c"), Store.newId("c"), Store.newId("c") }
  return Model.newWorkspace(Store.newId("ws"), name, columnIds)
end

local function bootstrap()
  index = Store.loadIndex()
  workspace = nil
  if index ~= nil then
    while workspace == nil and index.active ~= nil do
      workspace = Store.loadWorkspace(index.active)
      if workspace == nil then
        Model.removeEntry(index, index.active)
      end
    end
  else
    workspace = Store.adoptLegacy()
    if workspace ~= nil then
      index = Model.newIndex(workspace.id, workspace.name)
    end
  end
  if workspace == nil then
    workspace = createWorkspace("Default")
    index = Model.newIndex(workspace.id, workspace.name)
    persist()
  end
  persistIndex()
end

function render()
  state.force = noctalia.getConfig("force_delete") == true
  local task = state.openTaskId and Model.findTask(workspace, state.openTaskId)
  if task then
    panel.render(Detail.render(task, state, actions))
    return
  end
  state.openTaskId = nil
  panel.render(Board.render(index, workspace, state, actions, closeButton))
end

local function finish(changed)
  state.editing = nil
  if changed then
    persist()
  end
  render()
end

function actions.close()
  panel.close()
end

function actions.beginEdit(kind, id)
  state.editing = { kind = kind, id = id }
  render()
end

function actions.cancel()
  finish(false)
end

function actions.openTask(id)
  state.openTaskId = id
  state.inputRev += 1
  finish(false)
end

function actions.closeTask()
  state.openTaskId = nil
  state.inputRev += 1
  finish(false)
end

local function openTask()
  return Model.findTask(workspace, state.openTaskId)
end

function actions.addSubtask(text)
  local title = Model.cleanTitle(text)
  if title == nil then
    return
  end
  Model.addSubtask(openTask(), Store.newId("s"), title)
  state.inputRev += 1
  finish(true)
end

function actions.setSubtaskDone(id, done)
  finish(Model.setSubtaskDone(openTask(), id, done))
end

function actions.renameSubtask(id, text)
  local title = Model.cleanTitle(text)
  finish(title ~= nil and Model.renameSubtask(openTask(), id, title))
end

function actions.deleteSubtask(id)
  finish(Model.deleteSubtask(openTask(), id))
end

function actions.deleteTask(id)
  finish(Model.deleteTask(workspace, id))
end

function actions.deleteColumn(id)
  finish(Model.deleteColumn(workspace, id, state.force))
end

function actions.switchWorkspace(id)
  if id == index.active then
    return
  end
  local target = Store.loadWorkspace(id)
  if target == nil then
    notifyFailure()
    return
  end
  workspace = target
  index.active = id
  persistIndex()
  state.inputRev += 1
  finish(false)
end

function actions.addWorkspace(text)
  local name = Model.cleanTitle(text)
  if name == nil then
    finish(false)
    return
  end
  workspace = createWorkspace(name)
  persist()
  Model.addEntry(index, workspace.id, workspace.name)
  persistIndex()
  state.inputRev += 1
  finish(false)
end

function actions.renameWorkspace(text)
  local name = Model.cleanTitle(text)
  if name ~= nil then
    workspace.name = name
    Model.renameEntry(index, workspace.id, name)
    persist()
    persistIndex()
  end
  finish(false)
end

function actions.deleteWorkspace()
  if (#workspace.tasks > 0 and not state.force) or #index.workspaces <= 1 then
    return
  end
  local removed = workspace.id
  Model.removeEntry(index, removed)
  Store.deleteWorkspace(removed)
  workspace = Store.loadWorkspace(index.active)
  if workspace == nil then
    bootstrap()
  end
  persistIndex()
  state.inputRev += 1
  finish(false)
end

function actions.addTask(text)
  local title = Model.cleanTitle(text)
  if title == nil then
    return
  end
  Model.addTask(workspace, workspace.columns[1].id, title, Store.newId("t"))
  state.inputRev += 1
  finish(true)
end

function actions.renameTask(id, text)
  local title = Model.cleanTitle(text)
  finish(title ~= nil and Model.renameTask(workspace, id, title))
end

function actions.addColumn(text)
  local name = Model.cleanTitle(text)
  if name ~= nil then
    Model.addColumn(workspace, Store.newId("c"), name)
  end
  finish(name ~= nil)
end

function actions.renameColumn(id, text)
  local name = Model.cleanTitle(text)
  finish(name ~= nil and Model.renameColumn(workspace, id, name))
end

function actions.moveColumn(id, delta)
  if Model.moveColumn(workspace, id, delta) then
    persist()
  end
  render()
end

-- value is "<columnId>" (append) or "<columnId>:<slot>" (insert before slot).
function onTaskDropped(taskId, value)
  local columnId, slot = string.match(value, "^(.-):(%d+)$")
  if columnId == nil then
    columnId = value
  end
  if Model.moveTask(workspace, taskId, columnId, slot and tonumber(slot) or nil) then
    persist()
  end
  render()
end

function onOpen(_context)
  closeButton = noctalia.getSetting("shell.show_close_buttons") ~= false
  bootstrap()
  state.editing = nil
  state.openTaskId = nil
  render()
end
