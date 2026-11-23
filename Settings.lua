local _, A = ...
local registry = RaynnaModsSettingsRegistry
local groups = {
    'General',
    'Personal',
    'NPCs',
    'Players',
    'Party',
    'Targeting',
    'Quests',
    'Auras',
    'Castbar',
    'Colours',
    'Text',
    'Designer',
}
local function button(parent, caption, x, width, click)
    local b = CreateFrame('Button', nil, parent, 'UIPanelButtonTemplate')
    b:SetPoint('LEFT', parent, 'LEFT', x, 0)
    b:SetSize(width, 23)
    b:SetText(caption)
    b:SetScript('OnClick', click)
    return b
end
local function label(parent, caption, x)
    local t = parent:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
    t:SetPoint('LEFT', parent, 'LEFT', x, 0)
    t:SetText(caption)
    return t
end
local function input(parent, x, width)
    local e = CreateFrame('EditBox', nil, parent, 'InputBoxTemplate')
    e:SetPoint('LEFT', parent, 'LEFT', x, 0)
    e:SetSize(width, 22)
    e:SetAutoFocus(false)
    return e
end
local function rgb(hex)
    return tonumber(hex:sub(1, 2), 16) / 255,
        tonumber(hex:sub(3, 4), 16) / 255,
        tonumber(hex:sub(5, 6), 16) / 255
end
function A.TogglePreview()
    A.db.preview = not A.db.preview
    A.Refresh()
    if A.SyncOptions then
        A.SyncOptions()
    end
