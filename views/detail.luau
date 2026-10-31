--!nonstrict
local Model = require("../model.luau")

local Detail = {}

local function tr(key)
  return noctalia.tr(key)
end

local function isEditing(state, kind, id)
  return state.editing ~= nil and state.editing.kind == kind and state.editing.id == id
end

function Detail.progressText(task)
  local left, total = Model.subtaskProgress(task)
  if total == 0 then
    return nil
  end
  if left == 0 then
    return tr("detail.all_done")
  end
  return string.format(tr("detail.progress"), left, total)
end

local function cancelButton(actions)
  return ui.button({ glyph = "close", variant = "ghost", tooltip = tr("board.cancel"), onClick = actions.cancel })
end

local function subtaskRow(subtask, state, actions)
  if isEditing(state, "subtask", subtask.id) then
    return ui.row({ key = "subtask-" .. subtask.id .. "-edit", gap = 4, align = "center" }, {
      ui.input({
        key = "edit-subtask-" .. subtask.id,
        value = subtask.title,
        focus = true,
        flexGrow = 1,
        onSubmit = function(text)
          actions.renameSubtask(subtask.id, text)
        end,
      }),
      cancelButton(actions),
    })
  end

  return ui.row({
    key = "subtask-" .. subtask.id,
    gap = 6,
    align = "center",
    padding = 6,
    fill = "surface_container/0.4",
    radius = 10,
  }, {
    ui.toggle({
      checked = subtask.done,
      onChange = function(value)
        actions.setSubtaskDone(subtask.id, value == "true")
      end,
    }),
    ui.label({
      text = subtask.title,
      flexGrow = 1,
      color = subtask.done and "on_surface_variant" or "on_surface",
    }),
    ui.button({
      glyph = "pencil",
      variant = "ghost",
      tooltip = tr("board.rename"),
      onClick = function()
        actions.beginEdit("subtask", subtask.id)
      end,
    }),
    ui.button({
      glyph = "trash",
      variant = "ghost",
      tooltip = tr("board.delete"),
      onClick = function()
        actions.deleteSubtask(subtask.id)
      end,
    }),
  })
end

local function titleRow(task, state, actions)
  if isEditing(state, "task", task.id) then
    return ui.row({ key = "detail-title-edit", gap = 4, align = "center" }, {
      ui.input({
        key = "edit-task-" .. task.id,
        value = task.title,
        focus = true,
        flexGrow = 1,
        onSubmit = function(text)
          actions.renameTask(task.id, text)
        end,
      }),
      cancelButton(actions),
    })
  end

  return ui.row({ key = "detail-title", gap = 4, align = "center" }, {
    ui.label({ text = task.title, fontSize = 16, fontWeight = "bold", color = "on_surface", flexGrow = 1 }),
    ui.button({
      glyph = "pencil",
      variant = "ghost",
      tooltip = tr("board.rename"),
      onClick = function()
        actions.beginEdit("task", task.id)
      end,
    }),
  })
end

local function subtasksColumn(task, state, actions)
  local rows = {}
  for _, subtask in ipairs(task.subtasks) do
    rows[#rows + 1] = subtaskRow(subtask, state, actions)
  end

  return ui.column({ flexGrow = 1, gap = 12 }, {
    ui.row({ align = "center", gap = 8 }, {
      ui.label({ text = tr("detail.subtasks"), fontWeight = "bold", color = "on_surface_variant", flexGrow = 1 }),
      ui.label({ text = Detail.progressText(task) or "", color = "on_surface_variant" }),
    }),
    -- A fresh key per submit remounts the uncontrolled input, which clears it.
    ui.input({
      key = "new-subtask-" .. state.inputRev,
      placeholder = tr("detail.add_placeholder"),
      focus = state.editing == nil and state.detailFocus == "subtask",
      onSubmit = actions.addSubtask,
    }),
    ui.scroll({ flexGrow = 1, gap = 4 }, rows),
  })
end

local function descriptionColumn(task, state, actions)
  local editing = state.detailMode == "edit"
  local body
  if editing then
    body = ui.input({
      key = "detail-edit-" .. task.id,
      value = task.detail,
      multiline = true,
      focus = state.detailFocus == "description",
      flexGrow = 1,
      placeholder = tr("detail.description_placeholder"),
      onChange = actions.editDetail,
      onSubmit = actions.saveDetail,
    })
  elseif task.detail == "" then
    body = ui.label({ text = tr("detail.description_empty"), color = "on_surface_variant" })
  else
    body = ui.scroll({ flexGrow = 1 }, { ui.markdown({ text = task.detail }) })
  end

  return ui.column({ flexGrow = 2, gap = 12 }, {
    ui.row({ align = "center", gap = 8 }, {
      ui.label({ text = tr("detail.description"), fontWeight = "bold", color = "on_surface_variant", flexGrow = 1 }),
      -- Keyed by mode so the retained button is rebuilt with the new label.
      ui.button({
        key = "detail-mode-" .. state.detailMode,
        text = editing and tr("detail.preview") or tr("detail.edit"),
        variant = "ghost",
        onClick = actions.toggleDetailMode,
      }),
    }),
    body,
  })
end

function Detail.render(task, state, actions)
  local header = ui.row({ gap = 4, align = "center" }, {
    ui.button({ glyph = "chevron-left", variant = "ghost", tooltip = tr("detail.back"), onClick = actions.closeTask }),
    ui.column({ flexGrow = 1 }, { titleRow(task, state, actions) }),
  })

  return ui.column({ key = "detail-root", flexGrow = 1, gap = 12 }, {
    header,
    ui.row({ flexGrow = 1, gap = 16, align = "stretch" }, {
      subtasksColumn(task, state, actions),
      descriptionColumn(task, state, actions),
    }),
  })
end

return Detail
