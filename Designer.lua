local _, A = ...

local parts = {
    { 'partyIcon', 'Party icon' },
    { 'partyText', 'Party label' },
    { 'health', 'Health bar' },
    { 'value', 'Health value' },
    { 'name', 'Name' },
    { 'level', 'Level' },
    { 'distance', 'Distance' },
    { 'threat', 'Threat' },
    { 'guild', 'Guild' },
    { 'classBadge', 'Class icon' },
    { 'questBadge', 'Quest icon' },
    { 'power', 'Resource bar' },
    { 'powerValue', 'Resource value' },
    { 'cast', 'Cast bar' },
    { 'castText', 'Cast name' },
    { 'castTime', 'Cast timer' },
    { 'serviceName', 'Service name' },
    { 'serviceRole', 'Service role' },
    { 'serviceIcon', 'Service icon' },
    { 'serviceQuest', 'Service quest marker' },
    { 'objectLabel', 'NPC / object name' },
    { 'objectIcon', 'Interaction icon' },
    { 'petName', 'Pet name' },
    { 'petOwner', 'Pet owner' },
    { 'buffPosition', 'Buffs' },
    { 'debuffPosition', 'Debuffs' },
    { 'controlPosition', 'Crowd control' },
}
A.designerParts = parts
local states = setmetatable({}, { __mode = 'k' })
local renderingDraft
function A.MergeDesignerProfiles(db)
    local profiles = db.designerProfiles
    if not profiles then
        return
    end
    for _, kind in ipairs({ 'enemyNPCScale', 'friendlyNPCScale', 'neutral', 'questMob' }) do
        if profiles.npc == nil then
            profiles.npc = profiles[kind]
        end
        profiles[kind] = nil
    end
    for _, kind in ipairs({ 'trainer', 'vendor', 'repair', 'flight', 'inn', 'bank', 'auction', 'stable' }) do
        if profiles.service == nil then
            profiles.service = profiles[kind]
        end
        profiles[kind] = nil
    end
end
function A.DesignLayout(frame)
    local kind = frame and (frame.designType or (frame.isPersonal and 'personal'))
    local profiles = A.db.designerProfiles
    return profiles and profiles[kind] or A.db.designer
end
local function options(key, frame)
    local layout = renderingDraft or A.DesignLayout(frame)
    return layout and layout[key]
end
function A.DesignerAura(key, frame)
    local opt = options(key, frame)
    if opt then
        return opt.x or 0, opt.y or 0, opt.scale or 1
    end
    return 0, 0, 1
end

-- Remember the unedited anchors. Existing layouts can re-anchor a region when
-- casts, guilds or resources appear, including while a custom layout is active.
local function readAnchor(region, index)
    if region.rnpAnchor then
        local a = region.rnpAnchor
        return a.point, a.parent, a.anchor, a.x, a.y
    elseif region.rnpStretch then
        local point = index == 1 and 'TOPLEFT' or 'BOTTOMRIGHT'
        return point, region:GetParent(), point, 0, 0
    end
    if region.IsAnchoringRestricted and region:IsAnchoringRestricted() then
        return
    end
    local ok, point, parent, anchor, x, y = pcall(region.GetPoint, region, index)
    if ok and point and not (issecretvalue and (issecretvalue(x) or issecretvalue(y))) then
        return point, parent, anchor, x, y
    end
end
function A.DesignerVisibility(region, opt)
    if not region then
        return
    end
    local faded = region.designerDisabled
        or (region.designerSample and opt and (opt.hidden or opt.opacity == 0))
    if faded or (opt and (opt.hidden or opt.opacity)) then
        if region.rnpOriginalAlpha == nil then
            region.rnpOriginalAlpha = region:GetAlpha()
        end
        region:SetAlpha(faded and 0.35 or opt.hidden and 0 or (opt.opacity or 100) / 100)
    elseif region.rnpOriginalAlpha ~= nil then
        region:SetAlpha(region.rnpOriginalAlpha)
        region.rnpOriginalAlpha = nil
    end
end
local function applyAppearance(region, opt)
    A.DesignerVisibility(region, opt)
    if region.barBackground then
        local hex = opt and opt.backgroundTint
        if hex ~= region.lastBackgroundTint then
            if hex then
                region.barBackground:SetColorTexture(
                    tonumber(hex:sub(1, 2), 16) / 255,
                    tonumber(hex:sub(3, 4), 16) / 255,
                    tonumber(hex:sub(5, 6), 16) / 255,
                    region.baseBackground[4]
                )
            else
                region.barBackground:SetColorTexture(unpack(region.baseBackground))
            end
            region.lastBackgroundTint = hex
        end
    end
    if region.isCastBar then
        return
    end
    local target = region.caption or region
    if target.GetFont then
        local face, size, flags = target:GetFont()
        local wanted = opt and A.plateFonts[opt.font]
        if wanted or target.rnpCustomFace then
            local path = wanted or target.rnpFont
            if path and path ~= face then
                target:SetFont(path, size, flags)
            end
            target.rnpCustomFace = wanted
        end
    end
    if target.SetJustifyH and (opt and opt.align or target.rnpOriginalAlign) then
        if not target.rnpOriginalAlign then
            target.rnpOriginalAlign = target:GetJustifyH()
        end
        local align = opt and opt.align or target.rnpOriginalAlign
        if target:GetJustifyH() ~= align then
            target:SetJustifyH(align)
        end
        if not (opt and opt.align) then
            target.rnpOriginalAlign = nil
        end
    end
    if target.GetFont and target.SetFont and (opt and opt.outline or target.rnpOriginalOutline) then
        local face, size, flags = target:GetFont()
        if target.rnpOriginalOutline == nil then
            target.rnpOriginalOutline = flags or ''
        end
        local outline = opt and opt.outline or target.rnpOutline or target.rnpOriginalOutline
        if face and (flags or '') ~= outline then
            target:SetFont(face, size, outline)
        end
        if not (opt and opt.outline) then
            target.rnpOriginalOutline = nil
        end
    end
    local tint = opt and opt.tint
    if not tint and not target.rnpOriginalTint then
        return
    end
    local get = target.GetTextColor or target.GetStatusBarColor or target.GetVertexColor
    local set = target.SetTextColor or target.SetStatusBarColor or target.SetVertexColor
    if not get or not set then
        return
    end
    if tint then
        if not target.rnpOriginalTint then
            target.rnpOriginalTint = { get(target) }
        end
        set(
            target,
            tonumber(tint:sub(1, 2), 16) / 255,
            tonumber(tint:sub(3, 4), 16) / 255,
            tonumber(tint:sub(5, 6), 16) / 255
        )
    else
        set(target, unpack(target.rnpOriginalTint))
        target.rnpOriginalTint = nil
    end
