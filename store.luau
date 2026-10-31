--!nonstrict
local Store = {}

local FILE_NAME = "ws_default.json"
local counter = 0

local function filePath(name)
  local dir = noctalia.pluginDataDir()
  if dir == nil then
    return nil
  end
  return dir .. "/" .. name
end

function Store.newId(prefix)
  counter += 1
  return string.format("%s_%x%x", prefix, noctalia.nowMs(), counter)
end

function Store.load()
  local path = filePath(FILE_NAME)
  local raw = path and noctalia.readFile(path)
  if raw == nil then
    return nil
  end
  local workspace = noctalia.json.decode(raw)
  if type(workspace) ~= "table" or workspace.version ~= 1 then
    return nil
  end
  return workspace
end

-- Write-then-rename so a shell exit mid-save never leaves half a JSON file.
function Store.save(workspace)
  local path = filePath(FILE_NAME)
  local encoded = noctalia.json.encode(workspace, true)
  if path == nil or encoded == nil then
    return false
  end
  local tmp = path .. ".tmp"
  if not noctalia.writeFile(tmp, encoded) then
    return false
  end
  return noctalia.renameFile(tmp, path)
end

return Store
