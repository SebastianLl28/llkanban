--!nonstrict
local Store = {}

local INDEX_FILE = "workspaces.json"
local LEGACY_FILE = "ws_default.json"
local counter = 0

local function filePath(name)
  local dir = noctalia.pluginDataDir()
  if dir == nil then
    return nil
  end
  return dir .. "/" .. name
end

local function readJson(name)
  local path = filePath(name)
  local raw = path and noctalia.readFile(path)
  if raw == nil then
    return nil
  end
  local value = noctalia.json.decode(raw)
  if type(value) ~= "table" or value.version ~= 1 then
    return nil
  end
  return value
end

-- Write-then-rename so a shell exit mid-save never leaves half a JSON file.
local function writeJson(name, value)
  local path = filePath(name)
  local encoded = noctalia.json.encode(value, true)
  if path == nil or encoded == nil then
    return false
  end
  local tmp = path .. ".tmp"
  if not noctalia.writeFile(tmp, encoded) then
    return false
  end
  return noctalia.renameFile(tmp, path)
end

function Store.newId(prefix)
  counter += 1
  return string.format("%s_%x%x", prefix, noctalia.nowMs(), counter)
end

function Store.loadIndex()
  return readJson(INDEX_FILE)
end

function Store.saveIndex(index)
  return writeJson(INDEX_FILE, index)
end

function Store.loadWorkspace(id)
  return readJson(id .. ".json")
end

function Store.saveWorkspace(workspace)
  return writeJson(workspace.id .. ".json", workspace)
end

function Store.deleteWorkspace(id)
  local path = filePath(id .. ".json")
  return path ~= nil and noctalia.removeFile(path)
end

-- Before workspaces existed, the single board lived in ws_default.json.
function Store.adoptLegacy()
  local workspace = readJson(LEGACY_FILE)
  if workspace ~= nil and Store.saveWorkspace(workspace) then
    noctalia.removeFile(filePath(LEGACY_FILE))
    return workspace
  end
  return nil
end

return Store
