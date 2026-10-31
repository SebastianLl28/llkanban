--!nonstrict
local Model = require("./model.luau")
local Store = require("./store.luau")

local DRAG_TYPE = "llkanban-task"

local workspace = nil
local inputRev = 0
local closeButton = true

local function tr(key)
  return noctalia.tr(key)
end

local function persist()
  if not Store.save(workspace) then
    noctalia.notify(tr("board.save_failed"))
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

function onAddSubmitted(text)
  local title = string.gsub(text, "^%s+", "")
  title = string.gsub(title, "%s+$", "")
  if title == "" then
    return
  end
  Model.addTask(workspace, workspace.columns[1].id, title, Store.newId("t"))
  persist()
  inputRev += 1
  render()
end

function onCloseClicked()
  panel.close()
end

local function taskCard(task)
  return ui.row({
    key = "task-" .. task.id,
    gap = 8,
    align = "center",
    padding = 6,
    fill = "surface_container/0.4",
    radius = 10,
  }, {
    ui.dragSource({
      key = "grip-" .. task.id,
      dragType = DRAG_TYPE,
      payload = task.id,
      previewAncestor = 1,
      liftFromLayout = true,
      width = 24,
      height = 24,
      align = "center",
      justify = "center",
    }, {
      ui.glyph({ name = "menu-2", size = 14, color = "on_surface_variant" }),
    }),
    ui.label({ text = task.title, flexGrow = 1 }),
  })
end

local function insertionZone(column, slot)
  return ui.dropZone({
    key = string.format("gap-%s-%d", column.id, slot),
    accepts = { DRAG_TYPE },
    value = string.format("%s:%d", column.id, slot),
    onDrop = "onTaskDropped",
    height = 3,
    radius = 6,
    expandOnDrag = true,
    hitSlop = 28,
  })
end

local function columnView(column)
  local tasks = Model.tasksIn(workspace, column.id)
  local cards = {}
  for i, task in ipairs(tasks) do
    cards[#cards + 1] = insertionZone(column, i)
    cards[#cards + 1] = taskCard(task)
  end
  cards[#cards + 1] = insertionZone(column, #tasks + 1)

  return ui.dropZone({
    key = "column-" .. column.id,
    accepts = { DRAG_TYPE },
    value = column.id,
    onDrop = "onTaskDropped",
    gap = 6,
    padding = 8,
    radius = 12,
    fill = "surface_container/0.15",
    flexGrow = 1,
  }, {
    ui.label({
      text = string.format("%s (%d)", column.name, #tasks),
      fontWeight = "bold",
      color = "on_surface_variant",
    }),
    ui.scroll({ flexGrow = 1, gap = 4 }, cards),
  })
end

function render()
  local header = {
    ui.label({ text = tr("board.title"), fontSize = 16, fontWeight = "bold", color = "on_surface", flexGrow = 1 }),
  }
  if closeButton then
    header[#header + 1] = ui.button({ glyph = "close", onClick = "onCloseClicked" })
  end

  local columns = {}
  for _, column in ipairs(workspace.columns) do
    columns[#columns + 1] = columnView(column)
  end

  panel.render(ui.column({ flexGrow = 1, gap = 12 }, {
    ui.row({ align = "center", gap = 8 }, header),
    -- A fresh key per submit remounts the uncontrolled input, which clears it.
    ui.input({
      key = "new-task-" .. inputRev,
      placeholder = tr("board.add_placeholder"),
      submitOnEnter = true,
      focus = true,
      onSubmit = "onAddSubmitted",
    }),
    ui.row({ gap = 12, align = "stretch", flexGrow = 1 }, columns),
  }))
end

function onOpen(_context)
  closeButton = noctalia.getSetting("shell.show_close_buttons") ~= false
  workspace = loadWorkspace()
  render()
end
