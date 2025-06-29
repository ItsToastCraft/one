local utils = require "libs.utils"
---@alias UUID string A 36 character string (32 without dashes) that represents a player.
---@alias CompressedUUID string a 6 character string (looks like a hex code)
---@alias ServerID string a 6 character string taken from the first 6 characters of the owner's UUID

---@class GameRules
---@field keepDraw boolean Determines whether the player should keep drawing if they can't play a card.
---@field rotateWithZero boolean Determines whether players cards all rotate if there is a zero played.
---@field swapWithSeven boolean Determines whether players can swap cards if someone plays a seven. 
---@field jumpIn boolean Determines whether players can place a card that matches the one currently on the board.

---@class GameSession
---@field turn? UUID The player that is currently supposed to play a card.
---@field currentPlayers table<UUID, table> A table of the current players, stores important information like cards and offset. 
---@field rules? GameRules The rules set in place for the session.

---@class Server
---@field owner string Owner of the server
---@field serverID ServerID The first 6 characters of the owner's UUID
---@field version number Server Version (latest official is 0.1)
---@field needsPassword boolean Checks if the server needs a password
---@field password? string The password saved on the server.
---@field maxPlayers integer The number of players allowed on this server (max 8)
---@field connect? fun(self: Server, password: string) Function that is called when clients want to establish connection.
---@field index? integer Location on action wheel
---@field game? GameSession Active game session.
local server = {version = 0.1}
server.__index = server


local hosted ---@type Server

---(SERVER) Adds a player 
---@param auth any
function pings.addPlayer(auth)
    local uuid, key = auth:match("(...)(...)")
    
    local addedPlayer = utils.getPlayers()[uuid]
    hosted.game.currentPlayers[addedPlayer.uuid] = {}
    world.avatarVars()[addedPlayer.uuid].UNO.client.recieveAuth(hosted.serverID, key)
    if host:isHost() then
        hosted.game.currentPlayers[addedPlayer.uuid] = {name = addedPlayer.name, offset = tonumber(utils.decompressID(utils.xor(key, uuid)),16), cards = {}}
    end
        
    pings.broadcast(hosted:pack())
end

---(SERVER) Tries connecting to the server - called by clients
---@param uuid UUID
---@param password string
function server.connect(uuid,password)
    print("trying to connect")
    if not hosted then return end
    local key = math.random(16777215)

    local success = utils.compressUUID(uuid)..utils.xor(utils.compressUUID(string.format("%x", key)), utils.compressUUID(uuid))
    if hosted.needsPassword then 
        password = utils.xor(password, utils.compressUUID(uuid))
        if password ~= hosted.password then
            print("Incorrect password", uuid)
        else
            pings.addPlayer(success)
        end
    else
        pings.addPlayer(success)
    end
end

---(SERVER) tells other clients that there is a server available.
---@param data string
function pings.broadcast(data)
    if host:isHost() then return end
    local vars = utils.deepCopy(player:getVariable("UNO"))
    vars.server = {
        connect = hosted.connect,
        requestDraw = hosted.requestDraw
            }
 
    avatar:store("UNO",vars)
    for _, var in pairs(world.avatarVars()) do
        if var.UNO and var.UNO.client then
            var.UNO.client.discover(data)
        end
    end
end

---(SERVER) Compresses the server data to send to other clients.
---@return string
function server:pack()
    local gameData =
        bit32.lshift((#self.game.currentPlayers - 1) % 8, 4) +
        bit32.lshift((self.password and 1 or 0), 3) + 
        ((self.maxPlayers - 1) % 8)
    local rules = bit32.lshift(self.game.rules.jumpIn and 1 or 0, 3) + bit32.lshift(self.game.rules.keepDraw and 1 or 0, 2) + bit32.lshift(self.game.rules.rotateWithZero and 1 or 0, 1) + (self.game.rules.swapWithSeven and 1 or 0)
    local playerList = ""
    for uuid, _ in pairs(self.game.currentPlayers) do
        if uuid ~= world.getPlayers()[self.owner]:getUUID() then 
            playerList = playerList .. utils.compressUUID(uuid)
        end
    end
    return utils.compressUUID(self.serverID) .. string.char(self.version, gameData) .. ("%d%s"):format(#playerList / 3, playerList) .. rules
end

local t = 0

---(SERVER) Creates a server.
---@param maxPlayers integer Max 8
---@param password? string Password. If none is present, skips password check.
---@param version? string The server version, defines structure? Current is 0.1, max is 15.15
---@param rules? GameRules
---@return Server?
function server.createServer(maxPlayers, password, version, rules)
    if hosted then return end
    version = version or tostring(server.version)
    local majorVersion, minorVersion = version:match("(%d)%.(%d)")
    minorVersion = math.min(15, minorVersion)
    local self = setmetatable({
        version = bit32.bor(bit32.lshift(tonumber(majorVersion), 4), tonumber(minorVersion)),
        serverID = avatar:getUUID():sub(1,6),
        owner = avatar:getEntityName(),
        game = {
            currentPlayers = {[avatar:getUUID()] = {name = avatar:getEntityName(), offset = math.random(16777215)}}, rules = rules or {},
            turn = avatar:getUUID()
                },
        maxPlayers = maxPlayers and math.min(maxPlayers, 8) or 4,
        password = password,
        needsPassword = not not password,
    }, server)

    pings.broadcast(self:pack())
    events.WORLD_TICK:register(function() 
        t = t + 1 % 200
        if not t then
            pings.broadcast(self:pack())
        end
        if self.maxPlayers == utils.count(self.game.currentPlayers) then
            print("Ending broadcast, max players reached.")
            events.tick:remove("broadcast")
        end
    end, "broadcast")
    return self
end

---Validates if a player is able to draw a card. 
---@param uuid UUID
---@param amount number
---@return integer
function server.requestDraw(uuid, amount)
    local self = hosted
    if self.game.turn == uuid then
        
        local player = self.game.currentPlayers[uuid]
        math.randomseed(player.offset)
        local addedCards = {}
        for _ = 0, amount do
            player.cards[#player.cards+1] = math.random(1, 108)
            addedCards[#addedCards+1] = string.char(player.cards[#player.cards])
        end
        world.avatarVars()[uuid].UNO.client.success(table.concat(addedCards))
        return #player.cards
    end
    return -1
end

function server:start()
    for uuid, player in pairs(self.game.currentPlayers) do
        
    end
end

-- --- Just creates a testing server
function events.entity_init()
    hosted = server.createServer(2, "password")
    action_wheel:getCurrentPage():newAction(8):title("start game"):setOnLeftClick(hosted.start)
end

-- return server