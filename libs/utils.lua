local utils = {}
local players = {}

---Takes the first 6 characters of the UUID and turns them into a 3 byte string
---@param uuid CompressedUUID
---@return string
function utils.compressUUID(uuid)
    print(uuid)
    if #uuid ~= 6 then uuid = uuid:sub(1,6) end
    local newID = tonumber(uuid, 16)
    local b1 = bit32.rshift(newID, 16)
    local b2 = bit32.band(bit32.rshift(newID, 8), 0xFF)
    local b3 = bit32.band(newID, 0xFF)
    return string.char(b1, b2, b3)
end

function utils.count(tbl)
    local count = 0
    for _ in pairs(tbl) do 
        count = count + 1 
    end
  return count
end
-- Recursively copies a table (thanks 4P5)
---@param orig table The original table to copy.
---@return table copy A copy of the table.
function utils.deepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = utils.deepCopy(v)
    end
    return copy
end

function utils.xor(str, key)
    local result = {}
    for i = 1, #str do
        local inputByte = str:byte(i)
        local keyByte = key:byte((i - 1) % #key + 1)
        result[i] = string.char(bit32.bxor(inputByte, keyByte))
    end
    return table.concat(result)
end

local function createPlayerList()
    for _, player in pairs(world.getPlayers()) do
        players[utils.compressUUID(player:getUUID())] = {uuid = player:getUUID(), name = player:getName(), player = player}
    end
end
createPlayerList()


function utils.getPlayers()
    return players
end

---Decompresses 3 characters into a 6 character CompressedUUID
---@param uuid string
---@return CompressedUUID
function utils.decompressID(uuid)
    return ("%x"):format(uuid:byte() * 0x10000 + uuid:byte(2)  * 0x100 + uuid:byte(3))
end

return utils