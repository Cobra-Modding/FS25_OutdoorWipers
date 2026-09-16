-- ============================================================
-- FS25_OutdoorWipers.lua
-- by Marcus (Cobra Modding)
-- 
--
-- Version 1.0.0.0
--
--
-- Keine Änderung am Skript ohne meine Erlaubnis
-- ============================================================

OutdoorWipers = {}
OutdoorWipers.CHECK_INTERVAL   = 750  
OutdoorWipers.RAY_LENGTH       = 25   
OutdoorWipers.RAY_START_OFFSET = 1.0  
OutdoorWipers.DEBUG            = false

local function owSafeCollisionFlag(name)
    local value = CollisionFlag[name]
    if value == nil then
        Logging.warning("[OutdoorWipers] CollisionFlag." .. name .. " nicht gefunden, wird ignoriert.")
        return 0
    end
    return value
end

OutdoorWipers.COLLISION_MASK = owSafeCollisionFlag("STATIC_WORLD")
                              + owSafeCollisionFlag("STATIC_OBJECT")
                              + owSafeCollisionFlag("BUILDING")
                              + owSafeCollisionFlag("TERRAIN")

if OutdoorWipers.COLLISION_MASK == 0 then
    OutdoorWipers.COLLISION_MASK = CollisionFlag.ALL_STATIC or 8388607
end

function OutdoorWipers:owRaycastCallback(actorId, x, y, z, distance, nx, ny, nz, subShapeIndex, shapeId, isLast)
    local vehicle = self

    if actorId == nil or actorId == 0 then
        return not isLast
    end

    local hitObject = g_currentMission.nodeToObject[actorId]
    if hitObject ~= nil then
        if hitObject == vehicle then
            return not isLast
        end
        if hitObject.rootVehicle ~= nil and vehicle.rootVehicle ~= nil
           and hitObject.rootVehicle == vehicle.rootVehicle then
            return not isLast
        end
    end

    vehicle.owIsIndoor = true

    if OutdoorWipers.DEBUG then
        Logging.info("[OutdoorWipers] Dach erkannt in %.2f m (Node: %s)",
                     distance, tostring(getName ~= nil and getName(actorId) or actorId))
    end

    return false
end

function OutdoorWipers.updateIndoorState(vehicle, dt)
    vehicle.owTimer = (vehicle.owTimer or 0) - dt
    if vehicle.owTimer > 0 then
        return
    end
    vehicle.owTimer = OutdoorWipers.CHECK_INTERVAL

    if vehicle.rootNode == nil or not entityExists(vehicle.rootNode) then
        return
    end

    if vehicle.owRaycastCallback == nil then
        vehicle.owRaycastCallback = OutdoorWipers.owRaycastCallback
    end

    local x, y, z = getWorldTranslation(vehicle.rootNode)

    vehicle.owIsIndoor = false
    raycastAll(x, y + OutdoorWipers.RAY_START_OFFSET, z,
               0, 1, 0,
               OutdoorWipers.RAY_LENGTH,
               "owRaycastCallback",
               vehicle,
               OutdoorWipers.COLLISION_MASK)
end

function OutdoorWipers.forceWipersOff(vehicle)
    local spec = vehicle.spec_wipers
    if spec == nil or spec.wipers == nil then
        return
    end

    for _, wiper in ipairs(spec.wipers) do
        wiper.isActive = false

        if wiper.state ~= nil then
            wiper.state = 0
        end

        if wiper.animationName ~= nil and vehicle.setAnimationTime ~= nil then
            vehicle:setAnimationTime(wiper.animationName, 0, true)
        end
    end
end

function OutdoorWipers.onUpdate(vehicle, superFunc, dt, isActiveForInput,
                                isActiveForInputIgnoreSelection, isSelected)
    if vehicle.isClient and vehicle.spec_wipers ~= nil then
        OutdoorWipers.updateIndoorState(vehicle, dt)

        if vehicle.owIsIndoor == true then
            OutdoorWipers.forceWipersOff(vehicle)
            return
        end
    end

    return superFunc(vehicle, dt, isActiveForInput,
                     isActiveForInputIgnoreSelection, isSelected)
end

local function install()
    if Wipers == nil then
        Logging.warning("[OutdoorWipers] Wipers-Spezialisierung nicht gefunden – Mod inaktiv.")
        return
    end

    if Wipers.onUpdate ~= nil then
        Wipers.onUpdate = Utils.overwrittenFunction(Wipers.onUpdate, OutdoorWipers.onUpdate)
    elseif Wipers.onUpdateTick ~= nil then
        Wipers.onUpdateTick = Utils.overwrittenFunction(Wipers.onUpdateTick, OutdoorWipers.onUpdate)
    else
        Logging.warning("[OutdoorWipers] Keine passende Update-Funktion in Wipers gefunden.")
        return
    end

    addConsoleCommand("owToggleDebug", "OutdoorWipers Debug an/aus", "consoleToggleDebug", OutdoorWipers)

    Logging.info("[OutdoorWipers] geladen.")
end

function OutdoorWipers:consoleToggleDebug()
    OutdoorWipers.DEBUG = not OutdoorWipers.DEBUG
    return "OutdoorWipers Debug: " .. tostring(OutdoorWipers.DEBUG)
end

install()
