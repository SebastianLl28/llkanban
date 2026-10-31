--!nonstrict
local Model = require("./model.luau")
local Store = require("./store.luau")

local function tr(key)
  return noctalia.tr(key)
end

local function refresh()
  local index = Store.loadIndex()
  local total = 0
  local rows = {}
  for _, entry in ipairs(index and index.workspaces or {}) do
    local workspace = Store.loadWorkspace(entry.id)
    if workspace ~= nil then
      local pending = Model.pendingCount(workspace)
      total += pending
      rows[#rows + 1] = { key = workspace.name, value = tostring(pending) }
    end
  end

  table.insert(rows, 1, { key = tr("widget.title"), value = string.format(tr("widget.pending"), total) })
  barWidget.setText(total > 0 and tostring(total) or "")
  barWidget.setTooltip(rows)
end

function onClick()
  noctalia.togglePanel("sebastianll28/llkanban:board")
end

barWidget.setGlyph("layout-kanban")
-- The panel runs in another VM; it bumps data_rev after each save.
noctalia.state.watch("data_rev", refresh)
refresh()
