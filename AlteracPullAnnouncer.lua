local addonName, addon = ... -- all lua files linked in the .toc of an addon get passed the addon name
-- and a table scoped to that specific addon by the wow client.
-- That table can be used to pass variables and methods around in the addon without putting them
-- in the global namespace and risking collisions with other addons or Blizzard UI code.
local start
local isPulled = false

local PULL_ACTION = ""
local PULL_BODY = "body-"

local MELEE = "MELEE"

local frame = CreateFrame("FRAME") -- don't need the frame to be named to receive events
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("UNIT_TARGET")
frame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
frame.OnEvent = function(self, event, ...)
    return addon[event] and addon[event](addon, ...)
end
frame:SetScript("OnEvent", frame.OnEvent)

function addon:UPDATE_BATTLEFIELD_STATUS(...)
    if GetBattlefieldWinner() then
        isPulled = false
        start = nil
        -- debug
        DEFAULT_CHAT_FRAME:AddMessage("left bg, setting pull to false")
    end
end

local nonCombatSpells = {
    [(GetSpellInfo(2096))] = true, -- mind vision
    [(GetSpellInfo(1130))] = true, -- hunter's mark
    [(GetSpellInfo(2855))] = true, -- detect magic
    [(GetSpellInfo(1725))] = true, -- distract
    [(GetSpellInfo(1543))] = true, -- flare
}
local subEvents = {
    ["SPELL_DAMAGE"] = true,
    ["SPELL_MISSED"] = true,
    ["SWING_DAMAGE"] = true,
    ["SWING_MISSED"] = true,
    ["RANGE_DAMAGE"] = true,
    ["RANGE_MISSED"] = true,
}
local NPCids = {-- strings are truthy in Lua
    -- npc ids are numbers but this saves us tonumber() calls later when we extract the id as a string
    ["11946"] = "Drek'Thar",
    ["14770"] = "Dun Baldar North Warmaster",
    ["14771"] = "Dun Baldar South Warmaster",
    ["14772"] = "East Frostwolf Warmaster",
    ["14773"] = "Iceblood Warmaster",
    ["14774"] = "Icewing Warmaster",
    ["14775"] = "Stonehearth Warmaster",
    ["14776"] = "Tower Point Warmaster",
    ["14777"] = "West Frostwolf Warmaster",
    ["11948"] = "Vanndar Stormpike",
    ["14762"] = "Dun Baldar North Marshal",
    ["14763"] = "Dun Baldar South Marshal",
    ["14764"] = "Icewing Marshal",
    ["14765"] = "Stonehearth Marshal",
    ["14766"] = "Iceblood Marshal",
    ["14767"] = "Tower Point Marshal",
    ["14768"] = "East Frostwolf Marshal",
    ["14769"] = "West Frostwolf Marshal",
}
function addon:COMBAT_LOG_EVENT_UNFILTERED(...)

    local battelfieldRunTime = GetBattlefieldInstanceRunTime()

    -- Do not do anything if not in BattleGround
    if not battelfieldRunTime or battelfieldRunTime <= 0 then
        return
    end

    if not subEvents[subevent] then return end

    -- assignment is cheap, function calls not, select() included, we call CombatLogGetCurrentEventInfo after we pass the trivial tests
    local timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19, arg20, arg21, arg22, arg23, arg24 = CombatLogGetCurrentEventInfo()

    local dstUnitType,_,_,_,_, dstID = strsplit("-", destGUID)
    local srcUnitType,_,_,_,_, srcID = strsplit("-", sourceGUID)

    if dstUnitType == "Creature" and NPCids[dstID] then -- boss or guard getting attacked
        if not isPulled then
            if strfind(subevent, "^SPELL") or strfind(subevent, "^RANGE") then -- ^ anchors the search term at the start
                local spellId, spellName = arg12, arg13 -- use spellName so we don't have to list all rank spellids
                if not nonCombatSpells[spellName] then
                    addon:pullAnnounce(destName, sourceName, PULL_ACTION, spellName)
                end
            elseif strfind(subevent, "^SWING") then -- melee
                addon:pullAnnounce(destName, sourceName, PULL_ACTION, MELEE)
            end
        end
    end

    if srcUnitType == "Creature" and NPCids[srcID] then -- boss or guard attacking
        if not isPulled then
            if strfind(subevent, "^SPELL") or strfind(subevent, "^RANGE") then
                local spellId, spellName = arg12, arg13
                addon:pullAnnounce(sourceName, destName, PULL_BODY, spellName)
            elseif strfind(subevent, "^SWING") then
                addon:pullAnnounce(sourceName, destName, PULL_BODY, MELEE)
            end
        end
    end
end

function addon:UNIT_TARGET(...)

end

function addon:pullAnnounce(pullee, puller, pullType, pullAction) -- function doesn't need to be a global
    isPulled = true
    start = GetTime()

    local msg = pullee .. " ".. pullType .."pulled by " .. puller

    if pullType == PULL_BODY then
        msg = msg .. " and got hit with " .. pullAction .. "."
    else
        msg = msg .. " with " .. pullAction .. "."
    end

    DEFAULT_CHAT_FRAME:AddMessage(msg)
    SendChatMessage(msg, "SAY", nil, 0)
end
