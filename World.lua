local _, A = ...
local active, pool = {}, {}
local function readable(v)
    return not (issecretvalue and issecretvalue(v))
end
local function text(parent, size, role)
    local f = parent:CreateFontString(nil, "OVERLAY")
    f.rnpRole=role
    A.SetPlateFont(f, size)
    return f
end
local function bar(parent, height)
    local f = CreateFrame("StatusBar", nil, parent)
    f:SetSize(162, height)
    f:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", -1, 1)
    bg:SetPoint("BOTTOMRIGHT", 1, -1)
    bg:SetColorTexture(.07,.07,.08,.96)
    return f
end
function A.AddIndicators(f)
    f.power = bar(f,5)
    f.power:SetPoint("TOPLEFT",f,"BOTTOMLEFT",0,-2)
    f.power:Hide()
    f.auraAnchor = CreateFrame("Frame",nil,f)
    f.auraAnchor:SetSize(1,1)
    f.cast = bar(f,14)
    f.cast:SetPoint("TOPLEFT",f,"BOTTOMLEFT",0,-2)
    f.castText, f.castTime = text(f.cast,11,"castText"), text(f.cast,11,"castText")
    f.castText:SetPoint("LEFT",3,0)
    f.castText:SetWidth(126)
    f.castText:SetWordWrap(false)
    f.castText:SetJustifyH("LEFT")
    f.castTime:SetPoint("RIGHT",-2,0)
    f.cast:SetScript("OnUpdate",function(c)
        local now = GetTime()
        if now >= c.finish then c:Hide() return end
        c:SetValue(c.channel and c.finish-now or now-c.start)
        c:GetParent().castTime:SetFormattedText("%.1f",c.finish-now)
    end)
    local function layout()
        local last = f.power:IsShown() and f.power or f
        f.cast:ClearAllPoints()
        f.cast:SetPoint("TOPLEFT",last,"BOTTOMLEFT",0,-2)
        f.auraAnchor:ClearAllPoints()
        f.auraAnchor:SetPoint("TOPLEFT",f.cast:IsShown() and f.cast or last,"BOTTOMLEFT",0,-3)
    end
    f.power:SetScript("OnShow",layout)
    f.power:SetScript("OnHide",layout)
    f.cast:SetScript("OnShow",layout)
    f.cast:SetScript("OnHide",layout)
    layout()
    f.icons = {}
end
local function power(f,unit,enemy,personal,sample)
    if enemy==nil then enemy=A.IsEnemyPlayer(unit) end
    local key=personal and "personalPower" or A.PlayerOptionKey("power",enemy)
    if not A.db[key] or not UnitIsPlayer(unit) then f.power:Hide(); return end
    local kind, token = UnitPowerType(unit)
    if not readable(kind) then f.power:Hide(); return end
    local maximum = sample and 100 or UnitPowerMax(unit,kind)
    if readable(maximum) and (not maximum or maximum<=0) then f.power:Hide(); return end
    local c = PowerBarColor and ((readable(token) and PowerBarColor[token]) or PowerBarColor[kind])
    f.power:SetStatusBarColor(c and c.r or .22,c and c.g or .5,c and c.b or 1)
    f.power:SetMinMaxValues(0,maximum)
    local current=sample and 65 or UnitPower(unit,kind)
    f.power:SetValue(current)
    local height=A.db[key.."Height"] or 5
    if A.db[key.."Value"] then
        if not f.powerValue then
            f.powerValue=text(f.power,10,"resourceText")
            f.powerValue:SetPoint("CENTER")
            f.powerValue:SetWordWrap(false)
        end
        A.SetNumericLabel(f.powerValue,current,maximum,A.db[key.."Format"],unit,kind)
        f.powerValue:Show()
        local _,size=f.powerValue:GetFont()
        height=math.max(height,math.ceil(size)+3)
    elseif f.powerValue then
        f.powerValue:Hide()
    end
    f.power:SetHeight(height)
    f.power:Show()
end
local glowTextures={
    ["Soft outline"]="TargetGlow",
    ["Side flares"]="TargetSideFlares",
    ["Crown"]="TargetCrown",
    ["Wisp"]="TargetWisp",
}
local function selectPlate(f, selected)
    if not selected or not A.db.targetOutline then
        if f.targetGlow then f.targetGlow:Hide(); f.neonTop:Hide(); f.neonBottom:Hide() end
        return
    end
    if not f.targetGlow then
        local glow=f:CreateTexture(nil,"BACKGROUND")
        glow:SetBlendMode("ADD")
        f.targetGlow=glow
        for _,top in ipairs({true,false}) do
            local strip=f:CreateTexture(nil,"BACKGROUND")
            strip:SetTexture("Interface\\AddOns\\RaynnaNameplates\\TargetNeon")
            strip:SetBlendMode("ADD")
            if top then
                strip:SetPoint("BOTTOMLEFT",f.health,"TOPLEFT",-3,0)
                strip:SetPoint("BOTTOMRIGHT",f.health,"TOPRIGHT",3,0)
                strip:SetTexCoord(0,1,1,0)
                f.neonTop=strip
            else
                strip:SetPoint("TOPLEFT",f.health,"BOTTOMLEFT",-3,0)
                strip:SetPoint("TOPRIGHT",f.health,"BOTTOMRIGHT",3,0)
                f.neonBottom=strip
            end
        end

    end
    local alpha=(A.db.targetGlowStrength or 100)/100
    local style=A.db.targetGlowStyle or "Soft outline"
    local spread=A.db.targetGlowSpread or 18
    if f.glowSpread~=spread then
        f.targetGlow:SetPoint("TOPLEFT",f.health,"TOPLEFT",-spread,spread)
        f.targetGlow:SetPoint("BOTTOMRIGHT",f.health,"BOTTOMRIGHT",spread,-spread)
        f.neonTop:SetHeight(spread)
        f.neonBottom:SetHeight(spread)
        f.glowSpread=spread
    end
    f.targetGlow:SetAlpha(alpha)
    f.neonTop:SetAlpha(alpha)
    f.neonBottom:SetAlpha(alpha)
    local texture=glowTextures[style]
    if texture and f.glowTexture~=texture then
        f.targetGlow:SetTexture("Interface\\AddOns\\RaynnaNameplates\\"..texture)
        f.glowTexture=texture
    end
    f.targetGlow:SetShown(texture~=nil)
    f.neonTop:SetShown(style=="Neon edges")
    f.neonBottom:SetShown(style=="Neon edges" or style=="Underglow")
    local hex=A.db.targetColor or "FFB31E"
    if f.glowColor~=hex then
        local r,g,b=tonumber(hex:sub(1,2),16)/255,tonumber(hex:sub(3,4),16)/255,tonumber(hex:sub(5,6),16)/255
        f.targetGlow:SetVertexColor(r,g,b)
        f.neonTop:SetVertexColor(r,g,b)
        f.neonBottom:SetVertexColor(r,g,b)
        f.glowColor=hex
    end
end
local function create(plate)
    local f = CreateFrame("Frame", nil, plate)
    f:SetPoint("CENTER")
    f:SetSize(162,18)
    f.health = bar(f,18)
    f.health:SetAllPoints()
    f.name, f.level, f.value = text(f,15,"nameText"), text(f,14,"levelText"), text(f.health,13,"healthText")
    f.name:SetWidth(132)
    f.name:SetWordWrap(false)
    f.name:SetJustifyH("LEFT")
    f.name:SetPoint("BOTTOMLEFT", f,"TOPLEFT",0,2)
    f.level:SetPoint("BOTTOMRIGHT",f,"TOPRIGHT",0,2)
    f.distance=text(f,11,"distanceText")
    f.distance:SetPoint("LEFT",f.level,"RIGHT",4,0)
    f.distance:SetTextColor(.8,.88,.95)
    f.distance:Hide()
    f.value:SetPoint("CENTER")
    A.AddIndicators(f)
    return f
end
local function color(key)
    local hex = A.db[key]
    return tonumber(hex:sub(1,2),16)/255, tonumber(hex:sub(3,4),16)/255, tonumber(hex:sub(5,6),16)/255
end
local function friendlyPlayer(unit)
    return not UnitCanAttack("player",unit) and UnitIsFriend("player",unit)
