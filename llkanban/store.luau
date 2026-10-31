--!nonstrict
local Model = require("./model.luau")

local Store = {}

local INDEX_VERSION = 1
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
  return type(value) == "table" and value or nil
end

-- Old versions are upgraded in memory and written back on the next save.
local function readWorkspace(name)
  local workspace = readJson(name)
  if workspace == nil then
    return nil
  end
  Model.upgradeWorkspace(workspace)
  return workspace.version == Model.WORKSPACE_VERSION and workspace or nil
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
  local index = readJson(INDEX_FILE)
  return index ~= nil and index.version == INDEX_VERSION and index or nil
end

function Store.saveIndex(index)
  return writeJson(INDEX_FILE, index)
end

function Store.loadWorkspace(id)
  return readWorkspace(id .. ".json")
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
  local workspace = readWorkspace(LEGACY_FILE)
  if workspace ~= nil and Store.saveWorkspace(workspace) then
    noctalia.removeFile(filePath(LEGACY_FILE))
    return workspace
  end
  return nil
end

return Store
