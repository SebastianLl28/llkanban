--!nonstrict
local Model = require("../model.luau")
local Detail = require("./detail.luau")

local Board = {}

local DRAG_TYPE = "llkanban-task"

local function tr(key)
  return noctalia.tr(key)
end

local function isEditing(state, kind, id)
  return state.editing ~= nil and state.editing.kind == kind and state.editing.id == id
end

local function cancelButton(actions)
  return ui.button({ glyph = "close", variant = "ghost", tooltip = tr("board.cancel"), onClick = actions.cancel })
end

local function taskMeta(task)
  local progress = Detail.progressText(task)
  local children = {}
  if task.detail ~= "" then
    children[#children + 1] = ui.glyph({ name = "file-text", size = 14, color = "on_surface_variant" })
  end
  if progress ~= nil then
    children[#children + 1] = ui.label({ text = progress, color = "on_surface_variant", fontSize = 12 })
  end
  if #children == 0 then
    return nil
  end
  return ui.row({ gap = 6, align = "center" }, children)
end

-- Labels wrap only with a maxWidth, and the host exposes no panel size to derive it from.
local PANEL_WIDTH = 1000 -- keep in sync with [[panel]] width in plugin.toml
local PANEL_PADDING = 14
local COLUMN_GAP = 12
local ADD_TILE_WIDTH = 40
local COLUMN_PADDING = 8
local SCROLLBAR_GUTTER = 14
local CARD_PADDING = 10
local TITLE_MAX_LINES = 2

local function cardTextWidth(columnCount)
  local available = PANEL_WIDTH - 2 * PANEL_PADDING - ADD_TILE_WIDTH - COLUMN_GAP * columnCount
  local columnWidth = available / math.max(columnCount, 1)
  return math.max(60, math.floor(columnWidth - 2 * COLUMN_PADDING - SCROLLBAR_GUTTER - 2 * CARD_PADDING))
end

-- The drag source fills the card, so a press anywhere drags it and a short click opens it.
-- A row is the outer node because the column stretches rows to its width.
local function taskCard(task, actions, textWidth)
  return ui.row({ key = "task-" .. task.id, fill = "surface_container/0.4", radius = 10 }, {
    ui.dragSource({
      key = "drag-" .. task.id,
      dragType = DRAG_TYPE,
      payload = task.id,
      previewAncestor = 1,
      liftFromLayout = true,
      grabCursor = false,
      flexGrow = 1,
      onClick = function()
        actions.openTask(task.id)
      end,
    }, {
      ui.column({ gap = 6, padding = 10 }, {
        ui.label({ text = task.title, maxWidth = textWidth, maxLines = TITLE_MAX_LINES }),
        taskMeta(task),
      }),
    }),
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

local function columnHeader(workspace, column, count, state, actions)
  if not isEditing(state, "column", column.id) then
    return ui.row({ key = "head-" .. column.id, align = "center", gap = 4 }, {
      ui.label({
        text = string.format("%s (%d)", column.name, count),
        fontWeight = "bold",
        color = "on_surface_variant",
        flexGrow = 1,
      }),
      ui.glyph({ name = "circle-check", size = 16, color = "primary", visible = column.closed == true }),
      ui.button({
        glyph = "pencil",
        variant = "ghost",
        tooltip = tr("board.edit_column"),
        onClick = function()
          actions.beginEdit("column", column.id)
        end,
      }),
    })
  end

  local controls = {
    ui.button({
      glyph = "chevron-left",
      variant = "ghost",
      tooltip = tr("board.move_left"),
      onClick = function()
        actions.moveColumn(column.id, -1)
      end,
    }),
    ui.button({
      glyph = "chevron-right",
      variant = "ghost",
      tooltip = tr("board.move_right"),
      onClick = function()
        actions.moveColumn(column.id, 1)
      end,
    }),
  }
  if #workspace.columns > 1 then
    local empty = count == 0 or state.force
    -- Not `enabled = false`: a disabled button ignores the pointer, so its
    -- tooltip would never show. It is dimmed and inert instead.
    controls[#controls + 1] = ui.button({
      key = "delete-column-" .. column.id .. (empty and "" or "-blocked"),
      glyph = "trash",
      variant = "ghost",
      opacity = empty and 1 or 0.4,
      tooltip = count > 0 and state.force and tr("board.delete_column_force") or (empty and tr("board.delete_column") or tr("board.delete_column_blocked")),
      onClick = function()
        if empty then
          actions.deleteColumn(column.id)
        end
      end,
    })
  end
  controls[#controls + 1] = cancelButton(actions)

  local rows = {
    ui.input({
      key = "edit-column-" .. column.id,
      value = column.name,
      focus = true,
      onSubmit = function(text)
        actions.renameColumn(column.id, text)
      end,
    }),
    ui.row({ gap = 2, align = "center" }, controls),
    -- ui.toggle has no tooltip prop, so the row carries the explanation.
    ui.row({ gap = 6, align = "center", tooltip = tr("board.closed_column_hint") }, {
      ui.label({ text = tr("board.closed_column"), color = "on_surface_variant", flexGrow = 1 }),
      ui.toggle({
        checked = column.closed == true,
        onChange = function(value)
          actions.setColumnClosed(column.id, value == "true")
        end,
      }),
    }),
  }
  return ui.column({ key = "head-edit-" .. column.id, gap = 4 }, rows)
end

local function columnView(workspace, column, state, actions)
  local tasks = Model.tasksIn(workspace, column.id)
  local textWidth = cardTextWidth(#workspace.columns)
  local cards = {}
  for i, task in ipairs(tasks) do
    cards[#cards + 1] = insertionZone(column, i)
    cards[#cards + 1] = taskCard(task, actions, textWidth)
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
    columnHeader(workspace, column, #tasks, state, actions),
    ui.scroll({ flexGrow = 1, gap = 4 }, cards),
  })
end

local function addColumnTile(state, actions)
  if state.editing ~= nil and state.editing.kind == "newColumn" then
    return ui.column({ key = "new-column", width = 170, gap = 6, padding = 8, radius = 12, fill = "surface_container/0.15" }, {
      ui.input({
        key = "new-column-input",
        placeholder = tr("board.column_placeholder"),
        focus = true,
        onSubmit = actions.addColumn,
      }),
      cancelButton(actions),
    })
  end
  return ui.column({ key = "add-column", width = 40, align = "center" }, {
    ui.button({
      glyph = "plus",
      variant = "ghost",
      tooltip = tr("board.add_column"),
      onClick = function()
        actions.beginEdit("newColumn", "")
      end,
    }),
  })
end

local function workspaceBar(index, workspace, state, actions)
  local row = {}
  for _, entry in ipairs(index.workspaces) do
    local active = entry.id == index.active
    row[#row + 1] = ui.button({
      key = "ws-" .. entry.id .. (active and "-on" or ""),
      text = entry.name,
      variant = active and "primary" or "ghost",
      onClick = function()
        actions.switchWorkspace(entry.id)
      end,
    })
  end

  if state.editing ~= nil and state.editing.kind == "newWorkspace" then
    row[#row + 1] = ui.input({
      key = "new-workspace",
      placeholder = tr("board.workspace_placeholder"),
      focus = true,
      width = 200,
      onSubmit = actions.addWorkspace,
    })
    row[#row + 1] = cancelButton(actions)
  else
    row[#row + 1] = ui.button({
      glyph = "plus",
      variant = "ghost",
      tooltip = tr("board.add_workspace"),
      onClick = function()
        actions.beginEdit("newWorkspace", "")
      end,
    })
  end

  row[#row + 1] = ui.spacer({ flexGrow = 1 })

  if isEditing(state, "workspace", workspace.id) then
    row[#row + 1] = ui.input({
      key = "edit-workspace-" .. workspace.id,
      value = workspace.name,
      focus = true,
      width = 200,
      onSubmit = actions.renameWorkspace,
    })
    row[#row + 1] = cancelButton(actions)
  else
    row[#row + 1] = ui.button({
      glyph = "pencil",
      variant = "ghost",
      tooltip = tr("board.rename_workspace"),
      onClick = function()
        actions.beginEdit("workspace", workspace.id)
      end,
    })
    if #index.workspaces > 1 then
      local empty = #workspace.tasks == 0 or state.force
      row[#row + 1] = ui.button({
        key = "delete-workspace-" .. workspace.id .. (empty and "" or "-blocked"),
        glyph = "trash",
        variant = "ghost",
        opacity = empty and 1 or 0.4,
        tooltip = #workspace.tasks > 0 and state.force and tr("board.delete_workspace_force") or (empty and tr("board.delete_workspace") or tr("board.delete_workspace_blocked")),
        onClick = function()
          if empty then
            actions.deleteWorkspace()
          end
        end,
      })
    end
  end

  return ui.row({ align = "center", gap = 4 }, row)
end

function Board.render(index, workspace, state, actions, closeButton)
  local header = {
    ui.label({ text = tr("board.title"), fontSize = 16, fontWeight = "bold", color = "on_surface", flexGrow = 1 }),
  }
  header[#header + 1] = ui.button({ glyph = "list", variant = "ghost", tooltip = tr("list.show"), onClick = actions.showList })
  header[#header + 1] = ui.button({
    glyph = "database",
    variant = "ghost",
    tooltip = tr("transfer.show"),
    onClick = actions.showTransfer,
  })
  if closeButton then
    header[#header + 1] = ui.button({ glyph = "close", variant = "ghost", onClick = actions.close })
  end

  local rows = {
    ui.row({ align = "center", gap = 8 }, header),
    workspaceBar(index, workspace, state, actions),
    -- A fresh key per submit remounts the uncontrolled input, which clears it.
    ui.input({
      key = "new-task-" .. state.inputRev,
      placeholder = tr("board.add_placeholder"),
      focus = state.editing == nil,
      onSubmit = actions.addTask,
    }),
  }

  local columns = {}
  for _, column in ipairs(workspace.columns) do
    columns[#columns + 1] = columnView(workspace, column, state, actions)
  end
  columns[#columns + 1] = addColumnTile(state, actions)
  rows[#rows + 1] = ui.row({ gap = 12, align = "stretch", flexGrow = 1 }, columns)

  return ui.column({ key = "board-root", flexGrow = 1, gap = 12 }, rows)
end

return Board
