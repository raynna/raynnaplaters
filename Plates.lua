local _, A = ...
local player = CreateFrame("Frame", nil, UIParent)
player:SetSize(162, 18)
player:Hide()
local function label(parent, size)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont("Interface\\AddOns\\RaynnaNameplates\\Ubuntu-Bold.ttf", size, "OUTLINE")
    return text
end
local background = player:CreateTexture(nil, "BACKGROUND")
background:SetPoint("TOPLEFT", -1, 1)
background:SetPoint("BOTTOMRIGHT", 1, -1)
background:SetColorTexture(0.08, 0.08, 0.09, 0.95)
local health = CreateFrame("StatusBar", nil, player)
health:SetAllPoints()
health:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
local name, level, value = label(player, 15), label(player, 14), label(health, 13)
name:SetPoint("BOTTOMLEFT", player, "TOPLEFT", 0, 2)
level:SetPoint("BOTTOMRIGHT", player, "TOPRIGHT", 0, 2)
value:SetPoint("CENTER")
local badges = {}
local function badge(owner, unit, anchor)
    local icon = badges[owner]
    if icon then icon:Hide() end
    if not A.db or not A.db.badges or not unit or not UnitIsPlayer(unit) then return end
    local _, class = UnitClass(unit)
    if issecretvalue and issecretvalue(class) then return end
    local readableClass = class and class:lower()
    local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    local specIcon
    if A.db.spec then
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
        icon:SetPoint("RIGHT", anchor or owner, "LEFT", -4, 0)
        badges[owner] = icon
    end
    icon:SetSize(A.db.iconSize or 18, A.db.iconSize or 18)
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
local function updateHealth()
    local current, maximum = UnitHealth("player"), UnitHealthMax("player")
    health:SetMinMaxValues(0, maximum)
    health:SetValue(current)
    if issecretvalue and (issecretvalue(current) or issecretvalue(maximum)) then
        if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
            value:SetFormattedText("%d (%d%%)", current, UnitHealthPercent("player", true, CurveConstants.ScaleTo100))
        else
            value:SetText(current)
        end
    else
        value:SetFormattedText("%d (%d%%)", current, maximum > 0 and math.floor(100 * current / maximum + 0.5) or 0)
    end
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
    name:SetText(UnitName("player"))
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
            -- These used to default to off when absent in older profiles.
            RaynnaNameplatesDB = {
                preview = true,
                native = true,
                hideName = true,
                hideGuild = true,
                castableBuffs = true,
                buffs = true,
            }
        end
        A.db = RaynnaNameplatesDB
        for key, default in pairs({personal = false, badges = true, spec = true, scale = 100}) do
            if A.db[key] == nil then A.db[key] = default end
        end
        if Plater and Plater.UpdatePlateText then hooksecurefunc(Plater, "UpdatePlateText", updatePlate) end
        if not A.db.overheadVersion then
            A.db.x, A.db.y, A.db.overheadVersion = nil, nil, true
        end
        A.InitWorld()
        A.CreateLauncher()
        A.RegisterSettings()
    end
    if not A.db then return end
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        if player:IsShown() then updateHealth() end
    else
        A.Refresh()
    end
end)


