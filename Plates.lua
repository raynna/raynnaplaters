local _, A = ...
local player = CreateFrame("Frame", nil, UIParent)
player:SetSize(162, 18)
player:Hide()
local plateFonts = {
    ["Ubuntu Bold"] = "Interface\\AddOns\\RaynnaNameplates\\Ubuntu-Bold.ttf",
    ["Lilita One"] = "Interface\\AddOns\\RaynnaNameplates\\Fonts\\LilitaOne.ttf",
    ["Barlow SemiBold"] = "Interface\\AddOns\\RaynnaNameplates\\Fonts\\Barlow-SemiBold.ttf",
    ["Lato Bold"] = "Interface\\AddOns\\RaynnaNameplates\\Fonts\\Lato-Bold.ttf",
    ["PT Serif Bold"] = "Interface\\AddOns\\RaynnaNameplates\\Fonts\\PT_Serif-Web-Bold.ttf",
    ["Space Mono Bold"] = "Interface\\AddOns\\RaynnaNameplates\\Fonts\\SpaceMono-Bold.ttf",
    ["Morpheus"] = "Fonts\\MORPHEUS.TTF",
    ["Skurri"] = "Fonts\\skurri.ttf",
    ["Game font"] = STANDARD_TEXT_FONT,
    ["Damage font"] = DAMAGE_TEXT_FONT,
}
local fontSizes = setmetatable({}, {__mode = "k"})
A.TextRoles = {
    {"nameText","Character name"}, {"guildText","Guild name"}, {"levelText","Level"},
    {"healthText","Health value"}, {"distanceText","Distance"}, {"castText","Cast name and time"},
    {"auraText","Aura timers"}, {"serviceText","NPC service title"},
}
local outlines={Normal="OUTLINE", Thick="THICKOUTLINE", None=""}
function A.SetPlateFont(text,size)
    local db=A.db or {}
    local face=plateFonts[db.plateFont] or plateFonts["Ubuntu Bold"]
    local roleScale=db[text.rnpRole] or 100
    local pixels=math.max(1,math.floor(size*(db.textScale or 100)*roleScale/10000+.5))
    local outline=outlines[db.textOutline] or "OUTLINE"
    local shadow=db.textShadow~=false
    if text.rnpFont~=face or text.rnpPixels~=pixels or text.rnpOutline~=outline then
        if text:SetFont(face,pixels,outline)==false then text:SetFont(plateFonts["Ubuntu Bold"],pixels,outline) end
        text.rnpFont,text.rnpPixels,text.rnpOutline=face,pixels,outline
    end
    if text.rnpShadow~=shadow then
        text:SetShadowOffset(shadow and 1 or 0,shadow and -1 or 0)
        text.rnpShadow=shadow
    end
    fontSizes[text]=size
end
function A.RefreshFonts()
    for text,size in pairs(fontSizes) do A.SetPlateFont(text,size) end
end
local function label(parent,size,role)
    local text=parent:CreateFontString(nil,"OVERLAY")
    text.rnpRole=role
    A.SetPlateFont(text,size)
    return text
end
local playerOptions = {"showSurname","showGuild","guildPosition","guildStyle","power","powerHeight","powerValue","powerFormat","badges","spec","iconSize"}
function A.PlayerOptionKey(key,enemy)
    if enemy then return "enemy"..key:sub(1,1):upper()..key:sub(2) end
    return key
end
function A.InitEnemyOptions(db)
    for _,key in ipairs(playerOptions) do
        local enemyKey=A.PlayerOptionKey(key,true)
        if db[enemyKey]==nil then db[enemyKey]=db[key] end
    end
end
function A.IsEnemyPlayer(unit)
    return unit and UnitIsPlayer(unit) and not (UnitIsFriend("player",unit) and not UnitCanAttack("player",unit))
