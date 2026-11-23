local _, A = ...

A.partyDefaults = {
    partyIcon = false,
    partyLabel = false,
    partyLabelText = 'Party',
    partyHealthTint = false,
    partyNameTint = false,
    partyColor = '66CCFF',
    partyIconSize = 18,
    partyTextSize = 11,
    partyIncludeRaid = false,
    partyIconStyle = 'Group',
}
function A.InitPartyOptions(db)
    for key, value in pairs(A.partyDefaults) do
        if db[key] == nil then
            db[key] = value
        end
    end
end
function A.IsPartyPlayer(unit)
    if not unit or not UnitIsPlayer(unit) or UnitIsUnit(unit, 'player') or UnitCanAttack('player', unit) then
        return false
    end
    -- Resolve through roster tokens: nameplate aliases need not work with UnitInParty.
    for index = 1, (GetNumSubgroupMembers and GetNumSubgroupMembers() or 0) do
        if UnitIsUnit(unit, 'party' .. index) then
            return true
        end
    end
    if A.db.partyIncludeRaid then
        for index = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do
            if UnitIsUnit(unit, 'raid' .. index) then
                return true
            end
        end
    end
    return false
end
local function tint()
    local hex = A.db.partyColor or '66CCFF'
    return tonumber(hex:sub(1, 2), 16) / 255,
        tonumber(hex:sub(3, 4), 16) / 255,
        tonumber(hex:sub(5, 6), 16) / 255
end
function A.PartyTint(frame, member)
    if not member then
        return
    end
    if A.db.partyHealthTint then
        frame.health:SetStatusBarColor(tint())
    end
    if A.db.partyNameTint then
        frame.name:SetTextColor(tint())
    end
end
function A.UpdateParty(frame, unit, sample)
    local member = sample or A.IsPartyPlayer(unit)
    if member and (A.db.partyIcon or A.db.partyLabel) then
        if not frame.partyIcon then
            frame.partyIcon = frame:CreateTexture(nil, 'OVERLAY')
            frame.partyText = frame:CreateFontString(nil, 'OVERLAY')
        end
        local icon = frame.partyIcon
        local size = A.db.partyIconSize or 18
        icon:SetSize(size, size)
        icon:ClearAllPoints()
        A.AnchorPart(icon, 'RIGHT', frame, 'LEFT', -7, 0)
        if A.db.partyIconStyle == 'Star' then
            icon:SetTexture('Interface\\TargetingFrame\\UI-RaidTargetingIcon_1')
        else
            icon:SetTexture('Interface\\FriendsFrame\\UI-Toast-ChatInviteIcon')
        end
        icon:SetShown(A.db.partyIcon)
        local label = frame.partyText
        A.SetPlateFont(label, A.db.partyTextSize or 11)
        label:ClearAllPoints()
        A.AnchorPart(label, 'BOTTOM', frame.name, 'TOP', 0, 4)
        label:SetText(A.db.partyLabelText or 'Party')
        label:SetTextColor(tint())
        label:SetShown(A.db.partyLabel)
    else
        if frame.partyIcon then
            frame.partyIcon:Hide()
            frame.partyText:Hide()
        end
    end
    A.PartyTint(frame, member)
end
