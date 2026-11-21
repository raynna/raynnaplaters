local _, A = ...
local active, pool = {}, {}
local function readable(v)
    return not (issecretvalue and issecretvalue(v))
end
local function text(parent, size)
    local f = parent:CreateFontString(nil, "OVERLAY")
    f:SetFont("Interface\\AddOns\\RaynnaNameplates\\Ubuntu-Bold.ttf", size, "OUTLINE")
    f:SetShadowOffset(1, -1)
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
    f.castText, f.castTime = text(f.cast,11), text(f.cast,11)
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
local function power(f,unit)
    if not A.db.power or not UnitIsPlayer(unit) then f.power:Hide(); return end
    local kind, token = UnitPowerType(unit)
    if not readable(kind) then f.power:Hide(); return end
    local maximum = UnitPowerMax(unit,kind)
    if readable(maximum) and (not maximum or maximum<=0) then f.power:Hide(); return end
    local c = PowerBarColor and ((readable(token) and PowerBarColor[token]) or PowerBarColor[kind])
    f.power:SetStatusBarColor(c and c.r or .22,c and c.g or .5,c and c.b or 1)
    f.power:SetMinMaxValues(0,maximum)
    f.power:SetValue(UnitPower(unit,kind))
    f.power:Show()
end
-- The four mirrored corners use the same client artwork as Plater's Pins style.
local function selectPlate(f, selected)
    if f.targetGlow then f.targetGlow:SetShown(selected and A.db.targetOutline) end
    if not selected or not A.db.targetOutline then
        if f.selection then f.selection:Hide() end
        return
    end
    if not f.selection then
        local glow=f:CreateTexture(nil,"BACKGROUND")
        glow:SetTexture("Interface\\AddOns\\RaynnaNameplates\\TargetGlow")
        glow:SetPoint("TOPLEFT",f,-20,38)
        glow:SetPoint("BOTTOMRIGHT",f,20,-20)
        f.targetGlow=glow
        local rim = CreateFrame("Frame",nil,f,"BackdropTemplate")
        rim:SetPoint("TOPLEFT",f,-4,4)
        rim:SetPoint("BOTTOMRIGHT",f,4,-4)
        rim:SetFrameLevel(f:GetFrameLevel()+4)
        for n=1,3 do
            local ring=CreateFrame("Frame",nil,rim,"BackdropTemplate")
            ring:SetPoint("TOPLEFT",f,-n,n)
            ring:SetPoint("BOTTOMRIGHT",f,n,-n)
            ring:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
            ring:SetBackdropBorderColor(1,.84,.38,({.95,.45,.17})[n])
        end
        for i,corner in ipairs({"TOPLEFT","BOTTOMLEFT","BOTTOMRIGHT","TOPRIGHT"}) do
            local left=i<=2
            local top=i==1 or i==4
            local pin=rim:CreateTexture(nil,"OVERLAY")
            pin:SetTexture("Interface\\ITEMSOCKETINGFRAME\\UI-ItemSockets")
            pin:SetTexCoord((left and 145 or 161)/256,(left and 161 or 145)/256,
                (top and 3 or 19)/256,(top and 19 or 3)/256)
            pin:SetDesaturated(true)
            pin:SetSize(6,6)
            pin:SetPoint("CENTER",f,corner,0,0)
        end
        f.selection=rim
    end
    f.selection:Show()
end
local function create(plate)
    local f = CreateFrame("Frame", nil, plate)
    f:SetPoint("CENTER")
    f:SetSize(162,18)
    f.health = bar(f,18)
    f.health:SetAllPoints()
    f.name, f.level, f.value = text(f,15), text(f,14), text(f.health,13)
    f.name:SetWidth(132)
    f.name:SetWordWrap(false)
    f.name:SetJustifyH("LEFT")
    f.name:SetPoint("BOTTOMLEFT", f,"TOPLEFT",0,2)
    f.level:SetPoint("BOTTOMRIGHT",f,"TOPRIGHT",0,2)
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
local function paint(f,u)
    local reaction = UnitReaction(u,"player")
    if not readable(reaction) then reaction=nil end
    local key = reaction and reaction <= 3 and "hostile" or reaction == 4 and "neutral" or "friendly"
    if UnitIsPlayer(u) then key=friendlyPlayer(u) and "friendly" or "hostile" end
    f.name:SetTextColor(color(key))
    if UnitIsPlayer(u) then
        local _, class = UnitClass(u)
        local c = readable(class) and RAID_CLASS_COLORS[class]
        if c then f.health:SetStatusBarColor(c.r,c.g,c.b) return end
    elseif key ~= "friendly" and UnitAffectingCombat(u) then
        local t = UnitThreatSituation("player",u)
        if readable(t) then
            key = t and t >= 2 and "aggro" or t == 1 and "pulling" or "safe"
        end
    end
    f.health:SetStatusBarColor(color(key))
