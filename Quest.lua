local _, A = ...
local titles = {}
local neededVendors = {}
local vendorItemsByName = {}
for id, item in pairs(A.vendorItems) do
    local ids = vendorItemsByName[item[1]]
    if not ids then ids = {}; vendorItemsByName[item[1]] = ids end
    ids[#ids + 1] = id
end

local function markVendors(id)
    local item = A.vendorItems[id]
    if item then
        for i = 2, #item do neededVendors[item[i]] = true end
    end
end

local function recordShoppingObjectives(questID)
    if not C_QuestLog.GetQuestObjectives then return end
    for _, objective in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
        if objective.type == "item" and not objective.finished and
            (not objective.numRequired or not objective.numFulfilled or objective.numFulfilled < objective.numRequired) then
            if objective.itemID or objective.objectID then
                markVendors(objective.itemID or objective.objectID)
            elseif objective.text then
                local name = objective.text:gsub("^%s*%d+%s*/%s*%d+%s+", ""):gsub(":?%s*%d+%s*/%s*%d+%s*$", "")
                for _, id in ipairs(vendorItemsByName[name] or {}) do markVendors(id) end
            end
        end
    end
end
local function public(v)
    return not (issecretvalue and issecretvalue(v))
end
local function clean(title)
    if not public(title) or type(title)~="string" then return nil end
    return (title:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("^%[%d+[%+%-]?%]%s*",""))
end
function A.UpdateQuestTitles()
    wipe(titles)
    wipe(neededVendors)
    local log=C_QuestLog
    local count=log and log.GetNumQuestLogEntries or GetNumQuestLogEntries
    if not count then return end
    for i=1,count() do
        local title,header,complete
        if log and log.GetInfo then
            local info=log.GetInfo(i)
            if info then
                title,header=info.title,info.isHeader
                complete=info.questID and log.IsComplete and log.IsComplete(info.questID)
                if info.questID and not header and not complete then recordShoppingObjectives(info.questID) end
            end
        elseif GetQuestLogTitle then
            local name,_,_,isHeader,_,isComplete=GetQuestLogTitle(i)
            title,header,complete=name,isHeader,isComplete
        end
        local key=clean(title)
        if key and not header and not complete then titles[key]=true end
    end
end
function A.IsQuestNPC(unit)
    if UnitIsPlayer(unit) then return false end
    if C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest then
        local ok,related=pcall(C_QuestLog.UnitIsRelatedToActiveQuest,unit)
        if ok and public(related) and related then return true end
    end
    if not next(titles) then return false end
    local data=C_TooltipInfo and C_TooltipInfo.GetUnit and C_TooltipInfo.GetUnit(unit)
    if data and public(data.lines) and (not canaccesstable or canaccesstable(data.lines)) then
        for _,line in ipairs(data.lines) do
            if public(line) and (not canaccesstable or canaccesstable(line)) and titles[clean(line.leftText)] then return true end
        end
    end
    -- Questie supplies additional Forever NPC relationships when installed.
    local module=QuestieLoader and QuestieLoader._modules and QuestieLoader._modules.QuestieTooltips
    local guid=UnitGUID(unit)
    if module and module.GetTooltip and public(guid) and guid then
        local id=select(6,strsplit("-",guid))
        if id then
            local ok,lines=pcall(module.GetTooltip,"m_"..id)
            if ok and type(lines)=="table" then
                for _,line in ipairs(lines) do
                    local title=clean(line)
                    if title and titles[(title:gsub("%s+%(%d+%)$",""))] then return true end
                end
            end
        end
    end
    return false
end
local offers, observedEnds = {}, {}
local function npcID(unit)
    local guid=UnitGUID(unit)
    if not public(guid) or not guid then return end
    local kind,_,_,_,_,id=strsplit("-",guid)
    if kind=="Creature" or kind=="Vehicle" then return tonumber(id) end
end
function A.IsQuestVendor(unit)
    local id = npcID(unit)
    return id and neededVendors[id]
end
function A.ObserveConversation(event)
    local id=npcID("npc")
    if not id then id=npcID("questnpc") end
    if not id then return end
    if event=="GOSSIP_SHOW" then
        local hasOptions
        if C_GossipInfo and C_GossipInfo.GetOptions then
            local options=C_GossipInfo.GetOptions()
            if options then hasOptions=#options>0 end
        elseif GetNumGossipOptions then
            hasOptions=GetNumGossipOptions()>0
        end
        if A.db and hasOptions~=nil then
            A.db.confirmedGossipMenus=A.db.confirmedGossipMenus or {}
            A.db.confirmedGossipMenus[id]=hasOptions
        end
        if C_GossipInfo and C_GossipInfo.GetAvailableQuests then
            offers[id]={}
            for _,q in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
                if q.questID then offers[id][q.questID]=true end
            end
        end
        if C_GossipInfo and C_GossipInfo.GetActiveQuests then
            for _,q in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
                if q.questID then observedEnds[id]=observedEnds[id] or {}; observedEnds[id][q.questID]=true end
            end
        end
    elseif GetQuestID then
        local q=GetQuestID()
        if q and q>0 then
            local records=event=="QUEST_DETAIL" and offers or observedEnds
            records[id]=records[id] or {}; records[id][q]=true
        end
    end
end
function A.NPCInteraction(unit)
    local id=npcID(unit)
    if not id or UnitCanAttack("player",unit) then return end
    local menus=A.db and A.db.confirmedGossipMenus
    local talk=menus and menus[id]
    if talk==nil then
        -- Capital direction guards with known menus on Forever.
        talk=id==3296 or id==278194 or id==5624
    end
    local log=C_QuestLog
    local function ready(q)
        return log and log.IsComplete and log.IsComplete(q) and
            (not log.GetLogIndexForQuestID or (log.GetLogIndexForQuestID(q) or 0)>0)
    end
    for _,q in ipairs(A.turnInNPCs[id] or {}) do if ready(q) then return "turnin",talk end end
    for q in pairs(observedEnds[id] or {}) do if ready(q) then return "turnin",talk end end
    local available=QuestieLoader and QuestieLoader._modules and QuestieLoader._modules.AvailableQuests
    local function offered(q)
        if log and log.GetLogIndexForQuestID and (log.GetLogIndexForQuestID(q) or 0)>0 then return false end
        return not (log and log.IsQuestFlaggedCompleted and log.IsQuestFlaggedCompleted(q))
    end
    for q in pairs(offers[id] or {}) do if offered(q) then return "offer",talk end end
    for q in pairs(available and available.__availableQuestsByNpc and available.__availableQuestsByNpc[id] or {}) do
        if offered(q) then return "offer",talk end
    end
    local function inProgress(q)
        return log and log.GetLogIndexForQuestID and (log.GetLogIndexForQuestID(q) or 0)>0
    end
    for _,q in ipairs(A.turnInNPCs[id] or {}) do
        if inProgress(q) then return "incomplete",talk end
    end
    for q in pairs(observedEnds[id] or {}) do
        if inProgress(q) then return "incomplete",talk end
    end
    -- Questie's eligibility check covers prerequisites independently of its level filter.
    local db=QuestieLoader and QuestieLoader._modules and QuestieLoader._modules.QuestieDB
    if db and db.QueryNPCSingle and db.QueryQuestSingle and db.IsDoable then
        local ok,starts=pcall(db.QueryNPCSingle,id,"questStarts")
        local level=UnitLevel("player")
        if ok and type(starts)=="table" and level and level>0 then
            for _,q in ipairs(starts) do
                local found,minimum=pcall(db.QueryQuestSingle,q,"requiredLevel")
                if found and type(minimum)=="number" and minimum>level and minimum<=level+5 and offered(q) then
                    local checked,eligible=pcall(db.IsDoable,q)
                    if checked and eligible then return "upcoming",talk end
                end
            end
        end
    end
    return nil,talk
end