end
local function transform(region, key, owners, frame)
    if
        not region
        or (
            not region.rnpAnchor
            and not region.rnpStretch
            and region.IsAnchoringRestricted
            and region:IsAnchoringRestricted()
        )
    then
        return
    end
    local opt = options(key, frame)
    applyAppearance(region, opt)
    local state = states[region]
    local compensate
    if owners then
        for i = 1, (region.rnpAnchor and 1 or region.rnpStretch and 2 or region:GetNumPoints()) do
            local point, anchor = readAnchor(region, i)
            if not point then
                return
            end
            if anchor and owners[anchor] and options(owners[anchor], frame) then
                compensate = true
                break
            end
        end
    end
    if not opt and not state and not compensate then
        return
    end
    state = state or {}
    states[region] = state
    local dx, dy, scale = A.DesignerAura(key, frame)
    local count = region.rnpAnchor and 1 or region.rnpStretch and 2 or region:GetNumPoints()
    if count == 0 then
        return
    end
    local points = {}
    for i = 1, count do
        local point, parent, anchor, x, y = readAnchor(region, i)
        if not point then
            return
        end
        local old = state[point]
        if
            not region.rnpAnchor
            and not region.rnpStretch
            and old
            and old.parent == parent
            and old.anchor == anchor
            and x == old.outX
            and y == old.outY
        then
            x, y = old.x, old.y
        end
        points[i] = { point = point, parent = parent, anchor = anchor, x = x, y = y }
    end
    -- Single-anchor frames scale around their original anchor. A health bar
    -- stretched across its parent needs its opposing anchors spread instead.
    local stretch = count > 1 and key == 'health'
    if region.GetObjectType and region:GetObjectType() == 'FontString' then
        local face, size, flags = region:GetFont()
        local base = region.rnpPixels or (size == state.fontOutput and state.fontBase or size)
        if base and face then
            state.fontBase, state.fontOutput = base, math.max(1, base * scale)
            if size ~= state.fontOutput then
                region:SetFont(face, state.fontOutput, flags)
            end
        end
    elseif region.SetTextScale then
        region:SetTextScale(scale)
    elseif region.SetScale and not stretch then
        region:SetScale(scale)
    elseif count == 1 and region.SetSize then
        local w, h = region:GetSize()
        if w ~= state.outW or h ~= state.outH then
            state.w, state.h = w, h
        end
        state.outW, state.outH = state.w * scale, state.h * scale
        region:SetSize(state.outW, state.outH)
        state.outW, state.outH = region:GetSize()
    end
    local factor = region.SetScale
            and not state.fontBase
            and not region.SetTextScale
            and not stretch
            and scale
        or 1
    local w, h = region:GetParent():GetSize()
    for _, p in ipairs(points) do
        local x, y = dx, dy
        local parentKey = owners and owners[p.parent]
        local moved = parentKey and options(parentKey, frame)
        if moved then
            local units = p.parent:GetParent():GetEffectiveScale() / region:GetParent():GetEffectiveScale()
            x, y = x - moved.x * units, y - moved.y * units
        end
        if stretch then
            x = x + (p.point:find('LEFT') and -1 or p.point:find('RIGHT') and 1 or 0) * w * (scale - 1) / 2
            y = y + (p.point:find('BOTTOM') and -1 or p.point:find('TOP') and 1 or 0) * h * (scale - 1) / 2
        end
        p.outX, p.outY = (p.x + x) / factor, (p.y + y) / factor
        region:SetPoint(p.point, p.parent, p.anchor, p.outX, p.outY)
        -- WoW stores anchors at client precision. Cache the values it actually
        -- returns so a redraw cannot mistake rounding for a fresh layout.
        state[p.point] = p
    end
    if region.rnpAnchor or region.rnpStretch then
        if not opt and not compensate then
            states[region] = nil
        end
        return
    end
    for i = 1, region:GetNumPoints() do
        local point, parent, anchor, x, y = readAnchor(region, i)
        if not point then
            return
        end
        local p = state[point]
        p.parent, p.anchor, p.outX, p.outY = parent, anchor, x, y
    end
    if not opt and not compensate then
        states[region] = nil
    end
end
function A.DesignPlate(frame)
    if
        not A.db
        or (
            not frame.designerSettings
            and not renderingDraft
            and not A.DesignLayout(frame)
            and not frame.wasDesigned
        )
    then
        return
    end
    local owners = frame.designerOwners or {}
    frame.designerOwners = owners
    for _, part in ipairs(parts) do
        local region = frame[part[1]]
        if region then
            if frame.designerSettings then
                region.designerSample = true
                region.designerDisabled = frame.designerDisabled[part[1]]
            end
            owners[region] = part[1]
        end
    end
    for _, part in ipairs(parts) do
        transform(frame[part[1]], part[1], owners, frame)
    end
    transform(frame.auraAnchor, 'auraAnchor', owners, frame)
    A.DesignerVisibility(frame.healthBackground, options('health', frame))
    for _, icon in ipairs(frame.icons or {}) do
        if frame.designerSettings then
            icon.designerSample = true
            icon.designerDisabled = frame.designerDisabled[icon.designKey]
        end
        A.DesignerVisibility(icon, icon.designKey and options(icon.designKey, frame))
    end
    frame.wasDesigned = renderingDraft ~= nil or A.DesignLayout(frame) ~= nil
end
function A.DesignDistance(frame)
    transform(frame.distance, 'distance', frame.designerOwners, frame)
end
function A.DesignThreat(frame)
    transform(frame.threat, 'threat', frame.designerOwners, frame)
end

function A.InitPreviewCamera(sample)
    sample.cameraZoom = 1
    sample.cameraX, sample.cameraY = 0, 0
    function sample:PositionCamera()
        local plate = self.sample
        if not plate or not self.designBaseScale then
            return
        end
        local scale = self.designBaseScale * self.cameraZoom
        plate:SetScale(scale)
        plate:ClearAllPoints()
        plate:SetPoint('CENTER', self, 'CENTER', self.cameraX / scale, self.cameraY / scale)
    end
    function sample:ZoomCamera(delta)
        local old = self.cameraZoom
        local zoom = math.max(0.4, math.min(4, old * 1.2 ^ delta))
        local mx, my = GetCursorPosition()
        local cx, cy = self:GetCenter()
        if not cx or not cy then
            return old
        end
        local k = self:GetEffectiveScale()
        mx, my = mx / k - cx, my / k - cy
        self.cameraX = mx + (self.cameraX - mx) * zoom / old
        self.cameraY = my + (self.cameraY - my) * zoom / old
        self.cameraZoom = zoom
        self:PositionCamera()
        return zoom
    end
end

