---@alias UUID string A 36 character string (32 without dashes) that represents a player.
---@alias CompressedUUID string a 6 character string (looks like a hex code)
---@alias ServerID string a 6 character string taken from the first 6 characters of the owner's UUID

---@class Server
---@field owner {name: string, uuid: UUID} Owner of the server
---@field serverID ServerID The first 6 characters of the owner's UUID
---@field version number Server Version (latest official is 0.1)
---@field needsPassword boolean Checks if the server needs a password
---@field password? string The password saved on the server.
---@field currentPlayers table<UUID, table> A table of the current players, stores important information like cards and offset. 
---@field maxPlayers integer The number of players allowed on this server (max 8)
---@field connect fun(self: Server, password: string) Function that is called when clients want to establish connection.
---@field id? integer Location on action wheel
local server = {version = 0.1}
server.__index = server

local foundServers = {}
---@type Server
local hosted
local id = 0
local base64 = require("libs.base64")

local unoServers = action_wheel:newPage()
unoServers:newAction():setItem("minecraft:player_head[minecraft:profile=ItsToastCraft,minecraft:custom_data={type:server}]")
unoServers:newAction():setItem("minecraft:player_head[minecraft:profile=ItsToastCraft,minecraft:custom_data={type:player}]")
unoServers:newAction():setItem("minecraft:player_head[minecraft:profile=ItsToastCraft,minecraft:custom_data={type:gear}]")
---Takes the first 6 characters of the UUID and turns them into a 3 byte string
---@param uuid CompressedUUID
---@return string
local function compressID(uuid)
    if #uuid ~= 6 then return uuid end
    local newID = tonumber(uuid, 16)
    local b1 = bit32.rshift(newID, 16)
    local b2 = bit32.band(bit32.rshift(newID, 8), 0xFF)
    local b3 = bit32.band(newID, 0xFF) 
    return string.char(b1, b2, b3)
end

---Decompresses 3 characters into a 6 character CompressedUUID
---@param uuid string
---@return CompressedUUID
local function decompressID(uuid)
    return ("%x"):format(uuid:byte() * 0x10000 + uuid:byte(2)  * 0x100 + uuid:byte(3))
end

---Basically just finds the player that the compressed UUID belongs to
---@param uuid CompressedUUID
---@return UUID
local function decode(uuid)
    for _, player in pairs(world.getPlayers()) do
        if player:getUUID():gsub("-",""):find("^"..uuid) then
            return player:getUUID()
        end
    end
    return ""
end

--- GET PASSWORD ---
local waiting = false
local pass = ""
function events.CHAT_SEND_MESSAGE(msg)
    if waiting then
        pass = msg
        return nil
    end
    return msg
end
--- Just counts how many pairs are in a table
---@param tbl table
---@return integer
local function count(tbl)
    local n = 0
    for _ in pairs(tbl) do
        n = n + 1
    end
    return n
end

---(CLIENT) Tries to send a connect packet to the server.
---@param serverID CompressedUUID
---@param password? string
function pings.tryJoin(serverID, password)
    serverID = decompressID(serverID)

    local connecting = world.avatarVars()[decode(serverID)]
    if connecting and connecting.UNO and connecting.UNO.server and connecting.UNO.server.owner.uuid == decode(serverID) then
        connecting.UNO.server.connect(avatar:getUUID(), password)
    end
end

---(SERVER) Adds a player 
---@param auth any
function pings.addPlayer(auth)
    local uuid, key, rand = auth:match("␆(...)(...)(%d)")
    
    hosted.currentPlayers[decode(decompressID(uuid))] = {offset = key, startRand = rand}
    if count(hosted.currentPlayers) ~= hosted.maxPlayers then
        pings.broadcast(hosted:pack())
    end
end

---(SERVER) Tries connecting to the server - called by clients
---@param uuid UUID
---@param password string
function server.connect(uuid,password)
    if not hosted then return end
    password = base64.decode(password)
    if hosted.needsPassword then 
        if password ~= hosted.password then 
            print("Incorrect password", uuid)
        else
            local key = math.random(16777215)
            pings.addPlayer("␆"..compressID(uuid:sub(1,6))..compressID(string.format("%x", key)) ..math.random(8))
        end
    else
        local key = math.random(16777215)
        pings.addPlayer("␆"..compressID(uuid:sub(1,6))..compressID(string.format("%x", key)) ..math.random(8))
    end
end


