--!nonstrict
local TransferView = {}

local function tr(key)
  return noctalia.tr(key)
end

function TransferView.render(state, actions, closeButton)
  local header = {
    ui.label({ text = tr("transfer.title"), fontSize = 16, fontWeight = "bold", color = "on_surface", flexGrow = 1 }),
    ui.button({ glyph = "layout-kanban", variant = "ghost", tooltip = tr("list.show_board"), onClick = actions.showBoard }),
  }
  if closeButton then
    header[#header + 1] = ui.button({ glyph = "close", variant = "ghost", onClick = actions.close })
  end

  local rows = {
    ui.row({ align = "center", gap = 8 }, header),
    ui.label({ text = tr("transfer.hint"), color = "on_surface_variant" }),
    ui.row({ align = "center", gap = 8 }, {
      -- Uncontrolled: the stable key keeps the typed path across renders.
      ui.input({
        key = "transfer-path",
        value = state.transferPath,
        placeholder = tr("transfer.path_placeholder"),
        flexGrow = 1,
        onChange = actions.setTransferPath,
      }),
      ui.button({ glyph = "file-export", text = tr("transfer.export"), variant = "primary", onClick = actions.exportData }),
      ui.button({ glyph = "file-import", text = tr("transfer.import"), variant = "outline", onClick = actions.importData }),
    }),
  }
  if state.transferStatus ~= nil then
    rows[#rows + 1] = ui.label({
      text = state.transferStatus.text,
      color = state.transferStatus.failed and "error" or "primary",
    })
  end

  local confirmed = state.wipeConfirmed
  rows[#rows + 1] = ui.separator()
  rows[#rows + 1] = ui.label({ text = tr("transfer.wipe_title"), fontWeight = "bold", color = "on_surface" })
  rows[#rows + 1] = ui.label({ text = tr("transfer.wipe_hint"), color = "on_surface_variant" })
  rows[#rows + 1] = ui.row({ align = "center", gap = 8 }, {
    -- A fresh key after a wipe remounts the uncontrolled input, which clears it.
    ui.input({
      key = "wipe-confirm-" .. state.inputRev,
      placeholder = tr("transfer.wipe_placeholder"),
      flexGrow = 1,
      onChange = actions.setWipeConfirm,
    }),
    ui.button({
      key = "wipe" .. (confirmed and "" or "-locked"),
      glyph = "trash",
      text = tr("transfer.wipe"),
      variant = "destructive",
      enabled = confirmed,
      onClick = actions.wipeAll,
    }),
  })

  return ui.column({ key = "transfer-root", flexGrow = 1, gap = 12 }, rows)
end

return TransferView
