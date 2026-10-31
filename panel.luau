--!nonstrict
local Model = require("./model.luau")
local Store = require("./store.luau")
local Board = require("./views/board.luau")

local workspace = nil
local closeButton = true
local state = { editing = nil, inputRev = 0 }
local actions = {}

local function persist()
  if not Store.save(workspace) then
    noctalia.notify(noctalia.tr("board.save_failed"))
  end
end

local function loadWorkspace()
  local loaded = Store.load()
  if loaded ~= nil then
    return loaded
  end
  local columnIds = { Store.newId("c"), Store.newId("c"), Store.newId("c") }
  return Model.newWorkspace(Store.newId("ws"), "Default", columnIds)
end

function render()
  panel.render(Board.render(workspace, state, actions, closeButton))
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

function actions.deleteTask(id)
  finish(Model.deleteTask(workspace, id))
end

function actions.deleteColumn(id)
  finish(Model.deleteColumn(workspace, id))
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
  workspace = loadWorkspace()
  state.editing = nil
  render()
end
