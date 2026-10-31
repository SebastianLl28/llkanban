--!nonstrict
local Detail = require("./detail.luau")

local List = {}

local function tr(key)
  return noctalia.tr(key)
end

local function taskRow(row, showWorkspace, actions)
  local children = {
    ui.label({ text = row.task.title, flexGrow = 1 }),
    ui.label({ text = Detail.progressText(row.task) or "", color = "on_surface_variant", fontSize = 12 }),
    ui.label({ text = row.column.name, color = "on_surface_variant", width = 140 }),
  }
  if showWorkspace then
    children[#children + 1] = ui.label({ text = row.workspace.name, color = "on_surface_variant", width = 140 })
  end
  return ui.row({
    key = "list-" .. row.task.id,
    gap = 8,
    align = "center",
    padding = 8,
    fill = "surface_container/0.4",
    radius = 10,
    onClick = function()
      actions.openListedTask(row.workspace.id, row.task.id)
    end,
  }, children)
end

function List.render(rows, state, actions, closeButton)
  local header = {
    ui.label({ text = tr("list.title"), fontSize = 16, fontWeight = "bold", color = "on_surface", flexGrow = 1 }),
    ui.button({ glyph = "layout-kanban", variant = "ghost", tooltip = tr("list.show_board"), onClick = actions.showBoard }),
  }
  if closeButton then
    header[#header + 1] = ui.button({ glyph = "close", variant = "ghost", onClick = actions.close })
  end

  local rowNodes = {}
  for _, row in ipairs(rows) do
    rowNodes[#rowNodes + 1] = taskRow(row, state.allWorkspaces, actions)
  end
  if #rowNodes == 0 then
    rowNodes[1] = ui.label({ text = tr("list.empty"), color = "on_surface_variant" })
  end

  return ui.column({ key = "list-root", flexGrow = 1, gap = 12 }, {
    ui.row({ align = "center", gap = 8 }, header),
    ui.row({ align = "center", gap = 8 }, {
      -- Uncontrolled: the stable key keeps the typed text across renders.
      ui.input({
        key = "list-query",
        value = state.query,
        placeholder = tr("list.search_placeholder"),
        focus = true,
        flexGrow = 1,
        onChange = actions.setQuery,
      }),
      ui.label({ text = tr("list.all_workspaces"), color = "on_surface_variant" }),
      ui.toggle({ checked = state.allWorkspaces, onChange = actions.setAllWorkspaces }),
    }),
    ui.scroll({ flexGrow = 1, gap = 4 }, rowNodes),
  })
end

return List
