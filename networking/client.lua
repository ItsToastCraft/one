local unoClient = {}
local utils = require("libs.utils")
local base64 = require("libs.base64")

local discoveredServers = {} ---@type table<CompressedUUID, Server>
---@alias CompressedServer string Server data that is sent through pings as a byte array. It is formatted like this:
---| "serverID" 3 bytes that tell the client who is hosting the server.
---| "serverVersion" 1 byte that determines the version of the server. Newer servers might add more data.
---| "players" A compressed list of all of the players
---| "gameData" Any extra data the server might provide.



local unoServers = action_wheel:newPage()
local players = utils.getPlayers()
local uuid = avatar:getUUID() ---@type UUID
local connectedServer ---@type Server

function pings.sendJoin(info)
    local serverID, password = info:match("(...)(.*)")
    local gameHost = world.avatarVars()[utils.getPlayers()[serverID].uuid]
    if gameHost.UNO and gameHost.UNO.server then
        gameHost.UNO.server.connect(uuid, password)
    end
end


---comment
---@param server Server
local function addToWheel(server)
    if not host:isHost() then return end
    if #unoServers:getActions() > 7 then return end
    server.index = discoveredServers[server.serverID].index or #unoServers:getActions() + 1
    unoServers:newAction(server.index)
    :title(("%s's Server\nNeeds Password: %s\n Player Count: %i/%i"):format(server.owner, tostring(server.needsPassword), utils.count(server.game.currentPlayers) + 1, server.maxPlayers))
    :item(("minecraft:player_head[minecraft:profile=%s]"):format(server.owner))
    :onLeftClick(function() 
        if server.needsPassword then
            print("This server requires a password! Please enter it into the chat.")
            events.CHAT_SEND_MESSAGE:register(function(msg)
                print(utils.compressUUID(uuid), "awawa")
                pings.sendJoin(utils.compressUUID(server.serverID)..utils.xor(msg, utils.compressUUID(uuid)))
                events.CHAT_SEND_MESSAGE:remove("uno.listen")
                return nil
            end, "uno.listen")
        else
            pings.sendJoin(utils.compressUUID(server.serverID))
        end
    end)
end
action_wheel:setPage(unoServers)


---Adds a server to the discovery list.
---@param serverInfo CompressedServer
function unoClient.discover(serverInfo)
    local owner, version, serverData, compressedPlayers, extra = serverInfo:match("(...)(.)(.)%d(.*)(.*)")
    version, serverData = version:byte(), serverData:byte()
    local playerList = {}
    if #compressedPlayers > 2 then
        for i = 1, #compressedPlayers, 3 do
            local chunk = string.sub(compressedPlayers, i, i + 2)
            
            local player = players[utils.decompressID(chunk)]
            playerList[player.uuid] = {name = player.name}
        end
    end
    
    local index
    if not discoveredServers[owner] then
        printJson(toJson({{text ="[uno] ", color = "red"},{text = players[owner].name .. " is hosting a game! Check your action wheel.\n", color = "white"}}))
    else 
        index = discoveredServers[owner].index
    end
    local serverID = utils.decompressID(owner)
    discoveredServers[serverID] = {
        owner = players[owner].name,
        serverID = serverID,
        version = bit32.rshift(version, 4) + (bit32.band(version, 0x0F) * 0.1),
        needsPassword = bit32.band(serverData, 0x08) ~= 0,
        maxPlayers = bit32.band(serverData, 0x07) + 1,
        index = index,
        game = {
            currentPlayers = playerList,
        }
    }
    
    addToWheel(discoveredServers[serverID])
end
---Will try to check with the client before continuing.
---@param server any
---@param amount any
function pings.tryDraw(server, amount)
    local gameHost = world.avatarVars()[utils.getPlayers()[server].uuid]
    if gameHost.UNO and gameHost.UNO.server then
        gameHost.UNO.server.requestDraw(uuid, amount)
    end
end
---Not meant to be called by clients, will mess stuff up.
function unoClient.draw()
    if not connectedServer then return end
    pings.tryDraw(utils.compressUUID(connectedServer.serverID), 20)
end

function unoClient.success(cards)
    print(cards)
end

function unoClient.recieveAuth(server, key)
    connectedServer = discoveredServers[server]
    connectedServer.game.currentPlayers[uuid] = {name = avatar:getEntityName(), offset = tonumber(utils.decompressID(utils.xor(key, utils.compressUUID(uuid))),16), cards = {}}
end


action_wheel:getCurrentPage():newAction(7):title("start game"):setOnLeftClick(unoClient.draw)

avatar:store("UNO", {client = unoClient})