end
local threatStates={[0]="Low threat",[1]="Gaining aggro",[2]="Losing lead",[3]="Holding aggro"}
local function showThreat(f,percent,tint)
    if not A.db.showThreat or not readable(percent) or type(percent) ~= "number" then
        if f.threat then f.threat:Hide() end
        return
    end
    if not f.threat then f.threat=text(f,11,"threatText") end
    local label=f.threat
    local position=A.db.threatPosition
    label:ClearAllPoints()
    if position=="Left of bar" then label:SetPoint("RIGHT",f.health,"LEFT",-5,0)
    elseif position=="Above name" then label:SetPoint("BOTTOM",f.name,"TOP",0,2)
    else label:SetPoint("LEFT",f.health,"RIGHT",5,0) end
    label:SetFormattedText("%d%%", math.floor(percent + .5))
    label:SetTextColor(color(tint))
    label:Show()
end
local function mobThreatToken(u)
    for _, alias in ipairs({"target", "mouseover", "focus", "pettarget"}) do
        if UnitIsUnit(alias, u) then return alias end
    end
    for i = 1, GetNumSubgroupMembers() do
        local alias = "party"..i.."target"
        if UnitIsUnit(alias, u) then return alias end
        alias = "partypet"..i.."target"
        if UnitIsUnit(alias, u) then return alias end
    end
    return u
end

local function holdsThreat(member, mob)
    if not UnitExists(member) then return false end
    if UnitIsUnit(mob.."target", member) then return true end
    if UnitDetailedThreatSituation then
        local tanking, rank = UnitDetailedThreatSituation(member, mob)
        if readable(tanking) and tanking then return true end
        if readable(rank) and rank and rank >= 2 then return true end
    end
    local rank = UnitThreatSituation(member, mob)
    return readable(rank) and rank and rank >= 2
end

-- A tank can have a detailed threat table for a mob that another party member
-- cannot inspect. Relay only personal tanking observations, keyed by mob GUID.
local threatPrefix = "RNPThreat1"
local reports, lastSent = {}, {}
local shareThreat
local function mobGUID(unit)
    local guid = UnitGUID(unit)
    if readable(guid) and type(guid) == "string" then return guid end
end

local function receiveThreat(prefix, guid, channel, sender)
    if prefix ~= threatPrefix or channel ~= "PARTY" or #guid > 100 then return end
    for i = 1, GetNumSubgroupMembers() do
        local member = "party"..i
        local name, realm = UnitFullName(member)
        if name and (sender == name or sender == name.."-"..(realm or GetNormalizedRealmName())) then
            local now = GetTime()
            for id, expires in pairs(reports) do
                if expires <= now then reports[id] = nil end
            end
            reports[guid] = now + 3
            return
        end
    end
end

-- Forever can expose party targets before it supplies the observer's threat table.
-- This fallback affects the bar colour only. Targeting never proves tanking.
local function partyTargetsInCombat(mob)
    for i = 1, GetNumSubgroupMembers() do
        local member = "party"..i
        local pet = "partypet"..i
        if UnitIsUnit(member.."target", mob) and UnitAffectingCombat(member) then return true end
        if UnitIsUnit(pet.."target", mob) and UnitAffectingCombat(pet) then return true end
    end
    return false
end

local function combatThreat(f,u)
    local token=mobThreatToken(u)
    local status,percent,tanking
    if UnitDetailedThreatSituation then
        tanking,status,percent=UnitDetailedThreatSituation("player",token)
    end
    if not readable(status) or not threatStates[status] then status=UnitThreatSituation("player",token) end
    if not readable(status) or not threatStates[status] then status=nil end
    if not readable(percent) then percent=nil end
    local victim=token.."target"
    local key
    if (status and status>=2) or (readable(tanking) and tanking) then
        key="aggro"
    elseif status==1 then key="pulling"
    elseif UnitIsUnit(victim,"player") then key="aggro"
    else
        key="safe"
        for i=1,GetNumSubgroupMembers() do
            local member="party"..i
            if holdsThreat(member,token) or (token~=u and holdsThreat(member,u)) then
                key="partyAggro"
                break
            elseif holdsThreat("partypet"..i,token) or (token~=u and holdsThreat("partypet"..i,u)) then
                key="partyAggro"
                break
            end
        end
    end
    if GetNumSubgroupMembers() > 0 then
        local guid = mobGUID(u)
        local now = GetTime()
        if guid and key == "aggro" and shareThreat and (lastSent[guid] or -2) <= now-1.5 then
            lastSent[guid] = now
            shareThreat(threatPrefix, guid, "PARTY")
        elseif guid and key == "safe" and reports[guid] and reports[guid] > now
            and not UnitExists(victim) then
            key = "partyAggro"
        end
    end
    if key == "safe" and not UnitExists(victim) and not UnitExists(u.."target")
        and partyTargetsInCombat(u) then
        key = "partyAggro"
    end
    showThreat(f,percent,key)
    return key
end
local function paint(f,u)
    local reaction = UnitReaction(u,"player")
    if not readable(reaction) then reaction=nil end
    local key = reaction and reaction <= 3 and "hostile" or reaction == 4 and "neutral" or "friendly"
    if f.talk and key=="neutral" and not UnitCanAttack("player",u) then key="friendly" end
    if UnitIsPlayer(u) then key=friendlyPlayer(u) and "friendly" or "hostile" end
    f.name:SetTextColor(color(f.quest and A.db.questTint and "quest" or key))
    if UnitIsPlayer(u) then
        local _, class = UnitClass(u)
        local c = readable(class) and RAID_CLASS_COLORS[class]
        if c then showThreat(f,nil); f.health:SetStatusBarColor(c.r,c.g,c.b) return end
    elseif key ~= "friendly" and UnitAffectingCombat(u) then
        key=combatThreat(f,u)
    end
    if UnitIsPlayer(u) or key=="friendly" or not UnitAffectingCombat(u) then showThreat(f,nil) end
    if f.quest and A.db.questTint and not UnitAffectingCombat(u) then key="quest" end
    f.health:SetStatusBarColor(color(key))
end
local function cast(f,u)
    local n,desc,icon,s,e = UnitCastingInfo(u)
    local channel = false
    if not n then n,desc,icon,s,e = UnitChannelInfo(u); channel = true end
    if not A.PlateOption(f,"casts") or not n or not readable(s) or not readable(e) or not s or not e then
        f.cast:Hide()
        return
    end
    f.cast.start, f.cast.finish, f.cast.channel = s/1000,e/1000,channel
    f.cast:SetMinMaxValues(0,(e-s)/1000)
    f.cast:SetHeight(A.db.castHeight or 14)
    f.castTime:SetShown(A.db.castTimer~=false)
    f.cast:SetStatusBarColor(color("castColor"))
    f.castText:SetText(n)
    f.cast:Show()
end
local cc = {[12494]=true,[33395]=true,[122]=true,[865]=true,[6131]=true,[10230]=true,[118]=true,[853]=true,[408]=true,[339]=true}
local function isControl(unit,aura)
    if readable(aura.spellId) and cc[aura.spellId] then return true end
    local check=C_UnitAuras and C_UnitAuras.IsAuraFilteredOutByInstanceID
    if unit and check and readable(aura.auraInstanceID) and aura.auraInstanceID then
        local ok,excluded=pcall(check,unit,aura.auraInstanceID,"HARMFUL|CROWD_CONTROL")
        return ok and readable(excluded) and excluded==false
    end
    return false
end
local function dismissAura(box)
    if GameTooltip:IsOwned(box) then GameTooltip:Hide() end
end
local function describeAura(box)
    local a=box.aura
    if not a then return end
    GameTooltip:SetOwner(box,"ANCHOR_RIGHT")
    if box.unit and GameTooltip.SetUnitAura then
        GameTooltip:SetUnitAura(box.unit,box.index,box.filter)
    elseif a.spellId and GameTooltip.SetSpellByID then
        GameTooltip:SetSpellByID(a.spellId)
    else
        GameTooltip:AddLine(a.name or "Aura",1,.82,.25)
    end
    GameTooltip:AddLine(box.filter=="HELPFUL" and "Buff" or "Debuff",.75,.82,.88)
    GameTooltip:Show()
