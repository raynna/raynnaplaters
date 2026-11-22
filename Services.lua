local _, A = ...
local sprites = {
    trainer="Trainer", vendor="Vendor", bank="Banker", flight="Taxi",
    inn="Binder", stable="StableMaster", auction="Auctioneer",
}
local tracking={flight="FlightMaster", inn="Innkeeper", bank="Banker", auction="Auctioneer", stable="StableMaster"}
local labels={flight="Flight Master", inn="Innkeeper", bank="Banker", auction="Auctioneer", stable="Stable Master"}
local words = {
    {"trainer","trainer"},
    {"banker","bank"},
    {"auctioneer","auction"}, {"innkeeper","inn"}, {"stable master","stable"},
    {"flight master","flight"}, {"wind rider master","flight"}, {"gryphon master","flight"},
    {"hippogryph master","flight"}, {"bat handler","flight"}, {"dragonhawk master","flight"},
    {"vendor","vendor"}, {"merchant","vendor"}, {"supplies","vendor"}, {"goods","vendor"},
}
function A.ServiceRole(unit)
    if UnitIsPlayer(unit) or UnitCanAttack("player",unit) then return end
    local guid=UnitGUID(unit)
    if (issecretvalue and issecretvalue(guid)) or not guid then return end
    local kind,_,_,_,_,id=strsplit("-",guid)
    if kind~="Creature" and kind~="Vehicle" then return end
    local entry=A.serviceNPCs[tonumber(id)]
    local role,title
    if entry then role,title=entry[1],entry[2] end
    local data=C_TooltipInfo and C_TooltipInfo.GetUnit and C_TooltipInfo.GetUnit(unit)
    local lines=data and data.lines
    local line=lines and (not canaccesstable or canaccesstable(lines)) and lines[2]
    local subtitle=line and (not canaccesstable or canaccesstable(line)) and line.leftText
    if not (issecretvalue and issecretvalue(subtitle)) and type(subtitle)=="string" then
        subtitle=subtitle:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("^<(.+)>$","%1")
        for _,pair in ipairs(words) do
            if subtitle:lower():find(pair[1],1,true) then
                if pair[2]~="vendor" or not role or role=="vendor" then role,title=pair[2],subtitle end
                break
            end
        end
    end
    local service=A.townServices[tonumber(id)]
    if service and service~=role then role,title=service,labels[service] end
    if tracking[role] then return title,"Interface\\Minimap\\Tracking\\"..tracking[role],role end
    if (not role or role=="vendor") and (A.repairNPCs[tonumber(id)] or
        (role=="vendor" and title and (title:lower():find("weaponsmith",1,true) or title:lower():find("armorsmith",1,true)))) then
        return title or "Repairs","Interface\\Minimap\\Tracking\\Repair","repair"
    end
    if role then return title,"Interface\\GossipFrame\\"..sprites[role].."GossipIcon",role end
end
