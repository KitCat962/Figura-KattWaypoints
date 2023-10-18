---@type Texture
local waypointTexture
do
    local _name = config:getName()
    config:setName("KattWaypoints")
    ---@type table<string, string>
    local configTextures = config:load("textures")
    ---@type Texture
    waypointTexture = textures:read("KattWaypoints$Waypoint", configTextures.waypoint)
    config:setName(_name)
end

local waypointName = "%s-Name"
local waypointIcon = "%s-Icon"
local waypointModel = models:newPart("KattWaypoints$GUI", "GUI")

local serverData = client.getServerData()
local serverID = serverData.ip or serverData.name

---@alias UUID string

---@class KattWaypoints.Waypoint
---@field uuid UUID
---@field name string
---@field color Vector3
---@field position Vector3
---@field dimension Minecraft.dimensionID
---@field minDistance number
---@field maxDistance number
---@field targetUUID UUID?

---@type KattWaypoints.Waypoint[]
local waypoints = {}

local function saveToConfig(server)
    local _name = config:getName()
    config:setName("KattWaypoints-Data")
    config:save(server, waypoints)
    config:setName(_name)
end

---@param uuid UUID
---@param name string
---@param color Vector3
---@param position Vector3
---@param dimension Minecraft.dimensionID
---@param targetUUID UUID?
---@param minDistance number
---@param maxDistance number
local function addWaypoint(uuid, name, color, position, dimension, targetUUID, minDistance, maxDistance)
    table.insert(waypoints, {
        uuid = uuid,
        name = name,
        color = color,
        position = position,
        dimension = dimension,
        targetUUID = targetUUID,
        minDistance = minDistance,
        maxDistance = maxDistance,
    })
    waypointModel:newText(waypointName:format(uuid))
    waypointModel:newSprite(waypointIcon:format(uuid))
end

---@param name string
---@param color Vector3?
---@param position Vector3
---@param dimension Minecraft.dimensionID
local function newStaticWaypoint(name, color, position, dimension)
    addWaypoint(
        client.intUUIDToString(
            math.random(0, 255),
            math.random(0, 255),
            math.random(0, 255),
            math.random(0, 255)
        ), --client.generateUUID()),)
        name,
        color or vec(math.random(), math.random(), math.random()),
        position,
        dimension,
        nil,
        0,
        -1
    )
    saveToConfig(serverID)
end

---@param name string
---@param color Vector3?
---@param target UUID
local function newDynamicWaypoint(name, color, target)
    local targetEntity = world.getEntity(target)
    addWaypoint(
        client.intUUIDToString(
            math.random(0, 255),
            math.random(0, 255),
            math.random(0, 255),
            math.random(0, 255)
        ), --client.generateUUID()),)
        name,
        color or vec(math.random(), math.random(), math.random()),
        targetEntity and targetEntity:getPos() or vec(0, 0, 0),
        targetEntity and targetEntity:getDimensionName() or "kattwaypoints:unknown",
        target,
        0,
        -1
    )
    saveToConfig(serverID)
end

local function swapWaypoint(index, with)
    if not (waypoints[index] and waypoints[with]) then return false end
    local temp = waypoints[index]
    waypoints[index] = waypoints[with]
    waypoints[with] = temp
    saveToConfig(serverID)
    return true
end

local function cleanUpWaypoint(index)
    local waypoint = waypoints[index]
    if not waypoint then return false end
    waypointModel
        :removeTask(waypointName:format(waypoint.uuid))
        :removeTask(waypointIcon:format(waypoint.uuid))
    table.remove(waypoints, index)
    return true
end

---Removes a waypoint by specifying it's index in the waypoints table
---Returns if the removal was successful or not
---@param index any
local function deleteWaypointIndex(index)
    local status = cleanUpWaypoint(index)
    if status then
        saveToConfig(serverID)
    end
    return status
end

---Removes a waypoint by specifying it's UUID.
---Returns if the removal was successful or not.
---@param uuid UUID
---@return boolean
local function deleteWaypointUUID(uuid)
    local index
    for i, waypoint in ipairs(waypoints) do
        if uuid == waypoint.uuid then
            index = i
            break
        end
    end
    if not index then return false end
    return deleteWaypointIndex(index)
end

local function loadFromConfig(server)
    local _name = config:getName()
    config:setName("KattWaypoints-Data")
    ---@type KattWaypoints.Waypoint[]
    local data = config:load(server)
    if not data then data = {} end
    while waypoints[1] do cleanUpWaypoint(1) end
    for i, waypoint in ipairs(data) do
        addWaypoint(
            waypoint.uuid,
            waypoint.name,
            waypoint.color or vec(1, 1, 1),
            waypoint.position,
            waypoint.dimension,
            waypoint.targetUUID,
            waypoint.minDistance or 0,
            waypoint.maxDistance or -1
        )
    end
    config:setName(_name)
end


function events.entity_init()
    function events.world_render(delta)
        for i, waypoint in ipairs(waypoints) do
            local text = waypoint.name
            local playerPos = client:getCameraPos()
            local distance = (playerPos - waypoint.position):length()
            if distance > 5 then
                text = text .. ("\n(%.1f)"):format(distance)
            end
            if waypoint.targetUUID then
                local entity = world.getEntity(waypoint.targetUUID)
                if entity then
                    waypoint.position:set(entity:getPos(delta))
                    waypoint.dimension = entity:getDimensionName()
                else
                    text = text .. "\nLast Known Location"
                end
            end
            local screen = vectors.worldToScreenSpace(waypoint.position)
            local pos = client.getScaledWindowSize() / -2 * (screen.xy + 1)
            local scale = 1
            local visible =
                screen.z > 1 and
                player:getDimensionName() == waypoint.dimension and
                distance > waypoint.minDistance and
                (waypoint.maxDistance >= 0 and distance < waypoint.maxDistance or waypoint.maxDistance < 0)
            waypointModel:getTask(waypointName:format(waypoint.uuid)) --[[@as TextTask]]
                :pos(vec(0, -10):scale(scale):add(pos).xy_)
                :scale(scale)
                :alignment("CENTER")
                :outline(true)
                :text(text)
                :visible(visible)
            waypointModel:getTask(waypointIcon:format(waypoint.uuid)) --[[@as SpriteTask]]
                :pos(waypointTexture:getDimensions():scale(0.5):scale(scale):add(pos).xy_)
                :scale(scale)
                :color(waypoint.color)
                :texture(waypointTexture)
                :visible(visible)
        end
    end
end

loadFromConfig(serverID)

nsw = function()
    newStaticWaypoint(
        ("%.2f, %.2f, %.2f"):format(player:getPos():unpack()),
        nil,
        player:getPos(),
        player:getDimensionName()
    )
end
ndw = function()
    local e = player:getTargetedEntity()
    if not e then return end
    newDynamicWaypoint(e:getName(), nil, e:getUUID())
end
p = function()
    printTable(waypoints)
end
pc = function()
    printTable(config:name("KattWaypoints-Data"):load(), 2)
end

--nsw("how", nil, player:getPos(), player:getDimensionName())