end
function A.RegisterSettings()
    registry:Register('raynnanameplates', 'Nameplates', function(page)
        local header = CreateFrame('Frame', nil, page)
        header:SetPoint('TOPLEFT', 16, -5)
        header:SetSize(420, 30)
        label(header, 'Search settings', 0)
        local search = input(header, 104, 206)
        local clearSearch = button(header, 'Clear', 324, 66, function()
            search:SetText('')
            search:ClearFocus()
        end)
        local nav = CreateFrame('Frame', nil, page)
        nav:SetPoint('TOPLEFT', 12, -39)
        nav:SetSize(106, #groups * 24)
        local divider = nav:CreateTexture(nil, 'BACKGROUND')
        divider:SetColorTexture(0.55, 0.40, 0.19, 0.65)
        divider:SetPoint('TOPRIGHT')
        divider:SetPoint('BOTTOMRIGHT')
        divider:SetWidth(1)
        local scroll = CreateFrame('ScrollFrame', nil, page, 'UIPanelScrollFrameTemplate')
        scroll:SetPoint('TOPLEFT', 16, -119)
        scroll:SetPoint('BOTTOMRIGHT', -30, 39)
        local body = CreateFrame('Frame', nil, scroll)
        body:SetSize(405, 1)
        scroll:SetScrollChild(body)
        local empty = label(body, 'No matching settings', 6)
        empty:ClearAllPoints()
        empty:SetPoint('TOPLEFT', 6, -8)
        local heading = page:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
        heading:SetPoint('TOPLEFT', 20, -99)
        local rows, tabs = {}, {}
        local current = 'General'
        local example = CreateFrame('Frame', nil, page, 'BackdropTemplate')
        example:SetBackdrop({
            bgFile = 'Interface\\Buttons\\WHITE8X8',
            edgeFile = 'Interface\\Buttons\\WHITE8X8',
            edgeSize = 1,
        })
        example:SetBackdropColor(0.065, 0.047, 0.032, 0.85)
        example:SetBackdropBorderColor(0.57, 0.43, 0.23, 0.9)
        example:SetClipsChildren(true)
        local selector = CreateFrame('Frame', nil, page)
        selector:SetSize(260, 24)
        local friendlyTab, enemyTab
        local expanded = false
        local function positionPreview()
            local left = 128
            local top = 39
            local scale = math.min(1, math.max(0.1, (page:GetWidth() - left - 30) / 405))
            body:SetScale(scale)
            local height = expanded and 236 or 148
            local contentTop = current == 'Designer' and top or top + height + 7
            example:SetShown(current ~= 'Designer')
            example:ClearAllPoints()
            example:SetPoint('TOPLEFT', page, 'TOPLEFT', left, -top)
            example:SetPoint('TOPRIGHT', page, 'TOPRIGHT', -8, -top)
            example:SetHeight(height)
            selector:ClearAllPoints()
            selector:SetPoint('TOPLEFT', page, 'TOPLEFT', left, -contentTop)
            if selector:IsShown() then
                contentTop = contentTop + 29
            end
            heading:ClearAllPoints()
            heading:SetPoint('TOPLEFT', left + 4, -contentTop)
            scroll:ClearAllPoints()
            scroll:SetPoint('TOPLEFT', left, -contentTop - 20)
            scroll:SetPoint('BOTTOMRIGHT', -30, 39)
        end
        local resizePreview = CreateFrame('Button', nil, example, 'UIPanelButtonTemplate')
        resizePreview:SetPoint('TOPRIGHT', -3, -3)
        resizePreview:SetSize(60, 18)
        resizePreview:SetText('Expand')
        resizePreview:SetFrameLevel(example:GetFrameLevel() + 10)
        resizePreview:SetScript('OnClick', function()
            expanded = not expanded
            resizePreview:SetText(expanded and 'Compact' or 'Expand')
            positionPreview()
            A.DrawAuraExample(example)
        end)
        positionPreview()
        page:HookScript('OnSizeChanged', function()
            positionPreview()
            if example:IsVisible() then
                A.DrawAuraExample(example)
            end
        end)
        example:SetScript('OnShow', function()
            A.DrawAuraExample(example)
        end)
        local function layout()
            example.category = current
            if example:IsVisible() then
                A.DrawAuraExample(example)
            end
            local query = (search:GetText() or ''):lower():match('^%s*(.-)%s*$')
            clearSearch:SetShown(search:GetText() ~= '')
            selector:SetShown(current == 'Players' and query == '')
            friendlyTab:SetEnabled(A.db.previewEnemyPlayer == true)
            enemyTab:SetEnabled(A.db.previewEnemyPlayer ~= true)
            positionPreview()
            local selected = current
            if current == 'Players' then
                selected = A.db.previewEnemyPlayer and 'Enemy players' or 'Friendly players'
            end
            local count, height = 0, 0
            for _, r in ipairs(rows) do
                local visible = query == ''
                        and (r.group == selected or (selected == 'Colours' and r.castColour) or (selected == 'Friendly players' and r.group == 'Party'))
                    or query ~= '' and r.terms:find(query, 1, true)
                r:SetShown(not not visible)
                if visible then
                    r:ClearAllPoints()
                    r:SetPoint('TOPLEFT', 0, -height)
                    count = count + 1
                    height = height + r:GetHeight() + 2
                end
            end
            heading:SetText(query == '' and selected or ('Search results (' .. count .. ')'))
            empty:SetShown(count == 0)
            body:SetHeight(math.max(32, height))
            scroll:SetVerticalScroll(0)
            for name, b in pairs(tabs) do
                b.selectedFill:SetShown(query == '' and name == current)
            end
        end
        local function selectPlayers(enemy)
            A.db.previewEnemyPlayer = enemy
            layout()
        end
        friendlyTab = button(selector, 'Friendly players', 0, 118, function()
            selectPlayers(false)
        end)
        enemyTab = button(selector, 'Enemy players', 124, 118, function()
            selectPlayers(true)
        end)
        for i, group in ipairs(groups) do
            local name = group
            local entry = CreateFrame('Button', nil, nav)
            tabs[name] = entry
            entry:SetSize(102, 23)
            entry.selectedFill = entry:CreateTexture(nil, 'BACKGROUND')
            entry.selectedFill:SetAllPoints()
            entry.selectedFill:SetColorTexture(0.55, 0.38, 0.12, 0.52)
            label(entry, name, 8)
            entry:SetHighlightTexture('Interface\\QuestFrame\\UI-QuestTitleHighlight')
            entry:SetScript('OnClick', function()
                current = name
                search:SetText('')
                search:ClearFocus()
                layout()
                if name == 'Designer' and A.OpenDesigner then
                    A.OpenDesigner()
                end
            end)
            tabs[name]:ClearAllPoints()
            tabs[name]:SetPoint('TOPLEFT', 0, -(i - 1) * 24)
        end
        local function row(group, title, aliases)
            local r = CreateFrame('Frame', nil, body)
            r:SetSize(405, 30)
            r.resetTitle = title
            r.group = group
            r.terms = (group .. ' ' .. title .. ' ' .. (aliases or '')):lower()
            rows[#rows + 1] = r
            return r
        end
        local refreshDesigner
        local function changed()
            A.RefreshFonts()
            A.launcher:SetShown(A.db.minimap)
            A.Refresh()
            if A.RefreshPlateDistances then
                A.RefreshPlateDistances()
            end
            if current == 'Targeting' then
                positionPreview()
            end
            if A.RefreshAuraExample then
                A.RefreshAuraExample()
            end
            if refreshDesigner then
                refreshDesigner()
            end
        end
        local function addReset(r, key)
            r.settingKey = key
            button(r, 'Reset', 358, 47, function()
                if key == 'personal' then
                    A.FinishPersonalSetup()
                end
                local value = A.NewProfile()[key]
                if key == 'buffs' or key == 'castableBuffs' then
                    A.SetBuffOption(key, value)
                else
                    A.db[key] = value
                end
                if key == 'viewDistance' then
                    A.ApplyNativeDistance(value)
                    A.RefreshPlateDistances()
                end
                A.SyncOptions()
                changed()
                A.ReportReset(r.resetTitle .. ' reset.')
            end)
        end
        local function check(group, key, title, aliases)
            local r = row(group, title, aliases)
            addReset(r, key)
            local c = CreateFrame('CheckButton', nil, r, 'UICheckButtonTemplate')
            c:SetPoint('LEFT', 0, 0)
            c.Text:SetText(title)
            c:SetScript('OnClick', function()
                if key == 'personal' then
                    A.FinishPersonalSetup()
                end
                local enabled = not not c:GetChecked()
                if key == 'buffs' or key == 'castableBuffs' then
                    A.SetBuffOption(key, enabled)
                    A.SyncOptions()
                else
                    A.db[key] = enabled
                end
                changed()
            end)
            r.sync = function()
                c:SetChecked(A.db[key])
            end
        end
        local function number(group, key, title, min, max, step, suffix, aliases)
            local r = row(group, title, aliases)
            addReset(r, key)
            label(r, title, 4)
            local field = input(r, 249, 60)
            local function value()
                return A.db[key] or 18
            end
            r.sync = function()
                field:SetText(value() .. suffix)
            end
            local function apply(n)
                if n then
                    A.db[key] = math.min(max, math.max(min, math.floor(n)))
                end
                field:ClearFocus()
                r.sync()
                changed()
            end
            button(r, '-', 211, 28, function()
                apply(value() - step)
            end)
            button(r, '+', 318, 28, function()
                apply(value() + step)
            end)
            field:SetScript('OnEnterPressed', function()
                apply(
                    tonumber(
                        (
                            field:GetText():match('^%s*(%-?%d+)%s*%%?%s*$')
                            or field:GetText():match('^%s*(%d+)%s*px%s*$')
                        )
                    )
                )
            end)
            field:SetScript('OnEscapePressed', function()
                field:ClearFocus()
                r.sync()
            end)
        end
        local openRow = row('Designer', 'Open layout designer', 'drag move resize elements')
        local borrowed = {}
        local function releaseRows()
            for _, r in ipairs(borrowed) do
                r:SetParent(body)
                r:Hide()
            end
            local hadRows = #borrowed > 0
            borrowed = {}
            if hadRows then
                layout()
            end
        end
        -- Only borrow controls that directly change this component. Unlisted
        -- components still have their own local layout and appearance controls.
        local componentKeys = {
            name = 'nameText wrapNames nameWrapWidth',
            level = 'levelText',
            value = 'showHealthText healthFormat hideFullHealthText healthText',
            distance = 'showDistance distanceText',
            threat = 'showThreat threatPosition aggro pulling partyAggro safe',
            guild = 'guildText',
            questBadge = 'questIcon',
            serviceQuest = 'questIcon',
            cast = 'castHeight castColor lockedCastColor',
            castText = 'castText',
            castTime = 'castText castTimer',
            partyIcon = 'partyIcon partyIconStyle partyIconSize partyIncludeRaid',
            partyText = 'partyLabel partyLabelText partyTextSize partyColor partyIncludeRaid',
            serviceName = 'nameText',
            serviceRole = 'serviceText',
            objectLabel = 'nameText',
            petName = 'nameText showCompanionText',
            petOwner = 'serviceText showCompanionText',
            buffPosition = 'buffPosition auraText auraScale auraSweep auraSweepStyle auraPulse castableBuffs',
            debuffPosition = 'debuffPosition auraText auraScale auraSweep auraSweepStyle auraPulse',
            controlPosition = 'controlPosition auraText auraScale auraSweep auraSweepStyle auraPulse',
        }
        local playerKeys = {
            name = 'showSurname',
            guild = 'showGuild guildPosition guildStyle',
            classBadge = 'badges spec iconSize',
            power = 'power powerHeight',
            powerValue = 'powerValue powerFormat',
        }
        local personalKeys = {
            name = 'personalName',
            health = 'personalHealth',
            level = 'personalLevel',
            guild = 'personalGuild',
            classBadge = 'personalBadge',
            power = 'personalPower personalPowerHeight',
            powerValue = 'personalPowerValue personalPowerFormat',
            cast = 'personalCasts',
            buffPosition = 'personalBuffs',
            debuffPosition = 'personalDebuffs',
            controlPosition = 'personalDebuffs',
        }
        local function designerRows(host, component, kind)
            releaseRows()
            if not host then
                return
            end
            local allowed = {}
            local function include(keys)
                for key in (keys or ''):gmatch('%S+') do
                    allowed[key] = true
                end
            end
            include(componentKeys[component])
            if kind == 'personal' then
                include(personalKeys[component])
            else
                local common = {
                    level = 'showLevelText',
                    cast = 'casts',
                    buffPosition = 'buffs',
                    debuffPosition = 'debuffs',
                    controlPosition = 'debuffs',
                }
                include(common[component])
            end
            if kind == 'friendlyPlayerScale' or kind == 'enemyPlayerScale' then
                for key in (playerKeys[component] or ''):gmatch('%S+') do
                    allowed[A.PlayerOptionKey(key, kind == 'enemyPlayerScale')] = true
                end
            end
            if component == 'health' then
                if kind == 'npc' then
                    include('hostile neutral friendly aggro pulling partyAggro safe questTint quest')
                elseif kind == 'friendlyPlayerScale' then
                    include('partyHealthTint partyColor')
                end
            end
            for _, r in ipairs(rows) do
                if allowed[r.settingKey] then
                    r:SetParent(host)
                    r:ClearAllPoints()
                    r:SetPoint('TOPLEFT', 0, -#borrowed * 32)
                    borrowed[#borrowed + 1] = r
                    r:Show()
                    if r.sync then
                        r.sync()
                    end
                end
            end
            host:SetHeight(math.max(1, #borrowed * 32))
        end
        local function openDesigner()
            if not refreshDesigner then
                refreshDesigner = A.BuildDesigner(row, button, label, changed, openRow, designerRows)
            end
            A.OpenDesigner()
        end
        A.OpenDesigner = openDesigner
        button(openRow, 'Open designer', 0, 140, openDesigner)
        local confirm = CreateFrame('Frame', nil, page, 'BackdropTemplate')
        confirm:SetPoint('BOTTOMRIGHT', -8, 6)
        confirm:SetSize(295, 60)
        confirm:SetFrameLevel(page:GetFrameLevel() + 50)
        confirm:EnableMouse(true)
        confirm:SetBackdrop({
            bgFile = 'Interface\\Buttons\\WHITE8X8',
            edgeFile = 'Interface\\Buttons\\WHITE8X8',
            edgeSize = 1,
        })
        confirm:SetBackdropColor(0.07, 0.05, 0.03, 1)
        confirm:SetBackdropBorderColor(0.56, 0.41, 0.20, 1)
        confirm:Hide()
        local reset
        local function dismissReset()
            confirm:Hide()
            reset:Show()
        end
        reset = button(page, 'Reset all', 0, 94, function()
            if A.CloseDesigner then
                A.CloseDesigner()
            end
            local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
            if focus and focus.ClearFocus then
                focus:ClearFocus()
            end
            reset:Hide()
            confirm:Show()
        end)
        reset:ClearAllPoints()
        reset:SetPoint('BOTTOMRIGHT', page, 'BOTTOMRIGHT', -8, 6)
        local prompt = label(confirm, 'Reset all designs and settings? UI will reload.', 0)
        prompt:ClearAllPoints()
        prompt:SetPoint('TOPLEFT', 8, -6)
        prompt:SetPoint('TOPRIGHT', -8, -6)
        local actions = CreateFrame('Frame', nil, confirm)
        actions:SetPoint('BOTTOMRIGHT', -6, 4)
        actions:SetSize(156, 23)
        button(actions, CANCEL, 0, 72, dismissReset)
        button(actions, 'Reset all', 76, 80, function()
            dismissReset()
            local defaults = A.NewProfile()
            for key in pairs(A.db) do
                if key ~= 'confirmedGossipMenus' and key ~= 'overheadVersion' and not key:match('^old') then
                    A.db[key] = nil
                end
            end
            for key, value in pairs(defaults) do
                A.db[key] = value
            end
            A.db.personalSetupPending = false
            A.PositionLauncher()
            A.ApplyNativeDistance(A.db.viewDistance)
            A.previewColor = nil
            A.db.showResetReceipt = true
            ReloadUI()
        end)
        page:HookScript('OnHide', function()
            dismissReset()
            if A.CloseDesigner then
                A.CloseDesigner()
            end
        end)
        local distance =
            row('General', 'Nameplate view distance', 'NPCs monsters players range yards detection')
        addReset(distance, 'viewDistance')
        label(distance, 'Nameplate view distance', 4)
        local slider = CreateFrame('Slider', nil, distance, 'OptionsSliderTemplate')
        slider:SetPoint('LEFT', distance, 'LEFT', 184, 3)
        slider:SetSize(120, 14)
        slider:SetOrientation('HORIZONTAL')
        slider:SetValueStep(1)
        slider:SetObeyStepOnDrag(true)
        local valueLabel = label(distance, '', 310)
        local syncing = false
        distance.sync = function()
            local value = A.ClampDistance(A.db.viewDistance or GetCVar('nameplateMaxDistance'))
            local maximum = A.DistanceLimit()
            syncing = true
            slider:SetMinMaxValues(1, maximum)
            slider:SetValue(value)
            if slider.Low then
                slider.Low:SetText('1')
            end
            if slider.High then
                slider.High:SetText(maximum)
            end
            valueLabel:SetText(math.max(1, value) .. ' yd')
            syncing = false
        end
        slider:SetScript('OnValueChanged', function(_, raw)
            if syncing then
                return
            end
            local value = A.ClampDistance(raw + 0.5)
            valueLabel:SetText(value .. ' yd')
            if A.db.viewDistance == value then
                return
            end
            A.db.viewDistance = value
            A.ApplyNativeDistance(value)
            A.RefreshPlateDistances()
            if refreshDesigner then
                refreshDesigner()
            end
        end)
        check('General', 'showDistance', 'Show distance beside level', 'players range yards estimate')
        check('General', 'preview', 'Show live plate previews', 'test demo')
        check('General', 'previewTarget', 'Preview world plates as selected', 'target glow')
        check(
            'General',
            'previewFriendlyNPC',
            'Show a friendly NPC in the preview',
            'hostile enemy mob preview'
        )
        check('General', 'minimap', 'Show minimap button', 'launcher shortcut')
        if Plater and Plater.OpenOptionsPanel then
            button(row('General', 'Advanced Plater settings'), 'Advanced Plater settings', 4, 200, function()
                Plater.OpenOptionsPanel()
            end)
        end
        local function choice(group, key, title, values)
            local r = row(group, title, 'appearance')
            label(r, title, 4)
            addReset(r, key)
            local control = button(r, '', 202, 144, function()
                for i, value in ipairs(values) do
                    if A.db[key] == value then
                        A.db[key] = values[i % #values + 1]
                        break
                    end
                end
                r.sync()
                changed()
            end)
            r.sync = function()
                control:SetText(A.db[key] .. ' >')
            end
        end
        check('Party', 'partyIcon', 'Show party member icon', 'group players marker')
        check('Party', 'partyLabel', 'Show party label', 'group players text')
        check('Party', 'partyHealthTint', 'Use party health bar colour', 'group players tint')
        check('Party', 'partyNameTint', 'Use party name colour', 'group players tint')
        check('Party', 'partyIncludeRaid', 'Also mark raid members', 'group players')
        choice('Party', 'partyIconStyle', 'Party icon', { 'Group', 'Star' })
        number('Party', 'partyIconSize', 'Party icon size', 10, 48, 1, ' px')
        number('Party', 'partyTextSize', 'Party label font size', 8, 24, 1, ' px')
        local partyRow = row('Party', 'Party label text', 'custom group caption')
        label(partyRow, 'Party label text', 4)
        addReset(partyRow, 'partyLabelText')
        local partyText = input(partyRow, 202, 144)
        partyText:SetMaxLetters(32)
        partyRow.sync = function()
            partyText:SetText(A.db.partyLabelText)
        end
        partyText:SetScript('OnEnterPressed', function(self)
            local value = self:GetText():gsub('|', ''):match('^%s*(.-)%s*$')
            A.db.partyLabelText = value ~= '' and value or 'Party'
            self:ClearFocus()
            partyRow.sync()
            changed()
        end)
        partyText:SetScript('OnEscapePressed', function(self)
            self:ClearFocus()
            partyRow.sync()
        end)
        local valueFormats = { 'Current + percent', 'Current', 'Percent', 'Current / max' }
        check('Personal', 'personal', 'Show my personal plate', 'self health')
        check('Personal', 'unlock', 'Unlock my plate for dragging', 'move')
        check('Personal', 'personalName', 'Show my character name')
        check('Personal', 'personalLevel', 'Show my level')
        check('Personal', 'personalGuild', 'Show my guild name')
        check('Personal', 'personalBadge', 'Show my class or spec icon')
        check('Personal', 'personalHealth', 'Show my health bar')
        check('Personal', 'personalBuffs', 'Show my helpful buffs')
        check('Personal', 'personalDebuffs', 'Show my harmful debuffs')
        check('Personal', 'personalCasts', 'Show my cast bar')
        check('Personal', 'personalPower', 'Show my resource bar', 'mana energy rage power')
        number(
            'Personal',
            'personalPowerHeight',
            'Resource bar height',
            3,
            30,
            1,
            ' px',
            'mana rage energy size'
        )
        check('Personal', 'personalPowerValue', 'Show resource value', 'mana energy rage power values')
        choice('Personal', 'personalPowerFormat', 'Resource value format', valueFormats)
        number('Personal', 'scale', 'Personal plate scale', 40, 180, 5, '%')
        button(row('Personal', 'Center my plate', 'reset position'), 'Center my plate', 4, 150, function()
            A.db.x, A.db.y = nil, nil
            changed()
        end)
        check('Personal', 'native', 'Request native personal anchor', 'overhead')
        check('Personal', 'hideName', 'Hide my original overhead name')
        check('Personal', 'hideGuild', 'Hide overhead guild names (all players)')
        check('Text', 'showHealthText', 'Show health text', 'HP value numbers visibility')
        choice('Text', 'healthFormat', 'Health value format', valueFormats)
        check('Text', 'hideFullHealthText', 'Hide health text at full health', '100 percent HP')
        check('Text', 'showLevelText', 'Show level', 'level number visibility')
        choice('Text', 'plateFont', 'Plate font', {
            'Ubuntu Bold',
            'Lato Bold',
            'Barlow SemiBold',
            'PT Serif Bold',
            'Space Mono Bold',
            'Lilita One',
            'Morpheus',
            'Skurri',
            'Game font',
            'Damage font',
        })
        choice('Text', 'textOutline', 'Text outline', { 'Normal', 'Thick', 'None' })
        check('Text', 'wrapNames', 'Wrap long plate names (up to 3 lines)', 'word wrap player surname NPC')
        number('Text', 'nameWrapWidth', 'Wrapped name width', 80, 400, 4, ' px', 'line length wrap')
        check('Text', 'textShadow', 'Show text shadow', 'contrast lettering')
        number('Text', 'textScale', 'All plate text', 10, 125, 5, '%', 'font size scale')
        for _, role in ipairs(A.TextRoles) do
            number('Text', role[1], role[2] .. ' size', 10, 150, 5, '%', 'font text scale')
        end
        local scalePage = {
            enemyNPCScale = 'NPCs',
            friendlyNPCScale = 'NPCs',
            enemyPlayerScale = 'Enemy players',
            friendlyPlayerScale = 'Friendly players',
            targetScale = 'Targeting',
        }
        for _, v in ipairs(A.scaleGroups) do
            number(scalePage[v[1]], v[1], v[2] .. ' scale', 40, 180, 5, '%', 'world')
        end
        check(
            'NPCs',
            'townPlates',
            'Show friendly NPC plates outside combat',
            'guards trainers town names always'
        )
        check(
            'NPCs',
            'compactCompanions',
            'Compact friendly pets and minions',
            'player guardian companion owner'
        )
        check(
            'NPCs',
            'showCompanionText',
            'Show compact pet and minion text',
            'friendly companion name owner outside combat'
        )
        check(
            'NPCs',
            'hideIdleNPCs',
            'Idle friendly NPCs: show name only',
            'idle civilian town quest dialogue service'
        )
        check('NPCs', 'compactFriendly', 'Friendly NPCs: name only outside combat', 'hide hp health guards')
        check('Quests', 'questTint', 'Colour active quest NPCs', 'objectives monsters')
        check('Quests', 'questIcon', 'Show quest marker beside NPC names', 'objectives exclamation')
        check('Targeting', 'showThreat', 'Show my threat on enemy NPCs', 'combat aggro percent threat meter')
        choice(
            'Targeting',
            'threatPosition',
            'Threat position',
            { 'Right of bar', 'Left of bar', 'Above name' }
        )
        check('Targeting', 'targetOutline', 'Highlight selected target', 'target glow visibility')
        choice(
            'Targeting',
            'targetGlowStyle',
            'Target glow style',
            { 'Soft outline', 'Neon edges', 'Underglow', 'Side flares', 'Crown', 'Wisp' }
        )
        number('Targeting', 'targetGlowSpread', 'Glow spread', 6, 36, 2, ' px', 'halo backglow radius size')
        number(
            'Targeting',
            'targetGlowStrength',
            'Target glow strength',
            0,
            100,
            5,
            '%',
            'opacity brightness highlight'
        )
        for _, group in ipairs({ 'Friendly players', 'Enemy players' }) do
            local enemy = group == 'Enemy players'
            check(
                group,
                A.PlayerOptionKey('showSurname', enemy),
                'Show player surnames',
                'last name personal friendly enemy'
            )
            check(
                group,
                A.PlayerOptionKey('showGuild', enemy),
                'Show guild name',
                'guild name personal friendly enemy'
            )
            choice(group, A.PlayerOptionKey('guildPosition', enemy), 'Guild position', {
                'Above left',
                'Before name',
                'After name',
                'Under name',
                'Below plate',
                'Above centre',
                'Above right',
            })
            choice(
                group,
                A.PlayerOptionKey('guildStyle', enemy),
                'Guild style',
                { 'Gold tag', 'Plain text', 'Angle brackets' }
            )
            check(group, A.PlayerOptionKey('power', enemy), 'Show player resource bars', 'energy mana rage')
            number(
                group,
                A.PlayerOptionKey('powerHeight', enemy),
                'Resource bar height',
                3,
                30,
                1,
                ' px',
                'mana energy rage size'
            )
            check(
                group,
                A.PlayerOptionKey('powerValue', enemy),
                'Show resource value',
                'mana energy rage numbers'
            )
            choice(group, A.PlayerOptionKey('powerFormat', enemy), 'Resource value format', valueFormats)
            check(group, A.PlayerOptionKey('badges', enemy), 'Show player class badges', 'icon')
            check(
                group,
                A.PlayerOptionKey('spec', enemy),
                'Prefer specialization icons when known',
                'spec badge'
            )
            number(group, A.PlayerOptionKey('iconSize', enemy), 'Class badge size', 14, 36, 1, '', 'icon')
        end
        check('Castbar', 'casts', 'Show casts and channels', 'castbar spells')
        check('Castbar', 'castTimer', 'Show remaining cast time', 'countdown seconds')
        number('Castbar', 'castHeight', 'Cast bar height', 12, 28, 1, ' px', 'size thickness')
        check('Auras', 'buffs', 'Show helpful buffs')
        check('Auras', 'castableBuffs', 'Only buffs my character can cast', 'helpful apply filter player')
        check('Auras', 'debuffs', 'Show harmful debuffs', 'crowd control')
        check('Auras', 'auraSweep', 'Show cooldown sweep on aura icons', 'radial timer buffs debuffs')
        choice('Auras', 'auraSweepStyle', 'Aura sweep direction', { 'Circle', 'Down', 'Up', 'Left', 'Right' })
        check('Auras', 'auraPulse', 'Pulse auras near expiry', 'expiration warning buffs debuffs')
        number('Auras', 'auraScale', 'Aura icon and timer scale', 60, 200, 5, '%', 'buff debuff countdown')
        local function placement(key, title)
            local r = row('Auras', title, 'position placement anchor')
            addReset(r, key)
            label(r, title, 4)
            local control
            control = button(r, '', 210, 146, function()
                for i, position in ipairs(A.auraPositions) do
                    if position == A.AuraPosition(key) then
                        A.db[key] = A.auraPositions[i % #A.auraPositions + 1]
                        break
                    end
                end
                control:SetText(A.AuraPosition(key) .. ' >')
                changed()
            end)
            r.sync = function()
                control:SetText(A.AuraPosition(key) .. ' >')
            end
        end
        placement('buffPosition', 'Helpful buff position')
        placement('debuffPosition', 'Harmful debuff position')
        placement('controlPosition', 'Crowd control position')
        A.RefreshAuraExample = function()
            if example:IsVisible() then
                A.DrawAuraExample(example)
            end
        end

        for _, option in ipairs({
            { 'partyColor', 'Party member colour' },
            { 'targetColor', 'Target highlight colour' },
            { 'quest', 'Quest objective colour' },
            { 'hostile', 'Hostile' },
            { 'neutral', 'Neutral' },
            { 'friendly', 'Friendly' },
            { 'aggro', 'Have aggro' },
            { 'pulling', 'Gaining aggro' },
            { 'partyAggro', 'Party member has aggro' },
            { 'safe', 'No aggro' },
            { 'castColor', 'Cast bar fill' },
            { 'lockedCastColor', 'Uninterruptible cast' },
        }) do
            local key, title = option[1], option[2]
            local r = row(
                key == 'partyColor' and 'Party'
                    or key == 'targetColor' and 'Targeting'
                    or (key == 'castColor' or key == 'lockedCastColor') and 'Castbar'
                    or 'Colours',
                title,
                'color colour threat'
            )
            addReset(r, key)
            label(r, title, 4)
            r.castColour = key == 'castColor' or key == 'lockedCastColor'
            local field = input(r, 218, 76)
            local swatch = button(r, '', 310, 38, function() end)
            local fill = swatch:CreateTexture(nil, 'OVERLAY')
            fill:SetPoint('TOPLEFT', 4, -4)
            fill:SetPoint('BOTTOMRIGHT', -4, 4)
            r.sync = function()
                field:SetText(A.db[key])
                fill:SetColorTexture(rgb(A.db[key]))
            end
            local function set(hex)
                A.db[key] = hex
                A.previewLockedCast = key == 'lockedCastColor'
                A.previewColor = key ~= 'lockedCastColor'
                        and key ~= 'partyColor'
                        and key ~= 'targetColor'
                        and key ~= 'castColor'
                        and key
                    or nil
                r.sync()
                changed()
            end
            field:SetScript('OnEnterPressed', function()
                local hex = field:GetText():gsub('^#', ''):upper()
                if #hex == 6 and hex:match('^%x+$') then
                    set(hex)
                else
                    r.sync()
                end
                field:ClearFocus()
            end)
            field:SetScript('OnEscapePressed', function()
                field:ClearFocus()
                r.sync()
            end)
            swatch:SetScript('OnClick', function()
                local picker, original = ColorPickerFrame, A.db[key]
                local red, green, blue = rgb(original)
                local function choose()
                    local x, y, z = picker:GetColorRGB()
                    set(
                        ('%02X%02X%02X'):format(
                            math.floor(x * 255 + 0.5),
                            math.floor(y * 255 + 0.5),
                            math.floor(z * 255 + 0.5)
                        )
                    )
                end
                local function cancel()
                    set(original)
                end
                if picker.SetupColorPickerAndShow then
                    picker:SetupColorPickerAndShow({
                        r = red,
                        g = green,
                        b = blue,
                        hasOpacity = false,
                        swatchFunc = choose,
                        cancelFunc = cancel,
                    })
                else
                    picker:Hide()
                    picker.hasOpacity = false
                    picker.func = choose
                    picker.cancelFunc = cancel
                    picker:SetColorRGB(red, green, blue)
                    picker:Show()
                end
                if r:GetParent() ~= body then
                    if not picker.rnpSharedPickerHook then
                        picker:HookScript('OnHide', function(self)
                            if self.rnpSharedStrata then
                                self:SetFrameStrata(self.rnpSharedStrata)
                                self.rnpSharedStrata = nil
                            end
                        end)
                        picker.rnpSharedPickerHook = true
                    end
                    picker.rnpSharedStrata = picker.rnpSharedStrata or picker:GetFrameStrata()
                    picker:SetFrameStrata('TOOLTIP')
                    picker:Raise()
                end
            end)
        end
        search:SetScript('OnTextChanged', layout)
        search:SetScript('OnEscapePressed', function()
            search:SetText('')
            search:ClearFocus()
        end)
        A.SyncOptions = function()
            for _, r in ipairs(rows) do
                if r.sync then
                    r.sync()
                end
            end
            if refreshDesigner then
                refreshDesigner()
            end
        end
        return function()
            A.SyncOptions()
            layout()
        end
    end)
end
SLASH_RAYNNANAMEPLATES1 = '/rnp'
SlashCmdList.RAYNNANAMEPLATES = function(msg)
    if msg == 'threat' then
        A.PrintThreatSnapshot()
    elseif msg == 'preview' then
        A.TogglePreview()
    elseif msg == 'debugpulse' then
        A.TogglePulseDebug()
    elseif msg == 'anchor' then
        print(
            A.nativeAnchor and 'Raynna: attached to the native personal resource plate.'
                or 'Raynna: using a screen position.'
        )
    else
        registry:Open('raynnanameplates')
    end
end