end
local function cast(f,u)
    local n,desc,icon,s,e = UnitCastingInfo(u)
    local channel = false
    if not n then n,desc,icon,s,e = UnitChannelInfo(u); channel = true end
    if not A.db.casts or not n or not readable(s) or not readable(e) or not s or not e then
        f.cast:Hide()
        return
    end
    f.cast.start, f.cast.finish, f.cast.channel = s/1000,e/1000,channel
    f.cast:SetMinMaxValues(0,(e-s)/1000)
    f.cast:SetStatusBarColor(color("castColor"))
    f.castText:SetText(n)
    f.cast:Show()
end
local cc = {[122]=true,[865]=true,[6131]=true,[10230]=true,[118]=true,[853]=true,[408]=true,[339]=true}
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
local function nativeAuras(f,u,enabled)
    local supported=false
    if enabled and u and C_XMLUtil and C_XMLUtil.GetTemplateInfo then
        local ok,template=pcall(C_XMLUtil.GetTemplateInfo,"CustomAuraContainerTemplate")
        supported=ok and template~=nil
    end
    f.auraLayouts=f.auraLayouts or {}
    local buffFilter=A.db.castableBuffs and "HELPFUL|PLAYER" or "HELPFUL"
    for filter,container in pairs(f.auraLayouts) do
        if not supported or not ((A.db.debuffs and filter=="HARMFUL|PLAYER") or (A.db.buffs and filter==buffFilter)) then
            container:SetEnabled(false)
            container:Hide()
        end
    end
    if not supported then return false end
    local function display(filter,helpful)
        local container=f.auraLayouts[filter]
        if not container then
        container=CreateFrame("AuraContainer",nil,f,"CustomAuraContainerTemplate")
        container:SetSize(1,1)
        container:SetFlowLayoutAnchorPoint("TOPLEFT")
        container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right,AnchorUtil.FlowDirection.Down)
        container:SetFlowLayoutMaximumLineSize(126)
        local formatter=C_StringUtil.CreateNumericRuleFormatter()
        formatter:AddBreakpoint({threshold=0,step=1,format="%d"})
        formatter:AddBreakpoint({threshold=60,step=60,format=""})
        local function add(key,filter)
            container:AddAuraGroup(key,filter,{
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
                    local timer=text(button,10)
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
        add(helpful and "buffs" or "debuffs",filter)
        f.auraLayouts[filter]=container
        end
        local scale=(A.db.auraScale or 100)/100
        container:SetScale(scale)
        container:ClearAllPoints()
        if helpful then container:SetPoint("TOPLEFT",f,"TOPLEFT",0,19/scale+34)
        else container:SetPoint("TOPLEFT",f.auraAnchor,"TOPLEFT") end
        container:SetUnit(u)
        container:SetEnabled(true)
        container:Show()
    end
    if A.db.debuffs then display("HARMFUL|PLAYER",false) end
    if A.db.buffs then display(buffFilter,true) end
    return true
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
    if u and u~="player" and UnitIsUnit(u,"target") then u="target" end
    local native = nativeAuras(f,u,not samples and C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret())
    if not native and (samples or C_UnitAuras) then
        for _,filter in ipairs(A.db.castableBuffs and castableAuras or allAuras) do
        local helpfulQuery=filter:sub(1,7)=="HELPFUL"
        if samples or (not helpfulQuery and A.db.debuffs) or (helpfulQuery and A.db.buffs) then
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
            if (not unique or not seen[unique]) and ((helpful and top<6 and A.db.buffs and (not A.db.castableBuffs or canApply(a,query))) or (not helpful and bottom+side<6 and A.db.debuffs)) then
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
                box.timer=text(box,11)
                box.timer:SetPoint("TOP",box,"BOTTOM",0,-1)
                f.icons[count]=box
            end
            local size=math.floor(21*(A.db.auraScale or 100)/100+.5)
            box:SetSize(size,size)
            box.timer:SetFont("Interface\\AddOns\\RaynnaNameplates\\Ubuntu-Bold.ttf",math.max(6,math.floor(size*.42)),"OUTLINE")
            box.timer:SetWidth(0)
            local cellWidth=size
            box.timer:SetWordWrap(false)
            box:ClearAllPoints()
            if helpful then
                box:SetPoint("BOTTOMLEFT",f,"TOPLEFT",top*cellWidth,20+math.ceil(size*.6))
                top=top+1
            elseif readable(a.spellId) and cc[a.spellId] then
                box:SetPoint("LEFT",f,"RIGHT",4+side*cellWidth,0)
                box.rim:SetColorTexture(.95,.15,.19,1)
                side=side+1
            else
                box:SetPoint("TOPLEFT",f.auraAnchor,"TOPLEFT",bottom*cellWidth,0)
                box.rim:SetColorTexture(.95,.15,.19,1)
                bottom=bottom+1
            end
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
    for i=count+1,#f.icons do f.icons[i]:Hide() end
end
function A.PersonalIndicators(frame)
    if not frame.cast then A.AddIndicators(frame) end
    A.personalFrame=frame
    power(frame,"player")
    cast(frame,"player")
    auras(frame,"player")
end
local function health(f,u)
    local hp,max = UnitHealth(u),UnitHealthMax(u)
    f.health:SetMinMaxValues(0,max)
    f.health:SetValue(hp)
    if readable(hp) and readable(max) and max>0 then
        f.value:SetFormattedText("%d (%d%%)",hp,math.floor(100*hp/max+.5))
    else if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
            f.value:SetFormattedText("%d (%d%%)", hp, UnitHealthPercent(u, true, CurveConstants.ScaleTo100))
        else
            f.value:SetText(hp)
        end end
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
        f.objectLabel=text(f,14)
        f.objectLabel:SetPoint("CENTER")
        f.objectLabel:SetTextColor(.72,.93,1)
        f.objectIcon=f:CreateTexture(nil,"ARTWORK")
        f.objectIcon:SetSize(17,17)
        f.objectIcon:SetPoint("RIGHT",f.objectLabel,"LEFT",-4,0)
    end
    local name=UnitName(u)
    f.objectLabel:SetText(name)
    local portal=readable(name) and name and name:lower():find("portal",1,true)
    f.objectIcon:SetTexture(portal and "Interface\\Icons\\Spell_Arcane_PortalUndercity" or "Interface\\Icons\\INV_Misc_Spyglass_03")
    f.objectIcon:Show()
    f.objectLabel:Show()
end
local function refresh(f,u)
    f.objectOnly=isWorldObject(u)
    selectPlate(f,not f.objectOnly and UnitIsUnit(u,"target"))
    f.health:SetShown(not f.objectOnly)
    f.name:SetShown(not f.objectOnly)
    f.level:SetShown(not f.objectOnly)
    if f.objectOnly then
        f:SetScale(.94*groupScale("friendlyNPCScale"))
        A.Badge(f,nil,f.name)
        f.power:Hide()
        f.cast:Hide()
        nativeAuras(f,nil,false)
        for _,icon in ipairs(f.icons) do icon:Hide() end
        objectLabel(f,u)
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
    f.name:SetText(UnitName(u))
    local lvl=UnitLevel(u)
    f.level:SetText(readable(lvl) and lvl == -1 and "??" or lvl)
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
local function attach(u)
    if Plater or not u or UnitIsUnit(u,"player") then return end
    local plate=C_NamePlate.GetNamePlateForUnit(u)
    if not plate or plate:IsForbidden() then return end
    local f=pool[plate] or create(plate)
    if active[u] and active[u]~=f then detach(u) end
    if f.unit and f.unit~=u then detach(f.unit) end
    pool[plate],active[u],f.unit=f,f,u
    bind(f,plate)
    C_Timer.After(0,function()
        if active[u]==f then bind(f,plate) end
    end)
    f:Show()
    refresh(f,u)
end
local events=CreateFrame("Frame")
local preview
A.previewModes = {
    {key="enemyNPCScale", title="Hostile NPC", name="Kolkar Stormer", reaction="hostile", npc=true},
    {key="friendlyNPCScale", title="Friendly NPC", name="Crossroads Guard", reaction="friendly", npc=true},
    {key="friendlyPlayerScale", title="Friendly player", name="Friendly adventurer", reaction="friendly"},
    {key="enemyPlayerScale", title="Enemy player", name="Enemy adventurer", reaction="hostile"},
    {key="personal", title="Personal", reaction="friendly"}
}
function A.PreviewMode()
    for index,mode in ipairs(A.previewModes) do
        if mode.key==A.db.previewMode then return mode,index end
    end
    return A.previewModes[1],1
end
local function drawSample(f,mode)
    local personal=mode.key=="personal"
    local target=not personal and A.db.previewTarget
    selectPlate(f,target)
    f:SetScale(personal and A.db.scale/100 or .94*groupScale(mode.key)*(target and groupScale("targetScale") or 1))
    f.name:SetText(mode.name or UnitName("player"))
    if personal then f.name:SetTextColor(1,1,1) else f.name:SetTextColor(color(mode.reaction)) end
    f.level:SetText(personal and UnitLevel("player") or "34")
    f.value:SetText("345 (63%)")
    f.health:SetMinMaxValues(0,100)
    f.health:SetValue(63)
    if mode.npc then
        f.health:SetStatusBarColor(color(A.previewColor or mode.reaction))
        A.Badge(f,nil,f.name)
        f.power:Hide()
    else
        local unit="player"
        if not personal and UnitExists("target") and UnitIsPlayer("target")
            and (not not friendlyPlayer("target"))==(mode.reaction=="friendly") then unit="target" end
        local _,class=UnitClass(unit)
        local tint=readable(class) and RAID_CLASS_COLORS[class]
        if tint then f.health:SetStatusBarColor(tint.r,tint.g,tint.b) else f.health:SetStatusBarColor(color(mode.reaction)) end
        A.Badge(f,unit,f.name)
        power(f,unit)
    end
    local now=GetTime()
    f.cast.start,f.cast.finish=now,now+4
    f.cast:SetMinMaxValues(0,4)
    f.cast:SetStatusBarColor(color("castColor"))
    f.castText:SetText("Frostbolt")
    f.cast:SetShown(A.db.casts)
    auras(f,nil,{
        {helpful=true,spellId=1459,name="Arcane Intellect",icon=135932,duration=12,expirationTime=now+12},
        {spellId=1822,name="Rake",icon=132152,duration=8,expirationTime=now+8},
        {spellId=122,icon=135848,duration=6,expirationTime=now+6}
    })
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
        for i=1,4 do
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
        A.previewModes[5]
    }
    local height,width=0,0
    for index,mode in ipairs(modes) do
        local sample=preview.samples[index]
        drawSample(sample,mode)
        local scale=sample:GetScale()
        sample:ClearAllPoints()
        sample:SetPoint("TOP",preview,"TOP",0,-height/scale-23)
        local auraHeight=34*(A.db.auraScale or 100)/100
        height=height+(55+(A.db.buffs and auraHeight or 0)+(A.db.casts and 16 or 0)+auraHeight)*scale
        width=math.max(width,220*scale)
    end
    preview:SetSize(width,height)
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
function A.RefreshWorld()
    refreshPreview()
    for u,f in pairs(active) do refresh(f,u) end
    if InCombatLockdown() then return end
    local db=A.db
    applyCVar("UnitNameOwn","oldName",db.hideName and db.personal,"0")
    applyCVar("UnitNamePlayerGuild","oldGuild",db.hideGuild and db.personal,"0")
    applyCVar("nameplateShowSelf","oldSelf",db.native and db.personal,"1")
end
function A.SetBuffOption(key,enabled)
    A.db[key]=enabled
    if key=="castableBuffs" and enabled then A.db.buffs=true end
    if key=="buffs" and not enabled then A.db.castableBuffs=false end
end
function A.InitWorld()
    if A.db.castableBuffs and A.db.buffs==false then
        A.SetBuffOption("castableBuffs",true)
    end
    for _,group in ipairs(A.scaleGroups) do
        local key=group[1]
        if A.db[key]==nil then A.db[key]=key=="targetScale" and 120 or 80 end
    end
    for k,v in pairs({previewTarget=true,targetOutline=true,auraScale=100,power=true,buffs=true,casts=true,debuffs=true,hideName=false,hostile="CC0613",neutral="FFEB2B",friendly="70FF90",aggro="CC0613",pulling="FFEB2B",safe="C7CFD9",castColor="903BCC"}) do
        if A.db[k]==nil then A.db[k]=v end
    end
    for _,e in ipairs({"UNIT_POWER_UPDATE","UNIT_MAXPOWER","UNIT_DISPLAYPOWER","NAME_PLATE_UNIT_ADDED","NAME_PLATE_UNIT_REMOVED","PLAYER_TARGET_CHANGED","UNIT_HEALTH","UNIT_MAXHEALTH","UNIT_NAME_UPDATE","UNIT_FACTION","UNIT_FLAGS","UNIT_AURA","UNIT_THREAT_LIST_UPDATE","UNIT_THREAT_SITUATION_UPDATE","UNIT_SPELLCAST_START","UNIT_SPELLCAST_STOP","UNIT_SPELLCAST_FAILED","UNIT_SPELLCAST_INTERRUPTED","UNIT_SPELLCAST_DELAYED","UNIT_SPELLCAST_CHANNEL_START","UNIT_SPELLCAST_CHANNEL_UPDATE","UNIT_SPELLCAST_CHANNEL_STOP","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED"}) do events:RegisterEvent(e) end
    if C_NamePlate then
        for _,plate in ipairs(C_NamePlate.GetNamePlates()) do
            if not plate:IsForbidden() then attach(plate.namePlateUnitToken) end
        end
    end
end
events:SetScript("OnEvent",function(_,e,u)
    if e=="NAME_PLATE_UNIT_ADDED" then
        if UnitIsUnit(u,"player") then A.Refresh() else attach(u) end
    elseif e=="NAME_PLATE_UNIT_REMOVED" then
        detach(u)
        if personalOwner.native and personalOwner.native.unit==u then A.BindPersonal(nil,false) end
    elseif e=="PLAYER_TARGET_CHANGED" or e:find("PLAYER_REGEN") then A.RefreshWorld()
    elseif u=="player" and A.personalFrame and e:find("POWER") then power(A.personalFrame,u)
    elseif u=="player" and A.personalFrame and (e=="UNIT_AURA" or e:find("SPELLCAST")) then
        if e=="UNIT_AURA" then auras(A.personalFrame,u) else cast(A.personalFrame,u) end
    elseif e=="UNIT_AURA" and u=="target" then
        for token,frame in pairs(active) do
            if UnitIsUnit(token,"target") then if not frame.objectOnly then auras(frame,token) end; break end
        end
    elseif active[u] then
        local f=active[u]
        if f.objectOnly then
            if e=="UNIT_NAME_UPDATE" or e=="UNIT_FLAGS" or e=="UNIT_FACTION" or e:find("HEALTH") then refresh(f,u) end
        elseif e:find("POWER") then power(f,u)
        elseif e=="UNIT_AURA" then auras(f,u)
        elseif e:find("SPELLCAST") then cast(f,u)
        elseif e:find("HEALTH") then health(f,u)
        elseif e=="UNIT_FACTION" or e=="UNIT_FLAGS" then refresh(f,u)
        elseif e=="UNIT_NAME_UPDATE" then f.name:SetText(UnitName(u))
        else paint(f,u) end
    end
end)