end
local function updateCountdown(box,elapsed)
    box.tick=(box.tick or 0)+elapsed
    if box.tick < .1 then return end
    box.tick=0
    local seconds=math.ceil(box.expires-GetTime())
    if seconds<=0 then box.timer:Hide(); box:SetScript("OnUpdate",nil); return end
    box.timer:SetText(seconds>=86400 and math.ceil(seconds/86400).."d" or seconds>=3600 and math.ceil(seconds/3600).."h" or seconds>=60 and math.ceil(seconds/60).."m" or seconds)
end
-- In restricted combat the client owns the aura buttons and their duration text.
A.auraPositions={"Top left","Top middle","Top right","Middle left","Middle right","Bottom left","Bottom middle","Bottom right"}
local placementDefaults={buffPosition="Top left",debuffPosition="Bottom left",controlPosition="Middle right"}
function A.AuraPosition(key)
    return A.db[key] or placementDefaults[key]
end
local function anchorAura(widget,f,position,index,count,size,scale)
    local x=0
    local y=0
    local relative=f
    local anchor="TOPLEFT"
    if position=="Middle left" then
        x=-4-(count-index)*size
    elseif position=="Middle right" then
        anchor="TOPRIGHT"
        x=4+index*size
    else
        local guild=f.guild and f.guild:IsShown() and f.guild
        if position:find("Bottom",1,true) then
            relative=f.auraAnchor
            if guild and guild.position=="Below plate" then y=-guild:GetHeight()-2 end
        else
            local height=f.name and f.name:GetStringHeight()
            local heading=readable(height) and height or 16
            if guild then
                if guild.position=="Before name" or guild.position=="After name" then
                    heading=math.max(heading,guild:GetHeight())
                elseif guild.position~="Below plate" then
                    heading=heading+guild:GetHeight()+2
                end
            end
            local clearance=math.max(20,heading+4)
            if f.isPersonal and not f.name:IsShown() then
                clearance=f.level:IsShown() and 20 or 2
                if guild and guild.position~="Below plate" then clearance=math.max(clearance,guild:GetHeight()+4) end
            end
            y=clearance+size+math.ceil(size*.6)
        end
        local width=f:GetWidth()
        x=index*size
        if position:find("middle",1,true) then x=x+(width-count*size)/2
        elseif position:find("right",1,true) then x=x+width-count*size end
    end
    widget:ClearAllPoints()
    widget:SetPoint("TOPLEFT",relative,anchor,x/scale,y/scale)
end
local function setLevel(label,level)
    label:SetShown(A.db.showLevelText~=false)
    label:SetText(readable(level) and level==-1 and "??" or level)
    local r,g,b=1,1,1
    if readable(level) and type(level)=="number" then
        local delta=level-UnitLevel("player")
        if level==-1 then r,g,b=1,.12,.12
        elseif delta<0 then
            local t=math.min(1,-delta/5)
            r,b=1-.70*t,1-.65*t
        elseif delta<=3 then b=1-.88*delta/3
        else g,b=1-.88*math.min(1,(delta-3)/5),.12 end
    end
    label:SetTextColor(r,g,b)
