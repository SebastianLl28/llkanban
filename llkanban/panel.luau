--!nonstrict
local Model = require("./model.luau")
local Store = require("./store.luau")
local Board = require("./views/board.luau")
local Detail = require("./views/detail.luau")
local List = require("./views/list.luau")

-- update() runs once per second; the description saves after this many quiet ticks.
local AUTOSAVE_IDLE_TICKS = 2

local workspace = nil
local index = nil
local closeButton = true
local state = {
  editing = nil,
  inputRev = 0,
  force = false,
  openTaskId = nil,
  detailMode = "preview",
  detailFocus = "subtask",
  view = "board",
  query = "",
  allWorkspaces = false,
}
-- Workspaces other than the active one, loaded when the list needs them.
local others = {}
local actions = {}
local detailDirty = false
local idleTicks = 0
local saveCount = 0

local function notifyFailure()
  noctalia.notify(noctalia.tr("board.save_failed"))
end

local function publishChange()
  saveCount += 1
  noctalia.state.set("data_rev", string.format("%d:%d", noctalia.nowMs(), saveCount))
end

local function persist()
  detailDirty = false
  if not Store.saveWorkspace(workspace) then
    notifyFailure()
    return
  end
  publishChange()
end

local function flushDetail()
  if detailDirty then
    persist()
  end
end

local function persistIndex()
  if not Store.saveIndex(index) then
    notifyFailure()
    return
  end
  publishChange()
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

local function loadOthers()
  others = {}
  if not state.allWorkspaces then
    return
  end
  for _, entry in ipairs(index.workspaces) do
    if entry.id ~= workspace.id then
      others[entry.id] = Store.loadWorkspace(entry.id)
    end
  end
end

local function listedWorkspaces()
  if not state.allWorkspaces then
    return { workspace }
  end
  local list = {}
  for _, entry in ipairs(index.workspaces) do
    local listed = entry.id == workspace.id and workspace or others[entry.id]
    if listed ~= nil then
      list[#list + 1] = listed
    end
  end
  return list
end

function render()
  state.force = noctalia.getConfig("force_delete") == true
  local task = state.openTaskId and Model.findTask(workspace, state.openTaskId)
  if task then
    panel.render(Detail.render(workspace, task, state, actions))
    return
  end
  state.openTaskId = nil
  if state.view == "list" then
    local rows = Model.listTasks(listedWorkspaces(), state.query)
    panel.render(List.render(rows, state, actions, closeButton))
    return
  end
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

function actions.showList()
  state.view = "list"
  loadOthers()
  finish(false)
end

function actions.showBoard()
  state.view = "board"
  finish(false)
end

function actions.setQuery(text)
  state.query = text
  render()
end

function actions.setAllWorkspaces(value)
  state.allWorkspaces = value == "true"
  loadOthers()
  render()
end

-- A task without a description opens straight into the editor.
local function beginDetail(taskId)
  local task = Model.findTask(workspace, taskId)
  state.openTaskId = taskId
  state.detailMode = task.detail == "" and "edit" or "preview"
  state.detailFocus = state.detailMode == "edit" and "description" or "subtask"
  state.inputRev += 1
end

function actions.openListedTask(workspaceId, taskId)
  if workspaceId ~= workspace.id then
    local target = others[workspaceId] or Store.loadWorkspace(workspaceId)
    if target == nil then
      notifyFailure()
      return
    end
    workspace = target
    index.active = workspaceId
    persistIndex()
  end
  beginDetail(taskId)
  finish(false)
end

function actions.openTask(id)
  beginDetail(id)
  finish(false)
end

function actions.closeTask()
  flushDetail()
  state.openTaskId = nil
  state.inputRev += 1
  finish(false)
end

local function currentTask()
  return Model.findTask(workspace, state.openTaskId)
end

function actions.addSubtask(text)
  local title = Model.cleanTitle(text)
  if title == nil then
    return
  end
  Model.addSubtask(currentTask(), Store.newId("s"), title)
  state.detailFocus = "subtask"
  state.inputRev += 1
  finish(true)
end

function actions.editDetail(text)
  local task = currentTask()
  if task ~= nil then
    Model.setDetail(task, text)
    detailDirty = true
    idleTicks = 0
  end
end

function actions.saveDetail(text)
  actions.editDetail(text)
  flushDetail()
end

function actions.toggleDetailMode()
  flushDetail()
  state.detailMode = state.detailMode == "edit" and "preview" or "edit"
  state.detailFocus = state.detailMode == "edit" and "description" or "subtask"
  finish(false)
end

-- position is the 0-based index reported by the column select.
function actions.moveTaskTo(position)
  local column = workspace.columns[(tonumber(position) or -1) + 1]
  local task = currentTask()
  if column == nil or task == nil or column.id == task.columnId then
    return
  end
  finish(Model.moveTask(workspace, task.id, column.id, nil))
end

function actions.shiftTask(delta)
  finish(Model.shiftTask(workspace, state.openTaskId, delta))
end

function actions.setSubtaskDone(id, done)
  finish(Model.setSubtaskDone(currentTask(), id, done))
end

function actions.renameSubtask(id, text)
  local title = Model.cleanTitle(text)
  finish(title ~= nil and Model.renameSubtask(currentTask(), id, title))
end

function actions.deleteSubtask(id)
  finish(Model.deleteSubtask(currentTask(), id))
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

function onClose()
  flushDetail()
end

function update()
  if not detailDirty then
    return
  end
  idleTicks += 1
  if idleTicks >= AUTOSAVE_IDLE_TICKS then
    flushDetail()
  end
end

function onOpen(_context)
  closeButton = noctalia.getSetting("shell.show_close_buttons") ~= false
  bootstrap()
  state.editing = nil
  state.openTaskId = nil
  detailDirty = false
  state.view = "board"
  state.query = ""
  state.allWorkspaces = false
  render()
end