end
function A.FormatPlayerName(first,last,enemy)
    if A.db[A.PlayerOptionKey("showSurname",enemy)]==false then return first end
    if issecretvalue and (issecretvalue(first) or issecretvalue(last)) then return first end
    if first and last and last~="" then
        local separator=Constants and Constants.CharacterNameSeparatorConsts
        return first..(separator and separator.CHARACTERNAME_SURNAME_SEPARATOR or " ")..last
    end
    return first
end
function A.PlayerDisplayName(unit)
    local first,last=UnitName(unit)
    return A.FormatPlayerName(first,last,A.IsEnemyPlayer(unit))
end
function A.LayoutName(owner,nameText,levelText,isPlayer)
    local wrap=A.db.wrapNames==true
    nameText:ClearAllPoints()
    nameText:SetWordWrap(wrap)
    nameText:SetHeight(0)
    nameText:SetMaxLines(wrap and 3 or 1)
    nameText:SetNonSpaceWrap(wrap)
    nameText:SetJustifyV("BOTTOM")
    nameText:SetJustifyH("LEFT")
    if wrap then
        local width=A.db.nameWrapWidth or 132
        -- Short names keep their natural width when the limit is wider than the plate.
        nameText:SetWidth(0)
        local natural=nameText:GetStringWidth()
        if not (issecretvalue and issecretvalue(natural)) and natural>0 then
            width=math.min(width,math.ceil(natural)+1)
        end
        nameText:SetWidth(width)
        -- Give the client enough vertical space to lay out long words before
        -- measuring the result. Short names reclaim the unused space.
        local _,fontSize=nameText:GetFont()
        local available=3*math.ceil(fontSize*1.4)+4
        nameText:SetHeight(available)
        local measured=nameText:GetStringHeight()
        if not (issecretvalue and issecretvalue(measured)) and measured>0 then
            nameText:SetHeight(math.min(available,math.ceil(measured)+2))
        end
        if width>owner:GetWidth()-30 then
            nameText:SetPoint("BOTTOMRIGHT",levelText,"BOTTOMLEFT",-5,0)
            return
        end
    elseif isPlayer then
        nameText:SetWidth(0)
        local width=nameText:GetStringWidth()
        if not (issecretvalue and issecretvalue(width)) and width>132 then
            nameText:SetPoint("BOTTOMRIGHT",levelText,"BOTTOMLEFT",-5,0)
            return
        end
    else
        nameText:SetWidth(132)
    end
    nameText:SetPoint("BOTTOMLEFT",owner,"TOPLEFT",0,2)
end
local personalOptions={
    name="personalName", health="personalHealth", badges="personalBadge", showLevelText="personalLevel",
    buffs="personalBuffs", debuffs="personalDebuffs", casts="personalCasts", showGuild="personalGuild",
}
function A.PlateOption(owner,key,enemy)
    if owner.isPersonal and personalOptions[key] then return A.db[personalOptions[key]] end
    return A.db[A.PlayerOptionKey(key,enemy)]
end
function A.LayoutPersonalParts(owner,personal)
    owner.isPersonal=personal
    local healthVisible=not personal or A.db.personalHealth
    owner:SetHeight(healthVisible and 18 or .01)
    owner.health:SetShown(healthVisible)
    if owner.healthBackground then owner.healthBackground:SetShown(healthVisible) end
    owner.name:SetShown(not personal or A.db.personalName)