function A.BuildDesigner(row, button, label, changed, existingRow, designerRows)
    local openRow = existingRow or row('Designer', 'Open layout designer', 'drag move resize elements')
    local window = CreateFrame('Frame', nil, UIParent, 'BackdropTemplate')
    window:SetFrameStrata('FULLSCREEN_DIALOG')
    window:SetClampedToScreen(true)
    window:SetPoint('CENTER')
    local maxW, maxH = UIParent:GetWidth(), UIParent:GetHeight()
    window:SetSize(math.min(1040, maxW), math.min(650, maxH))
    window:SetResizable(true)
    if window.SetResizeBounds then
        window:SetResizeBounds(math.min(740, maxW), math.min(570, maxH), maxW, maxH)
    elseif window.SetMinResize then
        window:SetMinResize(math.min(740, maxW), math.min(570, maxH))
    end
    window:SetMovable(true)
    window:EnableMouse(true)
    window:SetBackdrop({
        bgFile = 'Interface\\Buttons\\WHITE8X8',
        edgeFile = 'Interface\\Buttons\\WHITE8X8',
        edgeSize = 1,
    })
    window:SetBackdropColor(0.075, 0.05, 0.033, 0.98)
    window:SetBackdropBorderColor(0.64, 0.46, 0.22, 1)
    window:Hide()
    local title = CreateFrame('Frame', nil, window)
    title:SetPoint('TOPLEFT', 8, -4)
    title:SetPoint('TOPRIGHT', -36, -4)
    title:SetHeight(28)
    label(title, "Raynna's Nameplate Designer", 4)
    title:EnableMouse(true)
    title:RegisterForDrag('LeftButton')
    title:SetScript('OnDragStart', function()
        window:StartMoving()
    end)
    title:SetScript('OnDragStop', function()
        window:StopMovingOrSizing()
    end)
    local close = CreateFrame('Button', nil, window, 'UIPanelCloseButton')
    close:SetPoint('TOPRIGHT', -2, -2)
    close:SetScript('OnClick', function()
        window:Hide()
    end)
    local grip = CreateFrame('Button', nil, window)
    grip:SetSize(20, 20)
    grip:SetPoint('BOTTOMRIGHT', -2, 2)
    grip:SetNormalTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up')
    grip:SetScript('OnMouseDown', function(_, mouse)
        if mouse == 'LeftButton' then
            window:StartSizing('BOTTOMRIGHT')
        end
    end)
    grip:SetScript('OnMouseUp', function()
        window:StopMovingOrSizing()
    end)
    window:SetScript('OnHide', function()
        window:StopMovingOrSizing()
    end)
    local sample
    local function open()
        window:Show()
        window:Raise()
        if not sample.sample then
            A.DrawAuraExample(sample)
        end
    end
    A.CloseDesigner = function()
        window:Hide()
    end
    A.OpenDesigner = open
    if not existingRow then
        button(openRow, 'Open designer', 0, 140, open)
    end
    local toolbar = CreateFrame('Frame', nil, window)
    toolbar:SetPoint('TOPLEFT', 12, -34)
    toolbar:SetPoint('TOPRIGHT', -12, -34)
    toolbar:SetHeight(30)
    local canvas = CreateFrame('Frame', nil, window)
    canvas:SetPoint('TOPLEFT', 12, -70)
    canvas:SetPoint('BOTTOMRIGHT', -252, 172)
    local guide = window:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
    guide:SetPoint('TOPLEFT', canvas, 'BOTTOMLEFT', 2, -6)
    guide:SetWidth(math.min(690, maxW - 30))
    guide:SetJustifyH('LEFT')
    if guide.SetSpacing then
        guide:SetSpacing(3)
    end
    guide:SetText(
        '|cffffd477Component controls|r\n* Left-click to select. Left-drag to move the selection.\n* Right-click a selected part to reset positions. Right-drag a part to resize it.\n* Drag from empty space to box-select, or Shift-drag anywhere. Click empty space to clear.\n* Right-drag empty space to pan. Scroll to zoom. Faded parts are disabled.'
    )
    local footer = CreateFrame('Frame', nil, window)
    footer:SetPoint('BOTTOMLEFT', 12, 3)
    footer:SetSize(410, 25)
    local magnet = CreateFrame('CheckButton', nil, footer, 'UICheckButtonTemplate')
    magnet:SetPoint('LEFT')
    magnet.Text:SetText('Snap edges and centres')
    magnet:SetScript('OnShow', function(self)
        self:SetChecked(A.db.designerSnap ~= false)
    end)
    magnet:SetScript('OnClick', function(self)
        A.db.designerSnap = not not self:GetChecked()
    end)
    sample = CreateFrame('Frame', nil, canvas, 'BackdropTemplate')
    sample:SetAllPoints()
    sample:SetClipsChildren(true)
    sample:SetBackdrop({
        bgFile = 'Interface\\Buttons\\WHITE8X8',
        edgeFile = 'Interface\\Buttons\\WHITE8X8',
        edgeSize = 1,
    })
    sample:SetBackdropColor(0.06, 0.045, 0.03, 0.96)
    sample:SetBackdropBorderColor(0.48, 0.36, 0.17, 1)
    local resetRow = CreateFrame('Frame', nil, window)
    resetRow:SetPoint('BOTTOMLEFT', 12, 32)
    resetRow:SetPoint('BOTTOMRIGHT', -12, 32)
    resetRow:SetHeight(26)
    local receipt = label(resetRow, '', 225)
    receipt:SetTextColor(0.45, 1, 0.55)
    local mode = 1
    local function storeLayout(layout)
        A.db.designerProfiles = A.db.designerProfiles or {}
        A.db.designerProfiles[A.designerModes[mode].designType] = layout
    end
    local inspector
    local pickerSelection
    local syncProperties, updateSelection
    local marked = {}
    local cleared = false
    local collapsed = false
    local selected = 3
    local selectButton, readout, partPicker
    local syncShared
    local general = CreateFrame('CheckButton', nil, toolbar, 'UICheckButtonTemplate')
    general:SetPoint('LEFT', 414, 0)
    local generalKeys = {
        personal = { 'personal', 'Enabled' },
        companion = { 'compactCompanions', 'Compact pets' },
        idle = { 'hideIdleNPCs', 'Name only' },
        friendlyPlayerScale = { 'showGuild', 'Show guild' },
        enemyPlayerScale = { 'enemyShowGuild', 'Show guild' },
    }
    local function syncGeneral()
        local entry = A.designerModes[mode]
        local option = entry.party and { 'partyIcon', 'Party icons' } or generalKeys[entry.designType]
        general:SetShown(option ~= nil)
        general.setting = option and option[1]
        if option then
            general.Text:SetText(option[2])
            general:SetChecked(A.db[option[1]])
        end
    end
    general:SetScript('OnClick', function(self)
        if self.setting == 'personal' then
            A.FinishPersonalSetup()
        end
        if self.setting then
            A.db[self.setting] = not not self:GetChecked()
            changed()
            if A.SyncOptions then
                A.SyncOptions()
            end
        end
    end)
    local function sync()
        syncGeneral()
        selectButton:SetText(cleared and 'Select component' or parts[selected][2] .. ' >')
        readout:SetShown(not cleared)
        local x, y, s = A.DesignerAura(parts[selected][1], sample.sample)
        readout:SetText(('%+.0f, %+.0f   %d%%'):format(x, y, math.floor(s * 100 + 0.5)))
        if updateSelection then
            updateSelection()
        end
        if inspector and inspector:IsShown() and syncProperties then
            syncProperties()
        end
    end
    selectButton = button(toolbar, '', 0, 138, function()
        partPicker:SetShown(not partPicker:IsShown())
    end)
    readout = label(toolbar, '', 145)
    button(toolbar, 'Reset part', 307, 96, function()
        if cleared then
            return
        end
        if inspector then
            inspector:Hide()
        end
        local copy = {}
        for k, v in pairs(A.DesignLayout(sample.sample) or {}) do
            if k ~= parts[selected][1] then
                copy[k] = v
            end
        end
        storeLayout(copy)
        receipt:SetText(parts[selected][2] .. ' reset.')
        changed()
        A.DrawAuraExample(sample)
        sync()
    end)
    local confirm = CreateFrame('Frame', nil, resetRow)
    confirm:SetAllPoints()
    confirm:Hide()
    local question = label(confirm, '', 0)
    local pending
    local resetType, resetAll
    local function dismiss()
        pending = nil
        confirm:Hide()
        resetType:Show()
        resetAll:Show()
        receipt:Show()
    end
    local function ask(all)
        if inspector then
            inspector:Hide()
        end
        pending = all and 'all' or sample.designerMode.designType
        question:SetText(all and 'Reset every plate design?' or 'Reset this plate design?')
        receipt:Hide()
        resetType:Hide()
        resetAll:Hide()
        confirm:Show()
    end
    resetType = button(resetRow, 'Reset this design', 0, 111, function()
        ask(false)
    end)
    resetAll = button(resetRow, 'Reset all designs', 114, 108, function()
        ask(true)
    end)
    button(confirm, CANCEL, 180, 72, dismiss)
    button(confirm, 'Reset', 256, 72, function()
        if pending == 'all' then
            A.db.designerProfiles = nil
            A.db.designer = nil
            receipt:SetText('All designs reset.')
        elseif pending == sample.designerMode.designType then
            storeLayout({})
            receipt:SetText((sample.designerMode.label or sample.designerMode.title) .. ' reset.')
        else
            dismiss()
            return
        end
        dismiss()
        A.DrawAuraExample(sample)
        sync()
        changed()
    end)
    window:HookScript('OnHide', dismiss)
    openRow.sync = function()
        sync()
        magnet:SetChecked(A.db.designerSnap ~= false)
    end
    sync()
    sample.category = 'Designer'
    sample.designerMode = A.designerModes[mode]
    local picker = CreateFrame('Frame', nil, window, 'BackdropTemplate')
    picker:SetFrameLevel(window:GetFrameLevel() + 60)
    picker:SetBackdrop({ bgFile = 'Interface\\Buttons\\WHITE8X8' })
    picker:SetBackdropColor(0.07, 0.05, 0.03, 1)
    picker:EnableMouse(true)
    picker:Hide()
    local typeButton = button(
        title,
        sample.designerMode.label or sample.designerMode.title,
        190,
        148,
        function()
            picker:SetShown(not picker:IsShown())
        end
    )
    picker:SetPoint('TOPLEFT', typeButton, 'BOTTOMLEFT')
    picker:SetSize(304, math.ceil(#A.designerModes / 2) * 24 + 6)
    window:HookScript('OnHide', function()
        picker:Hide()
    end)
    for index, entry in ipairs(A.designerModes) do
        local b = button(picker, entry.label or entry.title, 0, 148, function()
            if inspector then
                inspector:Hide()
            end
            dismiss()
            receipt:SetText('')
            partPicker:Hide()
            pickerSelection = nil
            mode = index
            marked = {}
            collapsed = false
            cleared = false
            selected = 3
            if entry.compact then
                local key = entry.service and 'serviceName'
                    or entry.designType == 'companion' and 'petName'
                    or 'objectLabel'
                for i, part in ipairs(parts) do
                    if part[1] == key then
                        selected = i
                        break
                    end
                end
            end
            sample.designerMode = entry
            typeButton:SetText(entry.label or entry.title)
            picker:Hide()
            A.DrawAuraExample(sample)
            sync()
        end)
        b:ClearAllPoints()
        b:SetPoint('TOPLEFT', 3 + ((index - 1) % 2) * 150, -3 - math.floor((index - 1) / 2) * 24)
    end
    partPicker = CreateFrame('Frame', nil, window, 'BackdropTemplate')
    partPicker:SetPoint('TOPLEFT', selectButton, 'BOTTOMLEFT', 0, -2)
    partPicker:SetWidth(352)
    partPicker:SetFrameLevel(window:GetFrameLevel() + 70)
    partPicker:SetBackdrop({ bgFile = 'Interface\\Buttons\\WHITE8X8' })
    partPicker:SetBackdropColor(0.09, 0.065, 0.04, 1)
    partPicker:EnableMouse(true)
    partPicker:Hide()
    local componentButtons = {}
    for index, part in ipairs(parts) do
        local entry = button(partPicker, part[2], 0, 170, function()
            marked = {}
            collapsed = false
            cleared = false
            pickerSelection = index
            selected = index
            partPicker:Hide()
            sync()
            syncProperties()
            inspector:Show()
        end)
        componentButtons[index] = entry
    end
    partPicker:SetScript('OnShow', function()
        local frame = sample.sample
        local visible = {}
        if frame then
            for _, icon in ipairs(frame.icons or {}) do
                if icon.designKey and icon:IsVisible() then
                    visible[icon.designKey] = true
                end
            end
        end
        local count = 0
        for i, part in ipairs(parts) do
            local entry = componentButtons[i]
            local region = frame and frame[part[1]]
            local shown = visible[part[1]] or (region and region:IsVisible())
            entry:SetShown(not not shown)
            if shown then
                entry:ClearAllPoints()
                entry:SetPoint('TOPLEFT', 4 + (count % 2) * 174, -3 - math.floor(count / 2) * 25)
                count = count + 1
            end
        end
        partPicker:SetHeight(math.ceil(count / 2) * 25 + 6)
    end)
    window:HookScript('OnHide', function()
        partPicker:Hide()
    end)
    local surface = CreateFrame('Frame', nil, sample)
    surface:SetAllPoints()
    surface:SetFrameLevel(sample:GetFrameLevel() + 40)
    surface:EnableMouse(true)
    inspector = CreateFrame('Frame', nil, window, 'BackdropTemplate')
    inspector:SetPoint('TOPRIGHT', -12, -70)
    inspector:SetSize(218, 430)
    inspector:SetFrameLevel(surface:GetFrameLevel() + 12)
    inspector:EnableMouse(true)
    inspector:SetBackdrop({
        bgFile = 'Interface\\Buttons\\WHITE8X8',
        edgeFile = 'Interface\\Buttons\\WHITE8X8',
        edgeSize = 1,
    })
    inspector:SetBackdropColor(0.09, 0.065, 0.04, 0.98)
    inspector:SetBackdropBorderColor(0.62, 0.45, 0.20, 1)
    inspector:Hide()
    window:HookScript('OnHide', function()
        inspector:Hide()
    end)
    local viewport = CreateFrame('ScrollFrame', nil, inspector, 'UIPanelScrollFrameTemplate')
    viewport:SetPoint('TOPLEFT', 2, -2)
    viewport:SetPoint('BOTTOMRIGHT', -24, 3)
    local sections = CreateFrame('Frame', nil, viewport)
    sections:SetSize(210, 410)
    viewport:SetScrollChild(sections)
    A.SizeScrollThumb(viewport)
    inspector:SetWidth(240)
    local panels, headers = {}, {}
    local barFor = { value = 'health', powerValue = 'power', castText = 'cast', castTime = 'cast' }
    local function buildPanel(selected)
        local panel = CreateFrame('Frame', nil, sections)
        panel:SetSize(210, 408)
        local rows = {}
        local function propertyRow(y)
            local row = CreateFrame('Frame', nil, panel)
            row:SetPoint('TOPLEFT', 7, -y)
            row:SetSize(204, 24)
            rows[#rows + 1] = row
            return row
        end
        local fontRow, tintRow = propertyRow(70), propertyRow(104)
        local backgroundRow, lockedRow = propertyRow(70), propertyRow(308)
        local refreshBackground, refreshLocked
        local fontButton, tintField
        local propertyFields = {}
        local visibleCheck, alignButton, outlineButton
        local fontNames = {}
        for name in pairs(A.plateFonts) do
            table.insert(fontNames, name)
        end
        table.sort(fontNames)
        local function refresh()
            local key = parts[selected][1]
            local opt = (A.DesignLayout(sample.sample) or {})[key] or {}
            local region = sample.sample[key]
            local target = region and (region.caption or region)
            fontRow:SetShown(target and target.GetFont ~= nil or false)
            fontButton:SetText(opt.font or 'Use plate font')
            tintRow:SetShown(
                target and (target.SetTextColor or target.SetStatusBarColor or target.SetVertexColor) and true
                    or false
            )
            tintField(region and region.baseBackground and 'Fill colour' or 'Colour')
            backgroundRow:SetShown(region and region.baseBackground ~= nil or false)
            lockedRow:SetShown(key == 'cast')
            if backgroundRow:IsShown() then
                refreshBackground()
            end
            if key == 'cast' then
                refreshLocked()
            end
            for field, control in pairs(propertyFields) do
                control:SetText(opt[field] or (field == 'scale' and 1 or field == 'opacity' and 100 or 0))
            end
            visibleCheck:SetChecked(
                not opt.hidden
                    and not (sample.sample.designerDisabled and sample.sample.designerDisabled[key])
            )
            alignButton:SetText(opt.align or 'Default alignment')
            outlineButton:SetText(opt.outline == '' and 'No outline' or opt.outline or 'Default outline')
            alignButton:GetParent():SetShown(target and target.GetFont ~= nil or false)
            outlineButton:GetParent():SetShown(target and target.GetFont ~= nil or false)
        end
        local function property(field, value)
            local layout = {}
            for k, v in pairs(A.DesignLayout(sample.sample) or {}) do
                layout[k] = v
            end
            local key = parts[selected][1]
            local part = { x = 0, y = 0, scale = 1 }
            for k, v in pairs(layout[key] or {}) do
                part[k] = v
            end
            if field == 'x' or field == 'y' then
                local frame = sample.sample
                local delta = value - (part[field] or 0)
                for child, bar in pairs(barFor) do
                    if bar == key and frame[child] and frame[bar] then
                        local x, y, scale = A.DesignerAura(child, frame)
                        local caption = { x = x, y = y, scale = scale }
                        for k, v in pairs(layout[child] or {}) do
                            caption[k] = v
                        end
                        local ratio = frame[bar]:GetParent():GetEffectiveScale()
                            / frame[child]:GetParent():GetEffectiveScale()
                        caption[field] = caption[field] + delta * ratio
                        layout[child] = caption
                    end
                end
            end
            part[field] = value
            layout[key] = part
            storeLayout(layout)
            changed()
            syncProperties()
            sync()
        end
        label(fontRow, 'Font', 0)
        fontButton = button(fontRow, '', 48, 150, function()
            local opt = (A.DesignLayout(sample.sample) or {})[parts[selected][1]] or {}
            local nextFont = fontNames[1]
            for i, name in ipairs(fontNames) do
                if name == opt.font then
                    nextFont = fontNames[i + 1]
                    break
                end
            end
            property('font', nextFont)
        end)
        local function colourControl(row, caption, field)
            local title = label(row, caption, 0)
            local fill
            local function current()
                local f = sample.sample
                local key = parts[selected][1]
                local opt = (A.DesignLayout(f) or {})[key] or {}
                local hex = opt[field]
                local region = f[key]
                if field == 'lockedTint' then
                    hex = hex or A.db.lockedCastColor
                end
                if field == 'tint' and key == 'cast' then
                    hex = hex or A.db.castColor
                end
                if hex then
                    return tonumber(hex:sub(1, 2), 16) / 255,
                        tonumber(hex:sub(3, 4), 16) / 255,
                        tonumber(hex:sub(5, 6), 16) / 255
                end
                if field == 'backgroundTint' and region and region.baseBackground then
                    return unpack(region.baseBackground)
                end
                local target = region and (region.caption or region)
                local getter = target
                    and (target.GetTextColor or target.GetStatusBarColor or target.GetVertexColor)
                if getter then
                    return getter(target)
                end
                return 1, 1, 1
            end
            local swatch = button(row, '', 102, 41, function()
                local picker = ColorPickerFrame
                local opt = (A.DesignLayout(sample.sample) or {})[parts[selected][1]] or {}
                local original = opt[field]
                local r, g, b = current()
                local function choose()
                    local red, green, blue = picker:GetColorRGB()
                    property(
                        field,
                        ('%02X%02X%02X'):format(
                            math.floor(red * 255 + 0.5),
                            math.floor(green * 255 + 0.5),
                            math.floor(blue * 255 + 0.5)
                        )
                    )
                end
                local function cancel()
                    property(field, original)
                end
                if picker.SetupColorPickerAndShow then
                    picker:SetupColorPickerAndShow({
                        r = r,
                        g = g,
                        b = b,
                        swatchFunc = choose,
                        cancelFunc = cancel,
                        hasOpacity = false,
                    })
                else
                    picker:Hide()
                    picker.hasOpacity = false
                    picker.func = choose
                    picker.cancelFunc = cancel
                    picker:SetColorRGB(r, g, b)
                    picker:Show()
                end
                -- Raise only orders frames within one strata. The designer itself
                -- is FULLSCREEN_DIALOG, above the normal settings dialogs.
                if not picker.rnpDesignerRestoreHook then
                    picker:HookScript('OnHide', function(self)
                        if self.rnpDesignerStrata then
                            self:SetFrameStrata(self.rnpDesignerStrata)
                            self.rnpDesignerStrata = nil
                        end
                    end)
                    picker.rnpDesignerRestoreHook = true
                end
                picker.rnpDesignerStrata = picker.rnpDesignerStrata or picker:GetFrameStrata()
                picker:SetFrameStrata('TOOLTIP')
                picker:Show()
                picker:Raise()
            end)
            fill = swatch:CreateTexture(nil, 'OVERLAY')
            fill:SetPoint('TOPLEFT', 4, -4)
            fill:SetPoint('BOTTOMRIGHT', -4, 4)
            button(row, 'Default', 147, 55, function()
                property(field, nil)
            end)
            return function(text)
                title:SetText(text or caption)
                local r, g, b = current()
                fill:SetColorTexture(r, g, b)
            end
        end
        tintField = colourControl(tintRow, 'Colour', 'tint')
        refreshBackground = colourControl(backgroundRow, 'Background', 'backgroundTint')
        refreshLocked = colourControl(lockedRow, 'Uninterruptible', 'lockedTint')
        local visibilityRow = propertyRow(138)
        visibleCheck = CreateFrame('CheckButton', nil, visibilityRow, 'UICheckButtonTemplate')
        visibleCheck:SetPoint('LEFT')
        visibleCheck.Text:SetText('Show component')
        visibleCheck:SetScript('OnClick', function()
            local enabled = not not visibleCheck:GetChecked()
            local f = sample.sample
            local setting = f.designerSettings and f.designerSettings[parts[selected][1]]
            if setting and enabled then
                A.db[setting] = true
            end
            property('hidden', not enabled)
            if setting and A.SyncOptions then
                A.SyncOptions()
            end
        end)
        local function numeric(field, title, y, minimum, maximum, step)
            local r = propertyRow(y)
            label(r, title, 0)
            local edit = CreateFrame('EditBox', nil, r, 'InputBoxTemplate')
            edit:SetPoint('LEFT', 97, 0)
            edit:SetSize(61, 20)
            edit:SetAutoFocus(false)
            propertyFields[field] = edit
            local function apply(value)
                if value then
                    property(field, math.max(minimum, math.min(maximum, value)))
                else
                    syncProperties()
                end
                edit:ClearFocus()
            end
            edit:SetScript('OnEnterPressed', function()
                apply(tonumber(edit:GetText()))
            end)
            edit:SetScript('OnEscapePressed', function()
                edit:ClearFocus()
                syncProperties()
            end)
            button(r, '-', 65, 25, function()
                apply((tonumber(edit:GetText()) or minimum) - step)
            end)
            button(r, '+', 168, 25, function()
                apply((tonumber(edit:GetText()) or minimum) + step)
            end)
        end
        numeric('x', 'X offset', 172, -1000, 1000, 1)
        numeric('y', 'Y offset', 206, -1000, 1000, 1)
        numeric('scale', 'Scale', 240, 0.25, 3, 0.05)
        numeric('opacity', 'Opacity %', 274, 0, 100, 5)
        local alignments = { 'LEFT', 'CENTER', 'RIGHT' }
        alignButton = button(propertyRow(308), '', 0, 198, function()
            local opt = (A.DesignLayout(sample.sample) or {})[parts[selected][1]] or {}
            local nextValue = alignments[1]
            for i, value in ipairs(alignments) do
                if value == opt.align then
                    nextValue = alignments[i + 1]
                    break
                end
            end
            property('align', nextValue)
        end)
        local outlines = { 'OUTLINE', 'THICKOUTLINE', '' }
        outlineButton = button(propertyRow(342), '', 0, 198, function()
            local opt = (A.DesignLayout(sample.sample) or {})[parts[selected][1]] or {}
            local nextValue = outlines[1]
            for i, value in ipairs(outlines) do
                if value == opt.outline then
                    nextValue = outlines[i + 1]
                    break
                end
            end
            property('outline', nextValue)
        end)
        local function pack()
            local height = 4
            for _, r in ipairs(rows) do
                if r:IsShown() then
                    r:ClearAllPoints()
                    r:SetPoint('TOPLEFT', 7, -height)
                    height = height + 26
                end
            end
            panel:SetHeight(height)
            return height
        end
        return { frame = panel, refresh = refresh, property = property, pack = pack }
    end
    syncProperties = function()
        local height = 0
        for i, part in ipairs(parts) do
            if marked[i] or i == selected then
                if not headers[i] then
                    local index = i
                    local tab = CreateFrame('Button', nil, sections)
                    tab:SetSize(204, 23)
                    tab.fill = tab:CreateTexture(nil, 'BACKGROUND')
                    tab.fill:SetAllPoints()
                    label(tab, part[2], 8)
                    tab:SetScript('OnClick', function()
                        collapsed = selected == index and not collapsed
                        selected = index
                        sync()
                        viewport:SetVerticalScroll(
                            math.min(headers[index].offset, viewport:GetVerticalScrollRange() or 0)
                        )
                    end)
                    headers[i] = tab
                end
                local tab = headers[i]
                tab.offset = height
                tab:SetPoint('TOPLEFT', 3, -height)
                tab.fill:SetColorTexture(
                    i == selected and 0.38 or 0.15,
                    i == selected and 0.25 or 0.10,
                    0.05,
                    1
                )
                tab:Show()
                height = height + 25
                if i == selected and not collapsed then
                    panels[i] = panels[i] or buildPanel(i)
                    local panel = panels[i]
                    panel.frame:SetPoint('TOPLEFT', 0, -height)
                    panel.frame:Show()
                    panel.refresh()
                    height = height + panel.pack()
                    if syncShared then
                        height = height + syncShared(height)
                    end
                end
            elseif headers[i] then
                headers[i]:Hide()
            end
            if panels[i] and (i ~= selected or collapsed) then
                panels[i].frame:Hide()
            end
        end
        sections:SetHeight(height)
        if syncShared and collapsed then
            syncShared(nil)
        end
    end
    local function property(field, value)
        panels[selected].property(field, value)
    end
    if designerRows then
        local host = CreateFrame('Frame', nil, sections)
        host:SetSize(405, 1)
        local scale = 0.82
        host:SetScale(scale)
        inspector:SetWidth(370)
        canvas:SetPoint('BOTTOMRIGHT', -391, 172)
        local last
        syncShared = function(top)
            if not top then
                if last then
                    designerRows(nil)
                    last = nil
                end
                host:Hide()
                return 0
            end
            local key = parts[selected][1]
            local kind = sample.designerMode.designType
            if last ~= key .. kind then
                designerRows(host, key, kind)
                last = key .. kind
            end
            host:SetPoint('TOPLEFT', 0, -top / scale)
            host:Show()
            return host:GetHeight() * scale + 4
        end
        inspector:HookScript('OnHide', function()
            syncShared(nil)
        end)
    end
    local push = CreateFrame('CheckButton', nil, footer, 'UICheckButtonTemplate')
    push:SetPoint('LEFT', 375, 0)
    push.Text:SetText('Push neighbours')
    push:SetScript('OnShow', function(self)
        self:SetChecked(A.db.designerPushNeighbours ~= false)
    end)
    push:SetScript('OnClick', function(self)
        A.db.designerPushNeighbours = not not self:GetChecked()
    end)
    local outlines = {}
    updateSelection = function()
        local f = sample.sample
        local count = 0
        local function highlight(region)
            if not region or not region:IsShown() then
                return
            end
            count = count + 1
            local outline = outlines[count]
            if not outline then
                outline = CreateFrame('Frame', nil, surface, 'BackdropTemplate')
                outline:SetBackdrop({ edgeFile = 'Interface\\Buttons\\WHITE8X8', edgeSize = 1 })
                outline:SetBackdropBorderColor(1, 0.82, 0.18, 1)
                outline:EnableMouse(false)
                outlines[count] = outline
            end
            outline:ClearAllPoints()
            outline:SetAllPoints(region)
            outline:Show()
        end
        if f and not cleared then
            for i, part in ipairs(parts) do
                if i == selected or marked[i] then
                    highlight(f[part[1]])
                    for _, icon in ipairs(f.icons or {}) do
                        if icon.designKey == part[1] then
                            highlight(icon)
                        end
                    end
                end
            end
        end
        for i = count + 1, #outlines do
            outlines[i]:Hide()
        end
    end
    window:EnableKeyboard(true)
    window:SetPropagateKeyboardInput(true)
    local arrows = { LEFT = { 'x', -1 }, RIGHT = { 'x', 1 }, UP = { 'y', 1 }, DOWN = { 'y', -1 } }
    local heldKey, delay
    local function canNudge()
        return inspector:IsShown()
            and not cleared
            and not sample.designerDragging
            and not (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus())
    end
    local function nudge(key)
        local move = arrows[key]
        local x, y = A.DesignerAura(parts[selected][1], sample.sample)
        property(move[1], (move[1] == 'x' and x or y) + move[2] * (IsShiftKeyDown() and 10 or 1))
    end
    local function stopRepeat()
        heldKey = nil
        window:SetScript('OnUpdate', nil)
    end
    local function repeatArrow(_, elapsed)
        if not canNudge() then
            stopRepeat()
            return
        end
        delay = delay - elapsed
        if delay <= 0 then
            nudge(heldKey)
            delay = 0.075
        end
    end
    window:SetScript('OnKeyDown', function(self, key)
        local consume = arrows[key] and canNudge()
        self:SetPropagateKeyboardInput(not consume)
        if consume and heldKey ~= key then
            heldKey, delay = key, 0.32
            nudge(key)
            self:SetScript('OnUpdate', repeatArrow)
        end
    end)
    window:SetScript('OnKeyUp', function(_, key)
        if key == heldKey then
            stopRepeat()
        end
    end)
    window:HookScript('OnHide', stopRepeat)
    inspector:HookScript('OnHide', stopRepeat)
    local function hitRect(region, key)
        local x, y, w, h = region:GetRect()
        if x and key == 'castText' and region.GetStringWidth then
            local ink = math.min(w, region:GetStringWidth() + 3)
            local align = region:GetJustifyH()
            x = x + (align == 'RIGHT' and w - ink or align == 'CENTER' and (w - ink) / 2 or 0)
            w = ink
        end
        return x, y, w, h
    end
    local function hitPart(f)
        local best, area
        local cx, cy = GetCursorPosition()
        local function hit(index, region)
            if region and region:IsVisible() and region:GetAlpha() > 0 then
                local x, y, w, h = hitRect(region, parts[index][1])
                local scale = region.GetEffectiveScale and region:GetEffectiveScale()
                    or region:GetParent():GetEffectiveScale()
                if
                    not x
                    or cx < x * scale
                    or cx > (x + w) * scale
                    or cy < y * scale
                    or cy > (y + h) * scale
                then
                    return
                end
                local footprint = w * h * scale ^ 2
                if pickerSelection == index then
                    best, area = index, -1
                elseif not area or footprint < area then
                    best, area = index, footprint
                end
            end
        end
        for i, part in ipairs(parts) do
            hit(i, f[part[1]])
            for _, icon in ipairs(f.icons or {}) do
                if icon.designKey == part[1] then
                    hit(i, icon)
                end
            end
        end
        return best
    end
    -- Store screen-space bounds at mouse-down so the snap targets never chase
    -- the moving part. Each axis releases when it leaves the magnetic radius.
    local function bounds(region)
        if not region or not region:IsVisible() then
            return
        end
        local x, y, w, h = region:GetRect()
        if not x or not y or not w or not h then
            return
        end
        local k = region.GetEffectiveScale and region:GetEffectiveScale()
            or region:GetParent():GetEffectiveScale()
        return { x * k, y * k, (x + w) * k, (y + h) * k }
    end
    local function snapAxis(first, last, near, far, delta, radius)
        local best
        for _, a in ipairs({ first, last, (first + last) / 2 }) do
            for _, b in ipairs({ near, far, (near + far) / 2 }) do
                local d = b - a - delta
                if math.abs(d) <= radius and (not best or math.abs(d) < math.abs(best)) then
                    best = d
                end
            end
        end
        return best
    end
    local function snap(d, dx, dy)
        local r = d.rect
        if not r or A.db.designerSnap == false then
            return dx, dy
        end
        local bestX, bestY
        if d.auraRows[d.key] then
            local nearest
            for _, part in ipairs(parts) do
                local key = part[1]
                local target = d.auraRows[key]
                if target and not d.moving[key] then
                    local leftGap = target[1] - r[3] - dx
                    local rightGap = target[3] - r[1] - dx
                    local edge = math.abs(leftGap) < math.abs(rightGap) and leftGap or rightGap
                    local top = target[4] - r[4] - dy
                    local reach = math.min(r[4] - r[2], target[4] - target[2]) + 3
                    local score = math.abs(edge) + math.abs(top)
                    if
                        math.abs(edge) <= 6
                        and math.abs(top) <= math.max(8, reach)
                        and (not nearest or score < nearest.score)
                    then
                        nearest = { edge = edge, top = top, score = score }
                    end
                end
            end
            if nearest then
                return dx + nearest.edge, dy + nearest.top, true
            end
        end
        for _, t in ipairs(d.targets) do
            local gx = math.max(0, t[1] - r[3] - dx, r[1] + dx - t[3])
            local gy = math.max(0, t[2] - r[4] - dy, r[2] + dy - t[4])
            if gx <= 16 and gy <= 16 then
                local x = snapAxis(r[1], r[3], t[1], t[3], dx, 5)
                local y = snapAxis(r[2], r[4], t[2], t[4], dy, 5)
                if x and (not bestX or math.abs(x) < math.abs(bestX)) then
                    bestX = x
                end
                if y and (not bestY or math.abs(y) < math.abs(bestY)) then
                    bestY = y
                end
            end
        end
        return dx + (bestX or 0), dy + (bestY or 0)
    end
    local function union(a, b)
        if not a then
            return b
        end
        return { math.min(a[1], b[1]), math.min(a[2], b[2]), math.max(a[3], b[3]), math.max(a[4], b[4]) }
    end
    local function overlaps(a, b)
        return a[1] < b[3] - 0.001 and a[3] > b[1] + 0.001 and a[2] < b[4] - 0.001 and a[4] > b[2] + 0.001
    end
    -- Place neighbours against the dragged group first, then against each
    -- displaced group. Unaffected parts keep their mouse-down positions.
    local function moveNeighbours(d, draft, dx, dy)
        local moving = d.groups[d.key]
        if not moving or (dx == 0 and dy == 0) then
            return
        end
        local r = moving.rect
        local fixed = { { r[1] + dx, r[2] + dy, r[3] + dx, r[4] + dy } }
        local function offset(key, x, y)
            local base = d.base[key] or { x = 0, y = 0, scale = 1 }
            local units = d.unitsByKey[key]
            draft[key] = {}
            for field, value in pairs(base) do
                draft[key][field] = value
            end
            draft[key].x, draft[key].y = base.x + x / units, base.y + (d.clearance[key] or 0) + y / units
        end
        for _, key in ipairs(moving.members) do
            if key ~= d.key then
                offset(key, dx, dy)
            end
        end
        local placed = { [d.key] = true }
        for index = 1, #parts do
            local obstacle = fixed[index]
            if not obstacle then
                break
            end
            for _, part in ipairs(parts) do
                local key = part[1]
                local group = d.groups[key]
                if group and not placed[key] and overlaps(group.rect, obstacle) then
                    local box = group.rect
                    local best
                    -- Test the proposed destination against stationary groups too.
                    -- Include their edges as candidates so tight but usable gaps win.
                    local obstacles = {}
                    for _, rect in ipairs(fixed) do
                        obstacles[#obstacles + 1] = rect
                    end
                    for _, partInfo in ipairs(parts) do
                        local id = partInfo[1]
                        if id ~= key and not placed[id] and d.groups[id] then
                            obstacles[#obstacles + 1] = d.groups[id].rect
                        end
                    end
                    local xs, ys = { 0 }, { 0 }
                    for _, rect in ipairs(obstacles) do
                        xs[#xs + 1] = rect[1] - box[3]
                        xs[#xs + 1] = rect[3] - box[1]
                        ys[#ys + 1] = rect[2] - box[4]
                        ys[#ys + 1] = rect[4] - box[2]
                    end
                    for _, x in ipairs(xs) do
                        for _, y in ipairs(ys) do
                            local distance = math.abs(x) + math.abs(y)
                            if not best or distance < best.distance then
                                local rect = { box[1] + x, box[2] + y, box[3] + x, box[4] + y }
                                local clear = true
                                for _, other in ipairs(obstacles) do
                                    if overlaps(rect, other) then
                                        clear = false
                                        break
                                    end
                                end
                                if clear then
                                    best = { x = x, y = y, rect = rect, distance = distance }
                                end
                            end
                        end
                    end
                    if best then
                        for _, member in ipairs(group.members) do
                            offset(member, best.x, best.y)
                        end
                        fixed[#fixed + 1] = best.rect
                        placed[key] = true
                    end
                end
            end
        end
    end
    local drag, pan, box
    local marquee = surface:CreateTexture(nil, 'OVERLAY')
    marquee:SetColorTexture(1, 0.82, 0.18, 0.23)
    marquee:Hide()
    local function boxSelection(commit)
        if not box then
            return
        end
        local x, y = GetCursorPosition()
        local l, r = math.min(x, box.x), math.max(x, box.x)
        local b, t = math.min(y, box.y), math.max(y, box.y)
        local k = surface:GetEffectiveScale()
        if not commit then
            marquee:SetPoint(
                'BOTTOMLEFT',
                surface,
                'BOTTOMLEFT',
                l / k - surface:GetLeft(),
                b / k - surface:GetBottom()
            )
            marquee:SetSize(math.max(1, (r - l) / k), math.max(1, (t - b) / k))
            marquee:Show()
            return
        end
        box = nil
        marquee:Hide()
        marked = {}
        local first
        local function include(i, region)
            if not region or not region:IsVisible() or region:GetAlpha() == 0 then
                return
            end
            local x, y, w, h = hitRect(region, parts[i][1])
            local scale = region.GetEffectiveScale and region:GetEffectiveScale()
                or region:GetParent():GetEffectiveScale()
            if x and x * scale <= r and (x + w) * scale >= l and y * scale <= t and (y + h) * scale >= b then
                marked[i] = true
                first = first or i
            end
        end
        for i, part in ipairs(parts) do
            include(i, sample.sample[part[1]])
            for _, icon in ipairs(sample.sample.icons or {}) do
                if icon.designKey == part[1] then
                    include(i, icon)
                end
            end
        end
        inspector:Hide()
        cleared = not first
        if first then
            collapsed = false
            selected = first
            viewport:SetVerticalScroll(0)
            syncProperties()
            inspector:Show()
        end
        sync()
    end
    A.InitPreviewCamera(sample)
    local cameraText = label(footer, '100%', 205)
    button(footer, 'Centre view', 259, 103, function()
        sample.cameraX, sample.cameraY, sample.cameraZoom = 0, 0, 1
        cameraText:SetText('100%')
        sample:PositionCamera()
    end)
    surface:EnableMouseWheel(true)
    surface:SetScript('OnMouseWheel', function(_, delta)
        if drag or pan or box then
            return
        end
        local zoom = sample:ZoomCamera(delta)
        cameraText:SetText(('%d%%'):format(math.floor(zoom * 100 + 0.5)))
    end)
    surface:SetScript('OnMouseDown', function(_, mouse)
        if mouse ~= 'LeftButton' and mouse ~= 'RightButton' then
            return
        end
        if drag or pan or box then
            return
        end
        local mx, my = GetCursorPosition()
        local hit = hitPart(sample.sample)
        if mouse == 'RightButton' and not hit then
            pan = { cx = mx, cy = my, x = sample.cameraX, y = sample.cameraY }
            return
        end
        if mouse == 'LeftButton' and (not hit or IsShiftKeyDown()) then
            box = { x = mx, y = my }
            return
        end
        if not marked[hit] then
            marked = {}
        end
        viewport:SetVerticalScroll(0)
        pickerSelection = nil
        cleared = false
        collapsed = false
        selected = hit
        syncProperties()
        inspector:Show()
        local key = parts[selected][1]
        local x, y, s = A.DesignerAura(key, sample.sample)
        local cx, cy = GetCursorPosition()
        local region = sample.sample[key]
        local owner = region and region:GetParent() or sample.sample
        local units = owner:GetEffectiveScale()
        drag = {
            mouse = mouse,
            key = key,
            x = x,
            y = y,
            scale = s,
            cx = cx,
            cy = cy,
            units = units,
            region = region,
        }
        drag.base = A.DesignLayout(sample.sample) or {}
        drag.targets, drag.groups, drag.unitsByKey, drag.icons = {}, {}, {}, {}
        local moving = { [key] = true }
        if mouse == 'LeftButton' then
            for index in pairs(marked) do
                moving[parts[index][1]] = true
            end
        end
        drag.auraRows = {}
        drag.moving = moving
        drag.clearance = {}
        local function addBounds(r, k)
            local b = bounds(r)
            if not b then
                return
            end
            drag.clearance[k] = r.rnpClearanceY or 0
            drag.unitsByKey[k] = r:GetParent():GetEffectiveScale()
            if r.designKey then
                drag.auraRows[k] = union(drag.auraRows[k], b)
            end
            if not moving[k] then
                table.insert(drag.targets, b)
            else
                drag.rect = union(drag.rect, b)
            end
            -- A separately selected text label can be placed inside its own bar.
            local groupKey = barFor[k] or k
            if groupKey == barFor[key] and not moving[k] then
                return
            end
            if moving[k] then
                groupKey = key
            end
            local group = drag.groups[groupKey] or { members = {} }
            drag.groups[groupKey] = group
            group.rect = union(group.rect, b)
            if group.members[#group.members] ~= k then
                table.insert(group.members, k)
            end
        end
        for _, part in ipairs(parts) do
            addBounds(sample.sample[part[1]], part[1])
        end
        for _, icon in ipairs(sample.sample.icons or {}) do
            if icon.designKey and icon:IsShown() then
                addBounds(icon, icon.designKey)
                local point, parent, anchor, px, py = icon:GetPoint(1)
                drag.icons[#drag.icons + 1] = {
                    icon = icon,
                    key = icon.designKey,
                    point = point,
                    parent = parent,
                    anchor = anchor,
                    x = px,
                    y = py,
                    width = icon:GetWidth(),
                    height = icon:GetHeight(),
                }
            end
        end
        sample.designerDragging = true
        sync()
    end)
    local function finish(commit)
        if not drag then
            return
        end
        local draft = drag.draft
        if commit and drag.mouse == 'RightButton' and not drag.started then
            local mx, my = GetCursorPosition()
            if (mx - drag.cx) ^ 2 + (my - drag.cy) ^ 2 < 64 then
                for index, part in ipairs(parts) do
                    local key = part[1]
                    local original = drag.base[key]
                    if
                        (index == selected or marked[index])
                        and original
                        and ((original.x or 0) ~= 0 or (original.y or 0) ~= 0)
                    then
                        if not draft then
                            draft = {}
                            for k, v in pairs(drag.base) do
                                draft[k] = v
                            end
                        end
                        local reset = {}
                        for k, v in pairs(original) do
                            reset[k] = v
                        end
                        reset.x, reset.y = 0, 0
                        draft[key] = reset
                    end
                end
            end
        end
        sample.sample.designerMoving = nil
        drag = nil
        sample.designerDragging = nil
        if commit then
            syncProperties()
            inspector:Show()
        end
        if commit and draft then
            storeLayout(draft)
            changed()
        end
        if sample:IsVisible() then
            A.DrawAuraExample(sample)
            sync()
        end
    end
    surface:SetScript('OnUpdate', function()
        if box then
            boxSelection(not IsMouseButtonDown('LeftButton'))
            return
        end
        if pan then
            if not IsMouseButtonDown('RightButton') then
                pan = nil
                return
            end
            local x, y = GetCursorPosition()
            local k = sample:GetEffectiveScale()
            sample.cameraX = pan.x + (x - pan.cx) / k
            sample.cameraY = pan.y + (y - pan.cy) / k
            sample:PositionCamera()
            return
        end
        if not drag then
            return
        end
        if not IsMouseButtonDown(drag.mouse) then
            finish(true)
            return
        end
        local cx, cy = GetCursorPosition()
        local factor = drag.units
        local dx, dy = cx - drag.cx, cy - drag.cy
        if not drag.started then
            if dx * dx + dy * dy < 64 then
                return
            end
            drag.started = true
        end
        local edgeSnapped
        if drag.mouse == 'LeftButton' then
            dx, dy, edgeSnapped = snap(drag, dx, dy)
        end
        dx, dy = dx / factor, dy / factor
        local function round(n)
            return math.floor(n + 0.5)
        end
        local x, y, s = drag.x, drag.y, drag.scale

        if drag.mouse == 'RightButton' then
            s = math.max(0.25, math.min(3, round(s * 100 + dx) / 100))
        else
            if edgeSnapped then
                x, y = x + dx, y + dy
            else
                x, y = round(x + dx), round(y + dy)
            end
        end
        if drag.lastX == x and drag.lastY == y and drag.lastScale == s then
            return
        end
        drag.lastX, drag.lastY, drag.lastScale = x, y, s
        local draft = {}
        for k, v in pairs(drag.base) do
            draft[k] = v
        end
        local original = drag.base[drag.key] or {}
        draft[drag.key] = {}
        for field, value in pairs(original) do
            draft[drag.key][field] = value
        end
        draft[drag.key].x, draft[drag.key].y, draft[drag.key].scale = x, y, s
        if A.db.designerPushNeighbours ~= false and drag.mouse == 'LeftButton' then
            moveNeighbours(drag, draft, (x - drag.x) * factor, (y - drag.y) * factor)
        end
        for k in pairs(drag.moving) do
            if k ~= drag.key and drag.unitsByKey[k] then
                local base = drag.base[k] or {}
                local moved = { scale = 1 }
                for field, value in pairs(base) do
                    moved[field] = value
                end
                local ratio = factor / drag.unitsByKey[k]
                moved.x = (base.x or 0) + (x - drag.x) * ratio
                moved.y = (base.y or 0) + (drag.clearance[k] or 0) + (y - drag.y) * ratio
                draft[k] = moved
            end
        end
        if drag.mouse == 'LeftButton' then
            sample.sample.designerMoving = drag.moving
            draft[drag.key].y = y + (drag.clearance[drag.key] or 0)
        end
        drag.draft = draft
        renderingDraft = draft
        A.DesignPlate(sample.sample)
        for _, saved in ipairs(drag.icons) do
            local base = drag.base[saved.key] or { scale = 1 }
            local now = draft[saved.key] or base
            local ratio = now.scale / base.scale
            saved.icon:SetSize(saved.width * ratio, saved.height * ratio)
        end
        if A.RefreshDesignerTimers then
            A.RefreshDesignerTimers(sample.sample)
        end
        renderingDraft = nil
        readout:SetText(('%+.0f, %+.0f   %d%%'):format(x, y, math.floor(s * 100 + 0.5)))
    end)
    surface:SetScript('OnMouseUp', function()
        boxSelection(true)
        pan = nil
        finish(true)
    end)
    surface:SetScript('OnHide', function()
        box = nil
        marquee:Hide()
        pan = nil
        finish(false)
    end)
    sample:SetScript('OnShow', function()
        A.DrawAuraExample(sample)
        sync()
    end)
    return function()
        if sample:IsVisible() and not sample.designerDragging then
            A.DrawAuraExample(sample)
            sync()
        end
    end
end