---(CLIENT) Registers a game to the action wheel.
---@param data Server
local function addGame(data)
    if not data.serverID or not data.owner or not data.currentPlayers then return end
    if not world.avatarVars()[data.owner.uuid].UNO then return end 
    if #unoServers:getActions() > 7 then return end
    if host:isHost() then 
        if (foundServers[data.serverID]) then
            ---@type Server
            local serv = foundServers[data.serverID]
            print("Already registered, updating...")
            unoServers:getAction(serv.id):setTitle("     " ..data.owner.name .. "'s Server     \nPassword Needed: " .. tostring(data.needsPassword) .. ("\nPlayer Count : %d/%d "):format(count(data.currentPlayers), data.maxPlayers))
            data.id = serv.id
            serv = data
        else
        
        id = id + 1
        printJson(toJson({{text ="[uno] ", color = "red"},{text = data.owner.name .. " is hosting a game! Check your action wheel.\n", color = "white"}}))
        
        data.id = id
        
        foundServers[data.serverID] = data
        unoServers:newAction(id)
        :setTitle("     " ..data.owner.name .. "'s Server     \nPassword Needed: " .. tostring(data.needsPassword) .. ("\nPlayer Count : %d/%d "):format(count(data.currentPlayers), data.maxPlayers))
        :setItem(("minecraft:player_head[profile=%s]"):format(data.owner.name))
        :setOnLeftClick(function()
            if data.needsPassword then
                print("This game requires a password! Enter the password into chat")
                waiting = true
                host:setChatColor(vectors.hexToRGB("f5c029"))
                events.tick:register(function ()
                    if pass ~= "" then
                        
                        pings.tryJoin(compressID(data.serverID), base64.encode(pass))
                        pass = ""
                        events.tick:remove("waitForPassword")
                        host:setChatColor(vec(1,1,1))
                        waiting = false
                    end
                end, "waitForPassword")
            else 
                pings.tryJoin(compressID(data.serverID))
            end
        end)
        end
    end
end

local storedData = {addGame = addGame}

action_wheel:setPage(unoServers)
avatar:store("UNO", storedData)

---(SERVER) tells other clients that there is a server available.
---@param data string
function pings.broadcast(data)
    if host:isHost() then return end
    for uuid, var in pairs(world.avatarVars()) do
        if var.UNO then
            local owner, version, serverData, players, extra = data:match("░(...)(.)(.)␝(.*)␝(.*)")
            
            owner = decompressID(owner)
            local playerList = {}
            for player in players:gmatch("...") do
                playerList[decompressID(player)] = {}
            end
            
            version, serverData = version:byte(), serverData:byte()
            version = bit32.rshift(version, 4) + (bit32.band(version, 0x0F) * 0.1)
            
            for name, _player in pairs(world.getPlayers()) do
                
                if _player:getUUID():find("^"..owner) and uuid ~= _player:getUUID() then
                    playerList[_player:getUUID()] = {}
                    ---@type Server
                    local found = setmetatable({
                        serverID = owner,
                        owner = {name = name, uuid = _player:getUUID()},
                        version =  version,
                        needsPassword = bit32.band(serverData, 0x08) ~= 0,
                        currentPlayers = playerList,
                        maxPlayers = bit32.band(serverData, 0x07) + 1,
                        connect = server.connect
                    }, server)
                    if tostring(found.version) ~= server.version then 
                        --print(("Server provided different version (%d), while this script is on (%d)! Compatibility might be limited."):format(found.version, server.version))
                    end

                    storedData.server = found
                    foundServers[owner] = found
                    avatar:store("UNO", storedData)
                    var.UNO.addGame(found)
                    break
                end
            end
        end
    end
end

---(SERVER) Compresses the server data to send to other clients.
---@return string
function server:pack()
    local gameData =
        bit32.lshift((#self.currentPlayers - 1) % 8, 4) +
        bit32.lshift((self.password and 1 or 0), 3) + 
        ((self.maxPlayers - 1) % 8)

    local playerList = ""
    for uuid, _ in pairs(self.currentPlayers) do
        if uuid ~= self.owner.uuid then 
        playerList = playerList .. compressID(uuid:sub(1,6))
        end
    end
    return "░" .. compressID(self.serverID) .. string.char(self.version, gameData) .. ("␝%s␝"):format(playerList)
end
local t = 0

---(SERVER) Creates a server.
---@param maxPlayers integer Max 8
---@param password? string Password. If none is present, skips password check.
---@param version? string The server version, defines structure? Current is 0.1, max is 15.15
---@return Server?
function server.createServer(maxPlayers, password, version)
    if hosted then return end
    version = version or tostring(server.version)
    local majorVersion, minorVersion = version:match("(%d)%.(%d)")
    minorVersion = math.min(15, minorVersion)
    local self = setmetatable({
        version = bit32.bor(bit32.lshift(tonumber(majorVersion), 4), tonumber(minorVersion)),
        serverID = avatar:getUUID():sub(1,6),
        owner = {name = avatar:getEntityName(), uuid = avatar:getUUID()},
        currentPlayers = {[avatar:getUUID()] = {}},
        maxPlayers = maxPlayers and math.min(maxPlayers, 8) or 4,
        password = password,
        needsPassword = not not password,
        connect = server.connect
    }, server)

    storedData.server = self
    avatar:store("UNO", storedData)
    pings.broadcast(self:pack())
    events.tick:register(function() 
        t = t + 1
        if t % 200 == 0 then
            pings.broadcast(self:pack())
        end
        if self.maxPlayers == count(self.currentPlayers) then
            print("Ending broadcast, max players reached.")
            events.tick:remove("broadcast")
        end
    end, "broadcast")
    return self
end

--- Just creates a testing server
function events.entity_init()
    hosted = server.createServer(2, "password")
end

return server