end
function A.PlayerHeading(owner,nameText,levelText,unit,sampleGuild,enemy)
    A.LayoutName(owner,nameText,levelText,true)
    local guild
    if enemy==nil then enemy=A.IsEnemyPlayer(unit) end
    if A.PlateOption(owner,"showGuild",enemy) then
        guild=sampleGuild or (unit and GetGuildInfo and GetGuildInfo(unit))
        if issecretvalue and issecretvalue(guild) then guild=nil end
    end
    if guild and guild~="" then
        if not owner.guild then
            local tag=CreateFrame("Frame",nil,owner)
            tag:SetHeight(15)
            local bg=tag:CreateTexture(nil,"BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(.055,.043,.028,.82)
            local accent=tag:CreateTexture(nil,"ARTWORK")
            accent:SetPoint("TOPLEFT")
            accent:SetPoint("BOTTOMLEFT")
            accent:SetWidth(2)
            accent:SetColorTexture(.78,.60,.29,.95)
            tag.caption=label(tag,11,"guildText")
            tag.caption:SetPoint("LEFT",6,0)
            tag.caption:SetTextColor(.95,.84,.61)
            tag.background,tag.accent=bg,accent
            owner.guild=tag
        end
        local tag=owner.guild
        local position=A.db[A.PlayerOptionKey("guildPosition",enemy)]
        local style=A.db[A.PlayerOptionKey("guildStyle",enemy)]
        local badge=style=="Gold tag"
        tag.background:SetShown(badge)
        tag.accent:SetShown(badge)
        tag.caption:ClearAllPoints()
        tag.caption:SetPoint("LEFT",badge and 6 or 0,0)
        tag.caption:SetText(style=="Angle brackets" and ("<"..guild..">") or guild)
        tag:SetHeight(math.max(15,tag.caption:GetStringHeight()+2))
        tag:SetWidth(tag.caption:GetStringWidth()+(badge and 11 or 0))
        tag:ClearAllPoints()
        tag.position=position
        if owner.isPersonal and not A.db.personalName and position~="Below plate" then
            tag:SetPoint("BOTTOMLEFT",owner,"TOPLEFT",0,2)
        elseif position=="Before name" then
            tag:SetPoint("RIGHT",nameText,"LEFT",-4,0)
        elseif position=="After name" then
            -- Reserve room beside the level for the guild, even with a long surname.
            nameText:ClearAllPoints()
            nameText:SetPoint("BOTTOMRIGHT",levelText,"BOTTOMLEFT",-tag:GetWidth()-9,0)
            tag:SetPoint("LEFT",nameText,"RIGHT",4,0)
        elseif position=="Under name" then
            tag:SetPoint("BOTTOMLEFT",owner,"TOPLEFT",0,2)
            nameText:ClearAllPoints()
            nameText:SetPoint("BOTTOMLEFT",tag,"TOPLEFT",0,2)
        elseif position=="Below plate" then
            if not owner.auraAnchor then A.AddIndicators(owner) end
            tag:SetPoint("TOPLEFT",owner.auraAnchor,"TOPLEFT",0,0)
        elseif position=="Above centre" or position=="Above right" then
            local height=nameText:GetHeight()
            if issecretvalue and issecretvalue(height) then height=16 end
            if position=="Above centre" then
                tag:SetPoint("BOTTOM",owner,"TOP",0,height+4)
            else
                tag:SetPoint("BOTTOMRIGHT",owner,"TOPRIGHT",0,height+4)
            end
        else
            tag:SetPoint("BOTTOMLEFT",nameText,"TOPLEFT",0,2)
        end
        tag:Show()
    elseif owner.guild then owner.guild:Hide() end
end
local background = player:CreateTexture(nil, "BACKGROUND")
background:SetPoint("TOPLEFT", -1, 1)
background:SetPoint("BOTTOMRIGHT", 1, -1)
background:SetColorTexture(0.08, 0.08, 0.09, 0.95)
local health = CreateFrame("StatusBar", nil, player)
health:SetAllPoints()
health:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
local name, level, value = label(player,15,"nameText"), label(player,14,"levelText"), label(health,13,"healthText")
player.health,player.healthBackground,player.level=health,background,level
player.name=name
name:SetPoint("BOTTOMLEFT", player, "TOPLEFT", 0, 2)
level:SetPoint("BOTTOMRIGHT", player, "TOPRIGHT", 0, 2)
value:SetPoint("CENTER")
local badges = {}
local function badge(owner, unit, anchor, enemy)
    local icon = badges[owner]
    if icon then icon:Hide() end
    if enemy==nil then enemy=A.IsEnemyPlayer(unit) end
    if not A.db or not A.PlateOption(owner,"badges",enemy) or not unit or not UnitIsPlayer(unit) then return end
    local _, class = UnitClass(unit)
    if issecretvalue and issecretvalue(class) then return end
    local readableClass = class and class:lower()
    local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    local specIcon
    if A.db[A.PlayerOptionKey("spec",enemy)] then
        if UnitIsUnit(unit, "player") and GetSpecialization and GetSpecializationInfo then
            local index = GetSpecialization()
            if index then specIcon = select(4, GetSpecializationInfo(index)) end
        elseif GetInspectSpecialization and GetSpecializationInfoByID then
            local ok, id = pcall(GetInspectSpecialization, unit)
            if ok and not (issecretvalue and issecretvalue(id)) and id and id > 0 then
                specIcon = select(4, GetSpecializationInfoByID(id))
            end
        end
    end
    if not readableClass and not coords and not specIcon then return end
    if not icon then
        icon = owner:CreateTexture(nil, "OVERLAY")
        icon:SetSize(18, 18)
        badges[owner] = icon
    end
    local guild=owner.guild
    if owner.isPersonal and not A.db.personalName then anchor=owner end
    local badgeAnchor=guild and guild:IsShown() and guild.position=="Before name" and guild or anchor or owner
    icon:ClearAllPoints()
    icon:SetPoint("RIGHT",badgeAnchor,"LEFT",-4,0)
    local size=A.db[A.PlayerOptionKey("iconSize",enemy)] or 18
    icon:SetSize(size,size)
    if specIcon then
        icon:SetTexture(specIcon)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    elseif coords then
        icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
        icon:SetTexCoord(unpack(coords))
    else
        icon:SetTexture("Interface\\Icons\\ClassIcon_" .. readableClass)
        icon:SetTexCoord(.06,.94,.06,.94)
    end
    icon:Show()
end
A.Badge = badge
local function updatePlate(plate)
    local frame = plate.unitFrame
    if frame and frame.healthBar then badge(frame.healthBar, frame.namePlateUnitToken, plate.CurrentUnitNameString or frame.unitName) end
end
function A.SetHealthLabel(label,current,maximum,unit)
    local db=A.db
    local restricted=issecretvalue and (issecretvalue(current) or issecretvalue(maximum))
    if db.showHealthText==false or (db.hideFullHealthText and not restricted and maximum>0 and current==maximum) then
        label:Hide()
        return
    end
    label:Show()
    A.SetNumericLabel(label,current,maximum,db.healthFormat,unit)
end
function A.SetNumericLabel(label,current,maximum,format,unit,powerType)
    local restricted=issecretvalue and (issecretvalue(current) or issecretvalue(maximum))
    if format=="Current" then label:SetText(current); return end
    if format=="Current / max" then label:SetFormattedText("%d / %d",current,maximum); return end
    local percent
    if not restricted and maximum>0 then
        percent=math.floor(100*current/maximum+.5)
    elseif unit and powerType~=nil and UnitPowerPercent and CurveConstants and CurveConstants.ScaleTo100 then
        percent=UnitPowerPercent(unit,powerType,false,CurveConstants.ScaleTo100)
    elseif unit and powerType==nil and UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
        percent=UnitHealthPercent(unit,true,CurveConstants.ScaleTo100)
    end
    if (issecretvalue and issecretvalue(percent)) or percent~=nil then
        if format=="Percent" then label:SetFormattedText("%d%%",percent)
        else label:SetFormattedText("%d (%d%%)",current,percent) end
    elseif format=="Percent" then label:SetText("")
    else label:SetText(current) end
end
local function updateHealth()
    local current,maximum=UnitHealth("player"),UnitHealthMax("player")
    health:SetMinMaxValues(0,maximum)
    health:SetValue(current)
    A.SetHealthLabel(value,current,maximum,"player")
end
function A.Refresh()
    local db = A.db
    player:SetScale(db.scale / 100)
    player:ClearAllPoints()
    local native = C_NamePlate and C_NamePlate.GetNamePlateForUnit("player")
    A.BindPersonal(native,db.personal)
    A.nativeAnchor = native and not native:IsForbidden() and not db.unlock and db.x == nil
    if native and not native:IsForbidden() and not db.unlock and db.x == nil then
        player:SetPoint("BOTTOM", native, "TOP", db.x or 0, db.y or 24)
    else
        player:SetPoint("CENTER", UIParent, "CENTER", db.x or 0, db.y or 80)
    end
    player:SetShown(db.personal)
    player:EnableMouse(db.personal and db.unlock)
    A.LayoutPersonalParts(player,true)
    local dragPadding=db.personalHealth and 0 or 12
    player:SetHitRectInsets(0,0,-dragPadding,-dragPadding)
    name:SetText(A.PlayerDisplayName("player"))
    A.PlayerHeading(player,name,level,"player")
    level:SetShown(db.personalLevel)
    level:SetText(UnitLevel("player"))
    local _, class = UnitClass("player")
    local color = RAID_CLASS_COLORS[class]
    if color then health:SetStatusBarColor(color.r, color.g, color.b) end
    updateHealth()
    if A.RefreshWorld then A.RefreshWorld() end
    if db.personal then A.PersonalIndicators(player) end
    badge(player, "player", name)
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do if Plater then updatePlate(plate) end end
    end
end
player:SetMovable(true)
player:SetClampedToScreen(true)
player:RegisterForDrag("LeftButton")
player:SetScript("OnDragStart", player.StartMoving)
player:SetScript("OnDragStop", function()
    player:StopMovingOrSizing()
    local x, y = player:GetCenter()
    local cx, cy = UIParent:GetCenter()
    A.db.x, A.db.y = x - cx / player:GetScale(), y - cy / player:GetScale()
end)
function A.NewProfile()
    local profile={
        powerHeight=5, powerValue=false, powerFormat="Current / max", personalPowerFormat="Current / max",
        personalPower=true, personalPowerHeight=5, personalPowerValue=true,
        personal=false, personalSetupPending=true, unlock=false, scale=80, native=true, hideName=true, hideGuild=true,
        preview=false, previewTarget=true, previewFriendlyNPC=false, previewMode="enemyNPCScale", minimap=true,
        enemyNPCScale=80, friendlyNPCScale=80, friendlyPlayerScale=80, enemyPlayerScale=80, targetScale=100,
        showThreat=false, threatPosition="Right of bar", threatFormat="Status + percent",
        townPlates=true, hideIdleNPCs=true, compactCompanions=true, showCompanionText=true, compactFriendly=false, targetOutline=true, viewDistance=A.DistanceLimit(), showDistance=false,
        guildPosition="Under name", guildStyle="Plain text", targetGlowSpread=12, targetGlowStyle="Soft outline", targetGlowStrength=100, targetColor="F4FFFB", showLevelText=true, showHealthText=true, hideFullHealthText=false, healthFormat="Current + percent", wrapNames=true, nameWrapWidth=132, plateFont="Ubuntu Bold", textScale=100, previewEnemyPlayer=false, showSurname=true, showGuild=true, badges=true, spec=true, iconSize=18, power=true,
        casts=true, castHeight=14, castTimer=true, castColor="903BCC",
        buffs=true, castableBuffs=true, debuffs=true, auraScale=100,
        buffPosition="Top left", debuffPosition="Bottom left", controlPosition="Bottom left",
        questTint=true, questIcon=true, quest="FF00F5", hostile="CC0613", neutral="FFEB2B",
        friendly="70FF90", aggro="CC0613", pulling="FFEB2B", safe="C7CFD9",
    }
    for key,option in pairs(personalOptions) do
        profile[option]=profile[key]~=false
    end
    profile.textOutline,profile.textShadow="Normal",true
    for _,role in ipairs(A.TextRoles) do profile[role[1]]=100 end
    A.InitEnemyOptions(profile)
    return profile
end
local personalPrompt="RAYNNA_NAMEPLATES_PERSONAL_SETUP"
local function answerPersonalPrompt(enabled)
    if not A.db or not A.db.personalSetupPending then return end
    A.db.personal=enabled
    A.db.personalSetupPending=false
    A.Refresh()
    if A.SyncOptions then A.SyncOptions() end
end
StaticPopupDialogs[personalPrompt]={
    text="Enable Raynna's personal nameplate for this character?\n\nYou can change this later in /rnp under Personal.",
    button1=YES, button2=NO,
    OnAccept=function() answerPersonalPrompt(true) end,
    OnCancel=function(_,_,reason)
        if reason=="clicked" or reason==nil then answerPersonalPrompt(false) end
    end,
    timeout=0, whileDead=true, hideOnEscape=false,
}
function A.FinishPersonalSetup()
    if A.db.personalSetupPending then
        A.db.personalSetupPending=false
        StaticPopup_Hide(personalPrompt)
    end
end
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterUnitEvent("UNIT_HEALTH", "player")
events:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("PLAYER_TALENT_UPDATE")
events:RegisterEvent("INSPECT_READY")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if not RaynnaNameplatesDB or not next(RaynnaNameplatesDB) then
            RaynnaNameplatesDB = A.NewProfile()
        end
        A.db = RaynnaNameplatesDB
        if A.db.personalSetupPending==nil then A.db.personalSetupPending=true end
        for key, default in pairs({guildPosition="Above left", guildStyle="Gold tag", targetGlowSpread=18, targetGlowStyle="Soft outline", targetGlowStrength=100, targetColor="FFB31E", showLevelText=true, showHealthText=true, hideFullHealthText=false, healthFormat="Current + percent", wrapNames=false, nameWrapWidth=132, plateFont="Ubuntu Bold", textScale=100, previewEnemyPlayer=false, showSurname = true, personal = false, badges = true, spec = true, scale = 100}) do
            if A.db[key] == nil then A.db[key] = default end
        end
        if Plater and Plater.UpdatePlateText then hooksecurefunc(Plater, "UpdatePlateText", updatePlate) end
        if not A.db.overheadVersion then
            A.db.x, A.db.y, A.db.overheadVersion = nil, nil, true
        end
        A.InitWorld()
        if A.db.plateFont=="Runeballs Labels" then A.db.plateFont="Lato Bold" end
        for key,option in pairs(personalOptions) do
            if A.db[option]==nil then A.db[option]=A.db[key]~=false and (key~="showGuild" or A.db.showGuild==true) end
        end
        if A.db.personalPower==nil then A.db.personalPower=A.db.power~=false end
        if A.db.personalPowerHeight==nil then A.db.personalPowerHeight=5 end
        if A.db.personalPowerValue==nil then A.db.personalPowerValue=false end
        for key,default in pairs({powerHeight=5,powerValue=false,powerFormat="Current / max",personalPowerFormat="Current / max"}) do
            if A.db[key]==nil then A.db[key]=default end
        end
        A.InitEnemyOptions(A.db)
        for key,value in pairs(A.NewProfile()) do
            if A.db[key]==nil and (key=="textOutline" or key=="textShadow" or key:match("Text$")) then A.db[key]=value end
        end
        A.RefreshFonts()
        A.CreateLauncher()
        A.RegisterSettings()
    end
    if not A.db then return end
    if event=="PLAYER_ENTERING_WORLD" and A.db.personalSetupPending and not (StaticPopup_Visible and StaticPopup_Visible(personalPrompt)) then
        StaticPopup_Show(personalPrompt)
    end
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        if player:IsShown() then updateHealth() end
    else
        A.Refresh()
    end
end)