end
local function nativeAuras(f,u,enabled)
    local supported=false
    if enabled and u and C_XMLUtil and C_XMLUtil.GetTemplateInfo then
        local ok,template=pcall(C_XMLUtil.GetTemplateInfo,"CustomAuraContainerTemplate")
        supported=ok and template~=nil
    end
    f.auraLayouts=f.auraLayouts or {}
    local buffFilter=A.db.castableBuffs and "HELPFUL|PLAYER" or "HELPFUL"
    local harmfulFilter="HARMFUL|PLAYER|!CROWD_CONTROL"
    local controlFilter="HARMFUL|PLAYER|CROWD_CONTROL"
    local rows={}
    local function addFilter(key,filter)
        local position=A.AuraPosition(key)
        rows[position]=rows[position] or {}
        table.insert(rows[position],filter)
    end
    if supported then
        if A.PlateOption(f,"buffs") then addFilter("buffPosition",buffFilter) end
        if A.PlateOption(f,"debuffs") then
            if A.AuraPosition("debuffPosition")==A.AuraPosition("controlPosition") then
                addFilter("debuffPosition","HARMFUL|PLAYER")
            else
                addFilter("debuffPosition",harmfulFilter)
                addFilter("controlPosition",controlFilter)
            end
        end
    end
    local activeRows={}
    for position,filters in pairs(rows) do
        local signature=table.concat(filters,";")
        activeRows[signature]=true
        local container=f.auraLayouts[signature]
        if not container then
            container=CreateFrame("AuraContainer",nil,f,"CustomAuraContainerTemplate")
            container:SetSize(1,1)
            container:SetFlowLayoutAnchorPoint("TOPLEFT")
            container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right,AnchorUtil.FlowDirection.Down)
            container:SetFlowLayoutMaximumLineSize(126*#filters)
            local formatter=C_StringUtil.CreateNumericRuleFormatter()
            formatter:AddBreakpoint({threshold=0,step=1,format="%d"})
            formatter:AddBreakpoint({threshold=60,step=60,format=""})
            for index,filter in ipairs(filters) do
                local helpful=filter:sub(1,7)=="HELPFUL"
                container:AddAuraGroup("group"..index,filter,{
                    initializeFrame=function(button)
                        button:SetSize(21,21)
                        local art=button:CreateTexture(nil,"ARTWORK")
                        local rim=button:CreateTexture(nil,"BACKGROUND")
                        rim:SetAllPoints()
                        if helpful then rim:SetColorTexture(.18,.9,.32,1) else rim:SetColorTexture(.95,.15,.19,1) end
                        art:SetPoint("TOPLEFT",2,-2)
                        art:SetPoint("BOTTOMRIGHT",-2,2)
                        art:SetTexCoord(.07,.93,.07,.93)
                        button:SetIcon(art)
                        local timer=text(button,10,"auraText")
                        timer:SetPoint("TOP",button,"BOTTOM",0,-1)
                        timer:SetWidth(0)
                        timer:SetWordWrap(false)
                        button:SetDurationText(timer,{textFormatter=formatter})
                    end,
                    maxFrameCount=6,
                    sortMethod=AuraContainerSortMethod.Default,
                    sortDirection=AuraContainerSortDirection.Normal,
                    layout={elementWidth=21,elementHeight=21,elementSpacing=0,lineSpacing=14}
                })
            end
            f.auraLayouts[signature]=container
        end
        local scale=(A.db.auraScale or 100)/100
        container:SetScale(scale)
        anchorAura(container,f,position,0,6*#filters,21*scale,scale)
        container:SetUnit(u)
        container:SetEnabled(true)
        container:Show()
    end
    for signature,container in pairs(f.auraLayouts) do
        if not activeRows[signature] then
            container:SetEnabled(false)
            container:Hide()
        end
    end
    return supported
end
local function accessible(t)
    return readable(t) and type(t)=="table" and (not canaccesstable or canaccesstable(t))
end
local allAuras={"HARMFUL|PLAYER","HARMFUL","HELPFUL"}
local castableAuras={"HARMFUL|PLAYER","HARMFUL","HELPFUL|PLAYER","HELPFUL|RAID","HELPFUL"}
local function canApply(a,query)
    if query=="HELPFUL|PLAYER" or query=="HELPFUL|RAID" then return true end
    if readable(a.canApplyAura) and a.canApplyAura then return true end
    if readable(a.sourceUnit) and a.sourceUnit=="player" then return true end
    local known=IsPlayerSpell or IsSpellKnown
    return known and readable(a.spellId) and a.spellId and known(a.spellId)
end
local function auras(f,u,samples)
    local count,side,bottom,top = 0,0,0,0
    local seen={}
    local positions={}
    if u and u~="player" and UnitIsUnit(u,"target") then u="target" end
    local native = nativeAuras(f,u,not samples and C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret())
    if not native and (samples or C_UnitAuras) then
        for _,filter in ipairs(A.db.castableBuffs and castableAuras or allAuras) do
        local helpfulQuery=filter:sub(1,7)=="HELPFUL"
        if samples or (not helpfulQuery and A.PlateOption(f,"debuffs")) or (helpfulQuery and A.PlateOption(f,"buffs")) then
        local batch
        local query=filter

        if not samples and C_UnitAuras.GetUnitAuras then
            local ok,list=pcall(C_UnitAuras.GetUnitAuras,u,query,40)
            if ok and accessible(list) then batch=list end
        end
        for i=1,40 do
            local a
            if samples then a=samples[i]
            elseif batch then a=batch[i]
            elseif C_UnitAuras.GetAuraDataByIndex then
                local ok,result=pcall(C_UnitAuras.GetAuraDataByIndex,u,i,query)
                if ok then a=result end
            end
            if not accessible(a) then break end
            local helpful = helpfulQuery or (samples and a.helpful)
            local id=a.auraInstanceID
            local unique=readable(id) and id
            if not unique and readable(a.spellId) and readable(a.sourceUnit) and a.spellId then
                unique=tostring(a.spellId)..":"..tostring(a.sourceUnit)
            end
            if (not unique or not seen[unique]) and ((helpful and top<6 and A.PlateOption(f,"buffs") and (not A.db.castableBuffs or canApply(a,query))) or (not helpful and bottom+side<6 and A.PlateOption(f,"debuffs"))) then
            if unique then seen[unique]=true end
            count=count+1
            local box=f.icons[count]
            if not box then
                box=CreateFrame("Frame",nil,f)
                box:EnableMouse(true)
                if box.SetMouseClickEnabled then box:SetMouseClickEnabled(false) end
                box:SetScript("OnEnter",describeAura)
                box:SetScript("OnLeave",dismissAura)
                box:SetScript("OnHide",dismissAura)
                box.rim=box:CreateTexture(nil,"BACKGROUND")
                box.rim:SetAllPoints()
                box.art=box:CreateTexture(nil,"ARTWORK")
                box.art:SetPoint("TOPLEFT",2,-2)
                box.art:SetPoint("BOTTOMRIGHT",-2,2)
                box.art:SetTexCoord(.07,.93,.07,.93)
                box.timer=text(box,11,"auraText")
                box.timer:SetPoint("TOP",box,"BOTTOM",0,-1)
                f.icons[count]=box
            end
            local size=math.floor(21*(A.db.auraScale or 100)/100+.5)
            box:SetSize(size,size)
            A.SetPlateFont(box.timer, math.max(6,math.floor(size*.42)))
            box.timer:SetWidth(0)
            box.timer:SetWordWrap(false)
            local key
            if helpful then key="buffPosition"; top=top+1
            elseif isControl(u,a) then key="controlPosition"; side=side+1
            else key="debuffPosition"; bottom=bottom+1 end
            local position=A.AuraPosition(key)
            positions[position]=positions[position] or {}
            table.insert(positions[position],box)
            box.rim:SetColorTexture(.95,.15,.19,1)
            box.aura,box.unit,box.index,box.filter=a,u,i,helpful and "HELPFUL" or "HARMFUL"
            if not samples then box.filter=query end
            if helpful then box.rim:SetColorTexture(.18,.9,.32,1) end
            box.art:SetTexture(a.icon)
            if readable(a.duration) and readable(a.expirationTime) and a.duration and a.duration>0 and a.expirationTime then
                box.expires=a.expirationTime
                box.tick=1
                box:SetScript("OnUpdate",updateCountdown)
                box.timer:Show()
                updateCountdown(box,0)
            else box.timer:Hide(); box:SetScript("OnUpdate",nil) end
            box:Show()
            if GameTooltip:IsOwned(box) then describeAura(box) end
            end
        end
        end
        if samples then break end
        end
    end
    for position,icons in pairs(positions) do
        for index,icon in ipairs(icons) do
            anchorAura(icon,f,position,index-1,#icons,icon:GetWidth(),1)
        end
    end
    for i=count+1,#f.icons do f.icons[i]:Hide() end
end
function A.PersonalIndicators(frame)
    if not frame.cast then A.AddIndicators(frame) end
    A.personalFrame=frame
    power(frame,"player",false,true)
    cast(frame,"player")
    auras(frame,"player")
end
local function health(f,u)
    local hp,max = UnitHealth(u),UnitHealthMax(u)
    f.health:SetMinMaxValues(0,max)
    f.health:SetValue(hp)
    A.SetHealthLabel(f.value,hp,max,u)
end
A.scaleGroups = {
    {"enemyNPCScale", "Hostile / neutral NPCs"},
    {"friendlyNPCScale", "Friendly NPCs"},
    {"enemyPlayerScale", "Enemy players"},
    {"friendlyPlayerScale", "Friendly players"},
    {"targetScale", "Current target"}
}
local function groupScale(key)
    return A.db[key] / 100
end
local function isWorldObject(u)
    if UnitIsPlayer(u) then return false end
    if UnitIsGameObject then
        local object=UnitIsGameObject(u)
        if readable(object) and object then return true end
    end
    if UnitCanAttack("player",u) then return false end
    local level,hp=UnitLevel(u),UnitHealth(u)
    return readable(level) and level==0 and readable(hp) and hp==0
end
local function objectLabel(f,u)
    if not f.objectLabel then
        f.objectLabel=text(f,14,"nameText")
        f.objectLabel:SetPoint("CENTER")
        f.objectLabel:SetTextColor(.72,.93,1)
        f.objectIcon=f:CreateTexture(nil,"ARTWORK")
        f.objectIcon:SetSize(17,17)
        f.objectIcon:SetPoint("RIGHT",f.objectLabel,"LEFT",-4,0)
    end
    local name=UnitName(u)
    f.objectLabel:SetText(name)
    local portal=readable(name) and name and name:lower():find("portal",1,true)
    f.objectIcon:SetDesaturated(false)
    f.objectIcon:SetTexture(portal and "Interface\\Icons\\Spell_Arcane_PortalUndercity" or "Interface\\Icons\\INV_Misc_Spyglass_03")
    f.objectIcon:Show()
    f.objectLabel:Show()
end
local function marker(f)
    if A.db.questIcon and (f.quest or f.dialogQuest) then
        return (f.dialogQuest=="turnin" or f.dialogQuest=="incomplete") and "Interface\\GossipFrame\\ActiveQuestIcon" or "Interface\\GossipFrame\\AvailableQuestIcon"
    end
    if f.talk and not f.serviceTitle then return "Interface\\GossipFrame\\GossipGossipIcon" end
end
local function extraChat(f,anchor,show)
    if show then
        if not f.extraChat then
            f.extraChat=f:CreateTexture(nil,"OVERLAY")
            f.extraChat:SetTexture("Interface\\GossipFrame\\GossipGossipIcon")
            f.extraChat:SetSize(16,16)
        end
        f.extraChat:ClearAllPoints()
        f.extraChat:SetPoint("RIGHT",anchor,"LEFT",-2,0)
        f.extraChat:Show()
    elseif f.extraChat then f.extraChat:Hide() end
end
local function nameMarker(f)
    local texture=marker(f)
    if texture then
        if not f.questBadge then
            f.questBadge=f:CreateTexture(nil,"OVERLAY")
            f.questBadge:SetSize(17,17)
            f.questBadge:SetPoint("RIGHT",f.name,"LEFT",-3,0)
        end
        f.questBadge:SetTexture(texture)
        f.questBadge:SetDesaturated(f.dialogQuest=="incomplete" or f.dialogQuest=="upcoming")
        f.questBadge:Show()
    elseif f.questBadge then f.questBadge:Hide() end
    extraChat(f,f.questBadge,f.talk and not f.serviceTitle and A.db.questIcon and (f.quest or f.dialogQuest))
end
local function servicePlaque(f,u,sampleName)
    if not f.servicePanel then
        local panel=CreateFrame("Frame",nil,f,"BackdropTemplate")
        panel:SetPoint("CENTER")
        panel:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        panel:SetBackdropColor(.08,.055,.035,.86)
        panel.icon=panel:CreateTexture(nil,"ARTWORK")
        panel.icon:SetSize(23,23)
        panel.icon:SetPoint("LEFT",5,0)
        panel.name=text(panel,14,"nameText")
        panel.name:SetPoint("BOTTOMLEFT",panel,"LEFT",32,-1)
        panel.role=text(panel,11,"serviceText")
        panel.role:SetPoint("TOPLEFT",panel,"LEFT",32,-1)
        panel.role:SetTextColor(.98,.82,.52)
        panel.quest=panel:CreateTexture(nil,"OVERLAY")
        panel.quest:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
        panel.quest:SetSize(15,15)
        panel.quest:SetPoint("LEFT",panel,"RIGHT",2,0)
        f.servicePanel=panel
    end
    local panel=f.servicePanel
    panel.icon:SetTexture(f.serviceSprite)
    panel.name:SetText(sampleName or UnitName(u))
    panel.name:SetTextColor(color(f.quest and A.db.questTint and "quest" or "friendly"))
    panel.role:SetText(f.serviceTitle)
    local nameWidth,roleWidth=panel.name:GetStringWidth(),panel.role:GetStringWidth()
    panel:SetSize(40+math.max(readable(nameWidth) and nameWidth or 100,readable(roleWidth) and roleWidth or 100),34)
    local badge=marker(f)
    if badge then panel.quest:SetTexture(badge) end
        panel.quest:SetDesaturated(f.dialogQuest=="incomplete" or f.dialogQuest=="upcoming")
    panel.quest:SetShown(badge~=nil)
    local targeted=u and UnitIsUnit("target",u)
    if A.db.questTint and (f.quest or f.dialogQuest) then
        local r,g,b=color("quest")
        panel:SetBackdropBorderColor(r,g,b,1)
        panel:SetBackdropColor(.05+r*.16,.04+g*.16,.03+b*.16,.94)
    else
        panel:SetBackdropBorderColor(.84,.63,.29,targeted and 1 or .42)
        panel:SetBackdropColor(.08,.055,.035,.86)
    end
    panel:Show()
end
local function playerCompanion(unit)
    local own=UnitIsUnit("pet",unit)
    if readable(own) and own then return true end
    local other=UnitIsOtherPlayersPet and UnitIsOtherPlayersPet(unit)
    if readable(other) and other then return true end
    local minion=UnitIsMinion and UnitIsMinion(unit)
    return readable(minion) and minion
end
local function companionCaption(f,unit)
    if f.ownerCaption then return f.ownerCaption end
    local now=GetTime()
    if not f.nextOwnerCheck or now>=f.nextOwnerCheck then
        f.nextOwnerCheck=now+3
        local data=C_TooltipInfo and C_TooltipInfo.GetUnit and C_TooltipInfo.GetUnit(unit)
        for _,line in ipairs(data and data.lines or {}) do
            local title=line.leftText
            if readable(title) and type(title)=="string" then
                for _,key in ipairs({"UNITNAME_TITLE_PET","UNITNAME_TITLE_MINION","UNITNAME_TITLE_GUARDIAN"}) do
                    local template=_G[key]
                    if template then
                        local prefix,suffix=template:match("^(.-)%%s(.-)$")
                        if prefix and #title>#prefix+#suffix and title:sub(1,#prefix)==prefix
                            and (#suffix==0 or title:sub(-#suffix)==suffix) then
                            f.ownerCaption=title
                            return title
                        end
                    end
                end
            end
        end
    end
    return "Companion"
end
local function showCompanionText(f,u)
    if not A.db.showCompanionText then return end
    if not f.companionLabel then
        local label=CreateFrame("Frame",nil,f)
        label:SetAllPoints(f)
        label.name=text(label,14,"nameText")
        label.name:SetPoint("BOTTOM",label,"CENTER",0,0)
        label.owner=text(label,11,"serviceText")
        label.owner:SetPoint("TOP",label.name,"BOTTOM",0,-1)
        label.owner:SetTextColor(.98,.82,.52)
        f.companionLabel=label
    end
    local label=f.companionLabel
    label.name:SetText(UnitName(u))
    label.name:SetTextColor(color("friendly"))
    label.owner:SetText(companionCaption(f,u))
    label:Show()
end
local function friendlyNPCLayout(f,friendly,nonAttackable,companion,object,inCombat)
    local interactive=f.quest or f.dialogQuest or f.talk or f.serviceTitle
    local nameOnly=A.db.hideIdleNPCs and friendly and not interactive and not companion and not object and not inCombat
    local compact=nonAttackable and interactive or companion or (friendly and A.db.compactFriendly)
    return nameOnly,compact
end
local function refresh(f,u)
    if f.quest==nil then
        f.quest=A.IsQuestVendor(u) or A.IsQuestNPC(u)
        f.dialogQuest,f.talk=A.NPCInteraction(u)
    end
    if not f.serviceChecked then
        f.serviceTitle,f.serviceSprite=A.ServiceRole(u)
        f.serviceChecked=true
    end
    extraChat(f,nil,false)
    if f.servicePanel then f.servicePanel:Hide() end
    if f.companionLabel then f.companionLabel:Hide() end
    local friendlyNPC=not UnitIsPlayer(u) and UnitIsFriend("player",u) and not UnitCanAttack("player",u)
    local companion=friendlyNPC and A.db.compactCompanions and playerCompanion(u)
    if friendlyNPC and A.db.compactCompanions and not companion and UnitPlayerControlled then
        local controlled=UnitPlayerControlled(u)
        if readable(controlled) and controlled then
            companionCaption(f,u)
            companion=f.ownerCaption~=nil
        end
    end
    f.npcInCombat=not not UnitAffectingCombat(u)
    local object=not companion and isWorldObject(u)
    local pet=companion or (friendlyNPC and playerCompanion(u))
    local controlled=friendlyNPC and UnitPlayerControlled and UnitPlayerControlled(u)
    local exemptPet=pet or (readable(controlled) and controlled)
    local nonAttackable=not UnitIsPlayer(u) and not UnitCanAttack("player",u)
    local nameOnly
    nameOnly,f.combatLayout=friendlyNPCLayout(f,friendlyNPC,nonAttackable,exemptPet,object,f.npcInCombat)
    if exemptPet and not companion then f.combatLayout=A.db.compactFriendly and friendlyNPC end
    f:SetShown(not f.outsideDistance)
    f.objectOnly=nameOnly or object or (f.combatLayout and not f.npcInCombat)
    if f.townBadge then f.townBadge:Hide() end
    selectPlate(f,not f.objectOnly and UnitIsUnit(u,"target"))
    f.health:SetShown(not f.objectOnly)
    f.name:SetShown(not f.objectOnly)
    f.level:SetShown(not f.objectOnly)
    if f.objectOnly then f.distance:Hide(); showThreat(f,nil) end
    if f.guild then f.guild:Hide() end
    if f.objectOnly then
        f:SetScale(.94*groupScale("friendlyNPCScale"))
        A.Badge(f,nil,f.name)
        f.power:Hide()
        f.cast:Hide()
        nativeAuras(f,nil,false)
        for _,icon in ipairs(f.icons) do icon:Hide() end
        if companion then
            if f.questBadge then f.questBadge:Hide() end
            if f.objectLabel then f.objectLabel:Hide(); f.objectIcon:Hide() end
            showCompanionText(f,u)
            return
        end
        objectLabel(f,u)
        if nameOnly then
            f.objectIcon:Hide()
            if f.questBadge then f.questBadge:Hide() end
            f.objectLabel:SetTextColor(color("friendly"))
            return
        end
        if not object then
            f.objectIcon:Hide()
            if not f.townBadge then
                f.townBadge=f:CreateTexture(nil,"BACKGROUND")
                f.townBadge:SetColorTexture(.065,.045,.025,.80)
                f.townBadge:SetPoint("TOPLEFT",f.objectLabel,"TOPLEFT",-7,4)
                f.townBadge:SetPoint("BOTTOMRIGHT",f.objectLabel,"BOTTOMRIGHT",7,-4)
            end
            f.townBadge:Show()
            f.objectLabel:SetTextColor(color("friendly"))
        else f.objectLabel:SetTextColor(.72,.93,1) end
        if f.quest and A.db.questTint then f.objectLabel:SetTextColor(color("quest")) end
        if marker(f) then
            f.objectIcon:SetTexture(marker(f))
        f.objectIcon:SetDesaturated(f.dialogQuest=="incomplete" or f.dialogQuest=="upcoming")
            f.objectIcon:Show()
        end
        extraChat(f,f.objectIcon,f.talk and not f.serviceTitle and A.db.questIcon and (f.quest or f.dialogQuest))
        if f.serviceTitle then
            f.objectLabel:Hide()
            f.objectIcon:Hide()
            if f.townBadge then f.townBadge:Hide() end
            servicePlaque(f,u)
        end
        if f.questBadge then f.questBadge:Hide() end
        return
    elseif f.objectLabel then
        f.objectLabel:Hide()
        f.objectIcon:Hide()
    end
    local friendly = UnitIsFriend("player",u)
    local group
    if UnitIsPlayer(u) then group = friendlyPlayer(u) and "friendlyPlayerScale" or "enemyPlayerScale"
    else group = friendly and "friendlyNPCScale" or "enemyNPCScale" end
    f:SetScale(.94 * groupScale(group) * (UnitIsUnit(u,"target") and groupScale("targetScale") or 1))
    nameMarker(f)
    if UnitIsPlayer(u) then
        f.name:SetText(A.PlayerDisplayName(u))
        A.PlayerHeading(f,f.name,f.level,u)
    else
        f.name:SetText(UnitName(u))
        A.LayoutName(f,f.name,f.level,false)
    end
    local lvl=UnitLevel(u)
    setLevel(f.level,lvl)
    health(f,u)
    paint(f,u)
    power(f,u)
    A.Badge(f,u,f.name)
    cast(f,u)
    auras(f,u)
end
-- Blizzard pools unit frames independently of the nameplate anchors.
local owners, hooked = {}, {}
local function suppress(native)
    if owners[native] and not native:IsForbidden() then
        local alpha=native:GetAlpha()
        if readable(alpha) and alpha~=0 then native:SetAlpha(0) end
    end
end
local function release(f)
    local native=f.native
    if native and owners[native]==f then
        owners[native]=nil
        if not native:IsForbidden() then native:SetAlpha(f.originalAlpha) end
    end
    f.native,f.originalAlpha=nil,nil
end
local function bind(f,plate)
    local native=plate.UnitFrame
    if f.native~=native then release(f) end
    if not native or native:IsForbidden() then return end
    if owners[native]~=f then
        if owners[native] then release(owners[native]) end
        local alpha=native:GetAlpha()
        f.native,f.originalAlpha=native,readable(alpha) and alpha or 1
        owners[native]=f
    end
    if not hooked[native] then
        hooked[native]=true
        hooksecurefunc(native,"Show",suppress)
        hooksecurefunc(native,"SetAlpha",suppress)
    end
    suppress(native)
end
local personalOwner={}
function A.BindPersonal(native,visible)
    if native and visible and not Plater and not native:IsForbidden() then
        bind(personalOwner,native)
    else
        release(personalOwner)
    end
end
local function detach(u)
    local f=active[u]
    if not f then return end
    active[u],f.unit=nil,nil
    release(f)
    nativeAuras(f,nil,false)
    f:Hide()
end
-- Range is measured from the player, independently of camera zoom.
-- Ordered probes bound the distance when coordinates are unavailable.
-- A nil or restricted answer provides no distance evidence.
local rangeItems={
    friendly={{5,1970},{15,1251},{20,21519},{30,1180},{35,18904},{40,18662}},
    hostile={{5,8149},{10,17626},{20,10645},{30,835},{35,18904},{40,4945}},
}
local function measuredDistance(unit,px,py,map)
    if UnitDistanceSquared then
        local squared,valid=UnitDistanceSquared(unit)
        if readable(valid) and valid and readable(squared) and type(squared)=="number" and squared>=0 then
            return math.sqrt(squared)
        end
    end
    if px and py and map and UnitPosition then
        local x,y,_,instance=UnitPosition(unit)
        if readable(x) and readable(y) and readable(instance) and x and y and instance==map then
            return math.sqrt((x-px)^2+(y-py)^2)
        end
    end
end
local function measureRange(unit,px,py,map)
    local distance=measuredDistance(unit,px,py,map)
    if distance then return distance end
    if unit~="target" then
        local target=UnitIsUnit(unit,"target")
        if readable(target) and target then
            distance=measuredDistance("target",px,py,map)
            if distance then return distance end
        end
    end
    -- Some client APIs require the party or raid token for the same player.
    local raidIndex=UnitInRaid and UnitInRaid(unit)
    if readable(raidIndex) and type(raidIndex)=="number" and raidIndex>0 then
        distance=measuredDistance("raid"..raidIndex,px,py,map)
    elseif UnitInParty then
        local member=UnitInParty(unit)
        if readable(member) and member then
            for index=1,4 do
                local token="party"..index
                local same=UnitIsUnit(unit,token)
                if readable(same) and same then
                    distance=measuredDistance(token,px,py,map)
                    break
                end
            end
        end
    end
    if distance then return distance end
    local lib=LibStub and LibStub("LibRangeCheck-3.0",true)
    local low,high
    if lib then
        low,high=lib:GetRange(unit)
        if not readable(low) or type(low)~="number" or low<=0 then low=nil end
        if not readable(high) or type(high)~="number" or high==math.huge then high=nil end

    end
    local check=C_Item and C_Item.IsItemInRange
    local attackable=UnitCanAttack("player",unit)
    if check and readable(attackable) then
        for _,probe in ipairs(attackable and rangeItems.hostile or rangeItems.friendly) do
            local yards=probe[1]
            if high and yards>=high then break end
            if not low or yards>low then
                local ok,inside=pcall(check,probe[2],unit)
                if ok and readable(inside) then
                    if inside==true or inside==1 then high=yards;break end
                    if inside==false or inside==0 then low=yards end
                end
            end
        end
    end
    if low and high and low>=high then return end
    return nil,low,high
end
local function rangeText(distance,low,high)
    if distance then return string.format("%.1f yd",distance) end
    if low and high then return string.format("~%.1f yd",(low+high)/2) end
    if high then return "<="..high.." yd" end
    if low then return ">"..low.." yd" end
    return "? yd"
end
function A.RefreshPlateDistances()
    local limit=A.db.viewDistance
    local show=A.db.showDistance
    local px,py,map
    if (limit or show) and UnitPosition then
        local x,y,_,instance=UnitPosition("player")
        if readable(x) and readable(y) and readable(instance) then px,py,map=x,y,instance end
    end
    for unit,frame in pairs(active) do
        local distance,low,high
        if limit or show then distance,low,high=measureRange(unit,px,py,map) end
        local outside=limit and ((distance and distance>limit) or (low and low>=limit))
        frame.outsideDistance=outside
        frame:SetShown(not outside)
        frame.distance:SetShown(show and not frame.objectOnly or false)
        if show and not frame.objectOnly then frame.distance:SetText(rangeText(distance,low,high)) end
    end
end
local function attach(u)
    if Plater or not u or UnitIsUnit(u,"player") then return end
    local plate=C_NamePlate.GetNamePlateForUnit(u)
    if not plate or plate:IsForbidden() then return end
    local f=pool[plate] or create(plate)
    if active[u] and active[u]~=f then detach(u) end
    if f.unit and f.unit~=u then detach(f.unit) end
    f.ownerCaption,f.nextOwnerCheck=nil,nil
    f.outsideDistance=nil
    f.serviceChecked=false
    f.quest=nil
    pool[plate],active[u],f.unit=f,f,u
    bind(f,plate)
    C_Timer.After(0,function()
        if active[u]==f then bind(f,plate) end
    end)
    f:Show()
    refresh(f,u)
    if A.db.viewDistance or A.db.showDistance then A.RefreshPlateDistances() end
end
local events=CreateFrame("Frame")
local preview
A.previewModes = {
    {key="enemyNPCScale", title="Hostile NPC", name="Kolkar Stormer", reaction="hostile", npc=true},
    {key="friendlyNPCScale", title="Friendly NPC", name="Crossroads Guard", reaction="friendly", npc=true},
    {key="friendlyPlayerScale", title="Friendly player", name="Mira", surname="Dawnvale", guild="Silver Lanterns", reaction="friendly"},
    {key="enemyPlayerScale", title="Enemy player", name="Drok", surname="Ironhand", guild="Blackrock Watch", reaction="hostile"},
    {key="personal", title="Personal", reaction="friendly"}
}
function A.PreviewMode()
    for index,mode in ipairs(A.previewModes) do
        if mode.key==A.db.previewMode then return mode,index end
    end
    return A.previewModes[1],1
end
local function drawSample(f,mode,previewSelected)
    showThreat(f,mode.npc and mode.reaction=="hostile" and not mode.service and 85 or nil,"pulling")
    f.quest=mode.objective
    f.dialogQuest=mode.dialogQuest
    if mode.service then
        f.health:Hide(); f.name:Hide(); f.level:Hide(); f.power:Hide(); f.cast:Hide()
        f.serviceSprite,f.serviceTitle=mode.service,mode.title
        f:SetScale(.94*groupScale("friendlyNPCScale"))
        servicePlaque(f,nil,mode.name)
        return
    end
    nameMarker(f)
    local personal=mode.key=="personal"
    A.LayoutPersonalParts(f,personal)
    local target=not personal and (previewSelected or A.db.previewTarget)
    selectPlate(f,target)
    f:SetScale(personal and A.db.scale/100 or .94*groupScale(mode.key)*(target and groupScale("targetScale") or 1))
    f.name:SetText(mode.name and A.FormatPlayerName(mode.name,mode.surname,mode.key=="enemyPlayerScale") or A.PlayerDisplayName("player"))
    if personal then A.PlayerHeading(f,f.name,f.level,"player")
    elseif not mode.npc then A.PlayerHeading(f,f.name,f.level,nil,mode.guild,mode.key=="enemyPlayerScale")
    else
        A.LayoutName(f,f.name,f.level,false)
        if f.guild then f.guild:Hide() end
    end
    if personal then f.name:SetTextColor(1,1,1) else f.name:SetTextColor(color(f.quest and A.db.questTint and "quest" or mode.reaction)) end
    setLevel(f.level,personal and UnitLevel("player") or 34)
    if personal then f.level:SetShown(A.db.personalLevel) end
    f.distance:SetShown(not personal and A.db.showDistance or false)
    f.distance:SetText("32.5 yd") -- Illustrative distance on the simulated plate.
    A.SetHealthLabel(f.value,345,548)
    f.health:SetMinMaxValues(0,548)
    f.health:SetValue(345)
    if mode.npc then
        f.health:SetStatusBarColor(color(f.quest and A.db.questTint and "quest" or A.previewColor or mode.reaction))
        A.Badge(f,nil,f.name)
        f.power:Hide()
    else
        local unit="player"
        if not personal and UnitExists("target") and UnitIsPlayer("target")
            and (not not friendlyPlayer("target"))==(mode.reaction=="friendly") then unit="target" end
        local _,class=UnitClass(unit)
        local tint=readable(class) and RAID_CLASS_COLORS[class]
        if tint then f.health:SetStatusBarColor(tint.r,tint.g,tint.b) else f.health:SetStatusBarColor(color(mode.reaction)) end
        A.Badge(f,unit,f.name,mode.key=="enemyPlayerScale")
        power(f,unit,mode.key=="enemyPlayerScale",personal,not personal)
    end
    local now=GetTime()
    f.cast.start,f.cast.finish=now,now+4
    f.cast:SetMinMaxValues(0,4)
    f.cast:SetHeight(A.db.castHeight or 14)
    f.castTime:SetShown(A.db.castTimer~=false)
    f.cast:SetStatusBarColor(color("castColor"))
    f.castText:SetText("Frostbolt")
    f.cast:SetShown(A.PlateOption(f,"casts"))
    auras(f,nil,{
        {helpful=true,canApplyAura=true,spellId=1459,name="Arcane Intellect",icon=135932,duration=12,expirationTime=now+12},
        {spellId=1822,name="Rake",icon=132152,duration=8,expirationTime=now+8},
        {spellId=122,icon=135848,duration=6,expirationTime=now+6}
    })
end
function A.DrawAuraExample(parent)
    if not parent.sample then
        parent.sample=create(parent)
        parent:SetScript("OnUpdate",function(frame,elapsed)
            frame.exampleElapsed=(frame.exampleElapsed or 0)+elapsed
            if frame.exampleElapsed>=3.8 then
                frame.exampleElapsed=0
                A.DrawAuraExample(frame)
            end
        end)
    end
    local category=parent.category
    local mode=A.previewModes[1]
    if category=="Players" then mode=A.previewModes[A.db.previewEnemyPlayer and 4 or 3]
    elseif category=="Text" and A.db.wrapNames then
        mode={key="enemyNPCScale",name="Bloodscalp Witch Doctor",reaction="hostile",npc=true}
    elseif category=="Personal" then mode=A.previewModes[5]
    elseif category=="Quests" then
        mode={key="enemyNPCScale",name="Quest objective",reaction="hostile",npc=true,objective=true}
    elseif category=="NPCs" and A.db.previewFriendlyNPC then mode=A.previewModes[2] end
    drawSample(parent.sample,mode,category=="Targeting")
    local scale=parent.sample:GetScale()*UIParent:GetEffectiveScale()/parent:GetEffectiveScale()
    parent.sample:SetScale(scale)
end
local function refreshPreview()
    if not A.db.preview then
        if preview then preview:Hide() end
        return
    end
    if not preview then
        preview=CreateFrame("Frame",nil,UIParent)
        preview:SetFrameStrata("DIALOG")
        preview:SetPoint("CENTER",UIParent,"CENTER",0,65)
        preview:SetMovable(true)
        preview:SetClampedToScreen(true)
        preview.samples={}
        for i=1,7 do
            local sample=create(preview)
            preview.samples[i]=sample
            sample:EnableMouse(true)
            sample:RegisterForDrag("LeftButton")
            sample:SetScript("OnDragStart",function() preview:StartMoving() end)
            sample:SetScript("OnDragStop",function() preview:StopMovingOrSizing() end)
        end
        preview:SetScript("OnUpdate",function(frame,elapsed)
            frame.elapsed=(frame.elapsed or 0)+elapsed
            if frame.elapsed>=4 then frame.elapsed=0; refreshPreview() end
        end)
    end
    preview:Show()

    local modes={
        A.previewModes[A.db.previewFriendlyNPC and 2 or 1],
        A.previewModes[3], A.previewModes[4],
        A.previewModes[5],
        {key="enemyNPCScale",name="Quest objective",npc=true,reaction="hostile",objective=true},
        {name="Xan'tish",title="Snake Vendor",objective=true,service="Interface\\GossipFrame\\VendorGossipIcon",dialogQuest="offer"},
        {name="Uthel'nay",title="Mage Trainer",service="Interface\\GossipFrame\\TrainerGossipIcon",dialogQuest="turnin"}
    }
    local heights={0,0}
    local width=0
    for index,mode in ipairs(modes) do
        drawSample(preview.samples[index],mode)
        width=math.max(width,240*preview.samples[index]:GetScale())
    end
    for index,mode in ipairs(modes) do
        local sample=preview.samples[index]
        local scale=sample:GetScale()
        sample:ClearAllPoints()
        local column=index<=4 and 1 or 2
        sample:SetPoint("TOP",preview,"TOP",(column==1 and -1 or 1)*width/scale/2,-heights[column]/scale-23)
        local auraHeight=34*(A.db.auraScale or 100)/100
        heights[column]=heights[column]+(mode.service and 52 or (55+(A.db.buffs and auraHeight or 0)+(A.db.casts and 16 or 0)+auraHeight))*scale
        width=math.max(width,220*scale)
    end
    preview:SetSize(2*width,math.max(heights[1],heights[2]))
end
local function applyCVar(key, saved, enabled, value)
    local db=A.db
    local current=GetCVar(key)
    if current==nil then return end
    if enabled then
        if db[saved]==nil then db[saved]=current end
        if current~=value then SetCVar(key,value) end
    elseif db[saved]~=nil then
        SetCVar(key,db[saved])
        db[saved]=nil
    end
end
local function applyCompanionCVars(enabled)
    for _,kind in ipairs({"Pets","Minions","Guardians"}) do
        local current="nameplateShowFriendlyPlayer"..kind
        local legacy="nameplateShowFriendly"..kind
        local supported=GetCVar(current)~=nil
        -- Restore any legacy override from 1.4.41 when the client has the player-specific setting.
        applyCVar(legacy,"oldFriendly"..kind,enabled and not supported,"1")
        if supported then applyCVar(current,"oldFriendlyPlayer"..kind,enabled,"1") end
    end
end
function A.RefreshWorld()
    refreshPreview()
    for u,f in pairs(active) do refresh(f,u) end
    if InCombatLockdown() then return end
    local db=A.db
    applyCompanionCVars(db.compactCompanions)
    applyCVar("nameplateShowFriendlyNpcs","oldFriendlyNPCs",db.townPlates,"1")
    applyCVar("nameplateShowAll","oldAlwaysShow",db.townPlates,"1")
    applyCVar("UnitNameOwn","oldName",db.hideName and db.personal,"0")
    applyCVar("UnitNamePlayerGuild","oldGuild",db.hideGuild and db.personal,"0")
    applyCVar("nameplateShowSelf","oldSelf",db.native and db.personal,"1")
end
function A.SetBuffOption(key,enabled)
    A.db[key]=enabled
    if key=="castableBuffs" and enabled then A.db.buffs=true end
    if key=="buffs" and not enabled then A.db.castableBuffs=false end
end
-- The slider uses the Forever client default as its upper endpoint.
function A.DistanceLimit()
    local default=(C_CVar and C_CVar.GetCVarDefault or GetCVarDefault)
    local yards=default and tonumber(default("nameplateMaxDistance"))
    return yards and yards>=1 and yards<=100 and math.floor(yards) or 45
end
function A.ClampDistance(value)
    return math.min(A.DistanceLimit(),math.max(1,math.floor(tonumber(value) or A.DistanceLimit())))
end
local distancePending=false
function A.ApplyNativeDistance(value)
    distancePending=InCombatLockdown()
    if distancePending then return end
    for _,key in ipairs({"nameplateMaxDistance","nameplatePlayerMaxDistance"}) do
        if GetCVar(key)~=nil then pcall(SetCVar,key,value) end
    end
end
function A.InitWorld()
    local register = C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix or RegisterAddonMessagePrefix
    if register then
        register(threatPrefix)
        shareThreat = C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
        events:RegisterEvent("CHAT_MSG_ADDON")
    end
    if A.db.viewDistance~=nil then
        A.db.viewDistance=A.ClampDistance(A.db.viewDistance)
        A.ApplyNativeDistance(A.db.viewDistance)
    end
    if not A.distanceTicker then
        C_Timer.NewTicker(.5,function()
            for token,frame in pairs(active) do
                if not frame.objectOnly and not UnitIsPlayer(token) and UnitAffectingCombat(token) then paint(frame,token) end
            end
        end)
        A.distanceTicker=C_Timer.NewTicker(.2,function()
            if (A.db.viewDistance or A.db.showDistance) and next(active) then A.RefreshPlateDistances() end
        end)
    end
    A.UpdateQuestTitles()
    if A.db.castableBuffs and A.db.buffs==false then
        A.SetBuffOption("castableBuffs",true)
    end
    for _,group in ipairs(A.scaleGroups) do
        local key=group[1]
        if A.db[key]==nil then A.db[key]=key=="targetScale" and 120 or 80 end
    end
    for k,v in pairs({showThreat=false,threatPosition="Right of bar",questTint=true,questIcon=true,quest="FFBE32",townPlates=true,hideIdleNPCs=true,compactCompanions=true,showCompanionText=true,compactFriendly=true,previewTarget=true,targetOutline=true,auraScale=100,power=true,buffs=true,casts=true,castTimer=true,castHeight=14,debuffs=true,hideName=false,hostile="CC0613",neutral="FFEB2B",friendly="70FF90",aggro="CC0613",pulling="FFEB2B",partyAggro="56A8FF",safe="C7CFD9",castColor="903BCC"}) do
        if A.db[k]==nil then A.db[k]=v end
    end
    for _,e in ipairs({"UNIT_TARGET","GROUP_ROSTER_UPDATE","PLAYER_GUILD_UPDATE","GOSSIP_SHOW","QUEST_DETAIL","QUEST_PROGRESS","QUEST_COMPLETE","QUEST_LOG_UPDATE","UNIT_POWER_UPDATE","UNIT_MAXPOWER","UNIT_DISPLAYPOWER","NAME_PLATE_UNIT_ADDED","NAME_PLATE_UNIT_REMOVED","PLAYER_TARGET_CHANGED","UNIT_HEALTH","UNIT_MAXHEALTH","UNIT_NAME_UPDATE","UNIT_FACTION","UNIT_FLAGS","UNIT_AURA","UNIT_THREAT_LIST_UPDATE","UNIT_THREAT_SITUATION_UPDATE","UNIT_SPELLCAST_START","UNIT_SPELLCAST_STOP","UNIT_SPELLCAST_FAILED","UNIT_SPELLCAST_INTERRUPTED","UNIT_SPELLCAST_DELAYED","UNIT_SPELLCAST_CHANNEL_START","UNIT_SPELLCAST_CHANNEL_UPDATE","UNIT_SPELLCAST_CHANNEL_STOP","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED"}) do events:RegisterEvent(e) end
    if C_NamePlate then
        for _,plate in ipairs(C_NamePlate.GetNamePlates()) do
            if not plate:IsForbidden() then attach(plate.namePlateUnitToken) end
        end
    end
end
events:SetScript("OnEvent",function(_,e,u,...)
    if e=="CHAT_MSG_ADDON" then receiveThreat(u,...); return end
    if e=="GROUP_ROSTER_UPDATE" or e=="PLAYER_REGEN_ENABLED" then wipe(reports); wipe(lastSent) end
    if e=="PLAYER_REGEN_ENABLED" and distancePending then A.ApplyNativeDistance(A.db.viewDistance) end
    if e=="GOSSIP_SHOW" or e=="QUEST_DETAIL" or e=="QUEST_PROGRESS" or e=="QUEST_COMPLETE" then
        A.ObserveConversation(e)
        e="QUEST_LOG_UPDATE"
    end
    if e=="GROUP_ROSTER_UPDATE" then A.RefreshWorld(); return end
    if e=="PLAYER_GUILD_UPDATE" then A.Refresh(); return end
    if e=="QUEST_LOG_UPDATE" then
        if not A.questRefreshPending then
            A.questRefreshPending=true
            C_Timer.After(.2,function()
                A.questRefreshPending=false
                A.UpdateQuestTitles()
                for token,frame in pairs(active) do frame.quest=nil; refresh(frame,token) end
            end)
        end
    elseif e=="UNIT_THREAT_LIST_UPDATE" or e=="UNIT_THREAT_SITUATION_UPDATE" then
        if active[u] then
            if not active[u].objectOnly then paint(active[u],u) end
        else
            for token,frame in pairs(active) do
                if not frame.objectOnly and (not u or u=="player" or UnitIsUnit(u,token)) then paint(frame,token) end
            end
        end
    elseif e=="NAME_PLATE_UNIT_ADDED" then
        if UnitIsUnit(u,"player") then A.Refresh() else attach(u) end
    elseif e=="NAME_PLATE_UNIT_REMOVED" then
        detach(u)
        if personalOwner.native and personalOwner.native.unit==u then A.BindPersonal(nil,false) end
    elseif e=="PLAYER_TARGET_CHANGED" or e:find("PLAYER_REGEN") then A.RefreshWorld()
    elseif u=="player" and A.personalFrame and e:find("POWER") then power(A.personalFrame,u,false,true)
    elseif u=="player" and A.personalFrame and (e=="UNIT_AURA" or e:find("SPELLCAST")) then
        if e=="UNIT_AURA" then auras(A.personalFrame,u) else cast(A.personalFrame,u) end
    elseif e=="UNIT_AURA" and u=="target" then
        for token,frame in pairs(active) do
            if UnitIsUnit(token,"target") then if not frame.objectOnly then auras(frame,token) end; break end
        end
    elseif active[u] then
        local f=active[u]
        if e=="UNIT_NAME_UPDATE" or e=="UNIT_FLAGS" or e=="UNIT_FACTION" then
            f.quest=nil
            f.serviceChecked=false
        end
        if f.npcInCombat~=(not not UnitAffectingCombat(u)) then
            refresh(f,u)
        elseif f.objectOnly then
            if e=="UNIT_NAME_UPDATE" or e=="UNIT_FLAGS" or e=="UNIT_FACTION" or e:find("HEALTH") then refresh(f,u) end
        elseif e:find("POWER") then power(f,u)
        elseif e=="UNIT_AURA" then auras(f,u)
        elseif e:find("SPELLCAST") then cast(f,u)
        elseif e:find("HEALTH") then health(f,u)
        elseif e=="UNIT_FACTION" or e=="UNIT_FLAGS" then refresh(f,u)
        elseif e=="UNIT_NAME_UPDATE" then refresh(f,u)
        else paint(f,u) end
    end
end)


