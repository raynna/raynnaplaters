local _, A = ...
local registry=RaynnaModsSettingsRegistry
local groups={"General","Personal","NPCs","Players","Targeting","Quests","Auras","Castbar","Colours","Text"}
local function button(parent,caption,x,width,click)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetPoint("LEFT",parent,"LEFT",x,0)
    b:SetSize(width,23)
    b:SetText(caption)
    b:SetScript("OnClick",click)
    return b
end
local function label(parent,caption,x)
    local t=parent:CreateFontString(nil,"ARTWORK","GameFontNormal")
    t:SetPoint("LEFT",parent,"LEFT",x,0)
    t:SetText(caption)
    return t
end
local function input(parent,x,width)
    local e=CreateFrame("EditBox",nil,parent,"InputBoxTemplate")
    e:SetPoint("LEFT",parent,"LEFT",x,0)
    e:SetSize(width,22)
    e:SetAutoFocus(false)
    return e
end
local function rgb(hex)
    return tonumber(hex:sub(1,2),16)/255,tonumber(hex:sub(3,4),16)/255,tonumber(hex:sub(5,6),16)/255
end
function A.TogglePreview()
    A.db.preview=not A.db.preview
    A.Refresh()
    if A.SyncOptions then A.SyncOptions() end
end
function A.RegisterSettings()
    registry:Register("raynnanameplates","Nameplates",function(page)
        local header=CreateFrame("Frame",nil,page)
        header:SetPoint("TOPLEFT",16,-5)
        header:SetSize(420,30)
        label(header,"Search settings",0)
        local search=input(header,104,206)
        button(header,"Clear",324,66,function() search:SetText(""); search:ClearFocus() end)
        local nav=CreateFrame("Frame",nil,page)
        nav:SetPoint("TOPLEFT",16,-40)
        nav:SetSize(400,52)
        local scroll=CreateFrame("ScrollFrame",nil,page,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",16,-119)
        scroll:SetPoint("BOTTOMRIGHT",-30,8)
        local body=CreateFrame("Frame",nil,scroll)
        body:SetSize(405,1)
        scroll:SetScrollChild(body)
        local empty=label(body,"No matching settings",6)
        empty:ClearAllPoints()
        empty:SetPoint("TOPLEFT",6,-8)
        local heading=page:CreateFontString(nil,"ARTWORK","GameFontNormal")
        heading:SetPoint("TOPLEFT",20,-99)
        local rows,tabs={},{}
        local current="General"
        local example=CreateFrame("Frame",nil,page,"BackdropTemplate")
        example:SetBackdrop({
            bgFile="Interface\\Buttons\\WHITE8X8",
            edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1,
        })
        example:SetBackdropColor(.065,.047,.032,.85)
        example:SetBackdropBorderColor(.57,.43,.23,.9)
        example:SetClipsChildren(true)
        local selector=CreateFrame("Frame",nil,page)
        selector:SetSize(260,24)
        local friendlyTab,enemyTab
        local expanded=false
        local function positionPreview()
            local minWidth=590
            if current=="Targeting" then
                local plateScale=.94*(A.db.enemyNPCScale or 80)*(A.db.targetScale or 120)/10000
                local sampleWidth=(162+2*(A.db.targetGlowSpread or 18))*plateScale
                minWidth=math.max(minWidth,440+sampleWidth*UIParent:GetEffectiveScale()/page:GetEffectiveScale())
            end
            local wide=not expanded and page:GetWidth()>=minWidth
            local top=wide and 4 or 96
            local height=expanded and 236 or 148
            local contentTop=top+height+7
            example:ClearAllPoints()
            example:SetPoint("TOPLEFT",page,"TOPLEFT",wide and 412 or 16,-top)
            example:SetPoint("TOPRIGHT",page,"TOPRIGHT",-8,-top)
            example:SetHeight(height)
            selector:ClearAllPoints()
            selector:SetPoint("TOPLEFT",page,"TOPLEFT",16,-contentTop)
            if selector:IsShown() then contentTop=contentTop+29 end
            heading:ClearAllPoints()
            heading:SetPoint("TOPLEFT",20,-contentTop)
            scroll:ClearAllPoints()
            scroll:SetPoint("TOPLEFT",16,-contentTop-20)
            scroll:SetPoint("BOTTOMRIGHT",-30,8)
        end
        local resizePreview=CreateFrame("Button",nil,example,"UIPanelButtonTemplate")
        resizePreview:SetPoint("TOPRIGHT",-3,-3)
        resizePreview:SetSize(60,18)
        resizePreview:SetText("Expand")
        resizePreview:SetFrameLevel(example:GetFrameLevel()+10)
        resizePreview:SetScript("OnClick",function()
            expanded=not expanded
            resizePreview:SetText(expanded and "Compact" or "Expand")
            positionPreview()
            A.DrawAuraExample(example)
        end)
        positionPreview()
        page:HookScript("OnSizeChanged",function()
            positionPreview()
            if example:IsVisible() then A.DrawAuraExample(example) end
        end)
        example:SetScript("OnShow",function() A.DrawAuraExample(example) end)
        local function layout()
            example.category=current
            if example:IsVisible() then A.DrawAuraExample(example) end
            local query=(search:GetText() or ""):lower():match("^%s*(.-)%s*$")
            selector:SetShown(current=="Players" and query=="")
            friendlyTab:SetEnabled(A.db.previewEnemyPlayer==true)
            enemyTab:SetEnabled(A.db.previewEnemyPlayer~=true)
            positionPreview()
            local selected=current
            if current=="Players" then selected=A.db.previewEnemyPlayer and "Enemy players" or "Friendly players" end
            local count,height=0,0
            for _,r in ipairs(rows) do
                local visible=query=="" and r.group==selected or query~="" and r.terms:find(query,1,true)
                r:SetShown(not not visible)
                if visible then
                    r:ClearAllPoints()
                    r:SetPoint("TOPLEFT",0,-height)
                    count=count+1
                    height=height+r:GetHeight()+2
                end
            end
            heading:SetText(query=="" and selected or ("Search results ("..count..")"))
            empty:SetShown(count==0)
            body:SetHeight(math.max(32,height))
            scroll:SetVerticalScroll(0)
            for name,b in pairs(tabs) do b:SetEnabled(query~="" or name~=current) end
        end
        local function selectPlayers(enemy)
            A.db.previewEnemyPlayer=enemy
            layout()
        end
        friendlyTab=button(selector,"Friendly players",0,118,function() selectPlayers(false) end)
        enemyTab=button(selector,"Enemy players",124,118,function() selectPlayers(true) end)
        for i,group in ipairs(groups) do
            local name=group
            tabs[name]=button(nav,name,0,73,function()
                current=name;search:SetText("");search:ClearFocus();layout()
            end)
            tabs[name]:ClearAllPoints()
            tabs[name]:SetPoint("TOPLEFT",((i-1)%5)*78,-math.floor((i-1)/5)*26)
        end
        local function row(group,title,aliases)
            local r=CreateFrame("Frame",nil,body)
            r:SetSize(405,30)
            r.group=group
            r.terms=(group.." "..title.." "..(aliases or "")):lower()
            rows[#rows+1]=r
            return r
        end
        local function changed()
            A.RefreshFonts()
            A.launcher:SetShown(A.db.minimap)
            A.Refresh()
            if A.RefreshPlateDistances then A.RefreshPlateDistances() end
            if current=="Targeting" then positionPreview() end
            if A.RefreshAuraExample then A.RefreshAuraExample() end
        end
        local function addReset(r,key)
            button(r,"Reset",358,47,function()
                if key=="personal" then A.FinishPersonalSetup() end
                local value=A.NewProfile()[key]
                if key=="buffs" or key=="castableBuffs" then
                    A.SetBuffOption(key,value)
                else
                    A.db[key]=value
                end
                if key=="viewDistance" then
                    A.ApplyNativeDistance(value)
                    A.RefreshPlateDistances()
                end
                A.SyncOptions()
                changed()
            end)
        end
        local function check(group,key,title,aliases)
            local r=row(group,title,aliases)
            addReset(r,key)
            local c=CreateFrame("CheckButton",nil,r,"UICheckButtonTemplate")
            c:SetPoint("LEFT",0,0)
            c.Text:SetText(title)
            c:SetScript("OnClick",function()
                if key=="personal" then A.FinishPersonalSetup() end
                local enabled=not not c:GetChecked()
                if key=="buffs" or key=="castableBuffs" then
                    A.SetBuffOption(key,enabled)
                    A.SyncOptions()
                else
                    A.db[key]=enabled
                end
                changed()
            end)
            r.sync=function() c:SetChecked(A.db[key]) end
        end
        local function number(group,key,title,min,max,step,suffix,aliases)
            local r=row(group,title,aliases)
            addReset(r,key)
            label(r,title,4)
            local field=input(r,249,60)
            local function value() return A.db[key] or 18 end
            r.sync=function() field:SetText(value()..suffix) end
            local function apply(n)
                if n then A.db[key]=math.min(max,math.max(min,math.floor(n))) end
                field:ClearFocus();r.sync();changed()
            end
            button(r,"-",211,28,function() apply(value()-step) end)
            button(r,"+",318,28,function() apply(value()+step) end)
            field:SetScript("OnEnterPressed",function() apply(tonumber((field:GetText():match("^%s*(%-?%d+)%s*%%?%s*$") or field:GetText():match("^%s*(%d+)%s*px%s*$")))) end)
            field:SetScript("OnEscapePressed",function() field:ClearFocus();r.sync() end)
        end
        local distance=row("General","Nameplate view distance","NPCs monsters players range yards detection")
        addReset(distance,"viewDistance")
        label(distance,"Nameplate view distance",4)
        local slider=CreateFrame("Slider",nil,distance,"OptionsSliderTemplate")
        slider:SetPoint("LEFT",distance,"LEFT",184,3)
        slider:SetSize(120,14)
        slider:SetOrientation("HORIZONTAL")
        slider:SetValueStep(1)
        slider:SetObeyStepOnDrag(true)
        local valueLabel=label(distance,"",310)
        local syncing=false
        distance.sync=function()
            local value=A.ClampDistance(A.db.viewDistance or GetCVar("nameplateMaxDistance"))
            local maximum=A.DistanceLimit()
            syncing=true
            slider:SetMinMaxValues(1,maximum)
            slider:SetValue(value)
            if slider.Low then slider.Low:SetText("1") end
            if slider.High then slider.High:SetText(maximum) end
            valueLabel:SetText(math.max(1,value).." yd")
            syncing=false
        end
        slider:SetScript("OnValueChanged",function(_,raw)
            if syncing then return end
            local value=A.ClampDistance(raw+.5)
            valueLabel:SetText(value.." yd")
            if A.db.viewDistance==value then return end
            A.db.viewDistance=value
            A.ApplyNativeDistance(value)
            A.RefreshPlateDistances()
        end)
        check("General","showDistance","Show distance beside level","players range yards estimate")
        check("General","preview","Show live plate previews","test demo")
        check("General","previewTarget","Preview world plates as selected","target glow")
        check("General","previewFriendlyNPC","Show a friendly NPC in the preview","hostile enemy mob preview")
        check("General","minimap","Show minimap button","launcher shortcut")
        if Plater and Plater.OpenOptionsPanel then
            button(row("General","Advanced Plater settings"),"Advanced Plater settings",4,200,function() Plater.OpenOptionsPanel() end)
        end
        local function choice(group,key,title,values)
            local r=row(group,title,"appearance")
            label(r,title,4)
            addReset(r,key)
            local control=button(r,"",202,144,function()
                for i,value in ipairs(values) do
                    if A.db[key]==value then A.db[key]=values[i%#values+1]; break end
                end
                r.sync()
                changed()
            end)
            r.sync=function() control:SetText(A.db[key].." >") end
        end
        local valueFormats={"Current + percent","Current","Percent","Current / max"}
        check("Personal","personal","Show my personal plate","self health")
        check("Personal","unlock","Unlock my plate for dragging","move")
        check("Personal","personalName","Show my character name")
        check("Personal","personalLevel","Show my level")
        check("Personal","personalGuild","Show my guild name")
        check("Personal","personalBadge","Show my class or spec icon")
        check("Personal","personalHealth","Show my health bar")
        check("Personal","personalBuffs","Show my helpful buffs")
        check("Personal","personalDebuffs","Show my harmful debuffs")
        check("Personal","personalCasts","Show my cast bar")
        check("Personal","personalPower","Show my resource bar","mana energy rage power")
        number("Personal","personalPowerHeight","Resource bar height",3,30,1," px","mana rage energy size")
        check("Personal","personalPowerValue","Show resource value","mana energy rage power values")
        choice("Personal","personalPowerFormat","Resource value format",valueFormats)
        number("Personal","scale","Personal plate scale",40,180,5,"%")
        button(row("Personal","Center my plate","reset position"),"Center my plate",4,150,function() A.db.x,A.db.y=nil,nil;changed() end)
        check("Personal","native","Request native personal anchor","overhead")
        check("Personal","hideName","Hide my original overhead name")
        check("Personal","hideGuild","Hide overhead guild names (all players)")
        check("Text","showHealthText","Show health text","HP value numbers visibility")
        choice("Text","healthFormat","Health value format",valueFormats)
        check("Text","hideFullHealthText","Hide health text at full health","100 percent HP")
        check("Text","showLevelText","Show level","level number visibility")
        choice("Text","plateFont","Plate font",{"Ubuntu Bold","Lato Bold","Barlow SemiBold","PT Serif Bold","Space Mono Bold","Lilita One","Morpheus","Skurri","Game font","Damage font"})
        choice("Text","textOutline","Text outline",{"Normal","Thick","None"})
        check("Text","wrapNames","Wrap long plate names (up to 3 lines)","word wrap player surname NPC")
        number("Text","nameWrapWidth","Wrapped name width",80,400,4," px","line length wrap")
        check("Text","textShadow","Show text shadow","contrast lettering")
        number("Text","textScale","All plate text",10,125,5,"%","font size scale")
        for _,role in ipairs(A.TextRoles) do
            number("Text",role[1],role[2].." size",10,150,5,"%","font text scale")
        end
        local scalePage={enemyNPCScale="NPCs",friendlyNPCScale="NPCs",enemyPlayerScale="Enemy players",
            friendlyPlayerScale="Friendly players",targetScale="Targeting"}
        for _,v in ipairs(A.scaleGroups) do
            number(scalePage[v[1]],v[1],v[2].." scale",40,180,5,"%","world")
        end
        check("NPCs","townPlates","Show friendly NPC plates outside combat","guards trainers town names always")
        check("NPCs","compactCompanions","Compact friendly pets and minions","player guardian companion owner")
        check("NPCs","showCompanionText","Show compact pet and minion text","friendly companion name owner outside combat")
        check("NPCs","hideIdleNPCs","Idle friendly NPCs: show name only","idle civilian town quest dialogue service")
        check("NPCs","compactFriendly","Friendly NPCs: name only outside combat","hide hp health guards")
        check("Quests","questTint","Colour active quest NPCs","objectives monsters")
        check("Quests","questIcon","Show quest marker beside NPC names","objectives exclamation")
        check("Targeting","showThreat","Show my threat on enemy NPCs","combat aggro percent threat meter")
        choice("Targeting","threatPosition","Threat position",{"Right of bar","Left of bar","Above name"})
        choice("Targeting","threatFormat","Threat display",{"Status + percent","Percent","Status"})
        check("Targeting","targetOutline","Highlight selected target","target glow visibility")
        choice("Targeting","targetGlowStyle","Target glow style",{"Soft outline","Neon edges","Underglow","Side flares","Crown","Wisp"})
        number("Targeting","targetGlowSpread","Glow spread",6,36,2," px","halo backglow radius size")
        number("Targeting","targetGlowStrength","Target glow strength",0,100,5,"%","opacity brightness highlight")
        for _,group in ipairs({"Friendly players","Enemy players"}) do
            local enemy=group=="Enemy players"
            check(group,A.PlayerOptionKey("showSurname",enemy),"Show player surnames","last name personal friendly enemy")
            check(group,A.PlayerOptionKey("showGuild",enemy),"Show guild name","guild name personal friendly enemy")
            choice(group,A.PlayerOptionKey("guildPosition",enemy),"Guild position",{"Above left","Before name","After name","Under name","Below plate","Above centre","Above right"})
            choice(group,A.PlayerOptionKey("guildStyle",enemy),"Guild style",{"Gold tag","Plain text","Angle brackets"})
            check(group,A.PlayerOptionKey("power",enemy),"Show player resource bars","energy mana rage")
            number(group,A.PlayerOptionKey("powerHeight",enemy),"Resource bar height",3,30,1," px","mana energy rage size")
            check(group,A.PlayerOptionKey("powerValue",enemy),"Show resource value","mana energy rage numbers")
            choice(group,A.PlayerOptionKey("powerFormat",enemy),"Resource value format",valueFormats)
            check(group,A.PlayerOptionKey("badges",enemy),"Show player class badges","icon")
            check(group,A.PlayerOptionKey("spec",enemy),"Prefer specialization icons when known","spec badge")
            number(group,A.PlayerOptionKey("iconSize",enemy),"Class badge size",14,36,1,"","icon")
        end
        check("Castbar","casts","Show casts and channels","castbar spells")
        check("Castbar","castTimer","Show remaining cast time","countdown seconds")
        number("Castbar","castHeight","Cast bar height",12,28,1," px","size thickness")
        check("Auras","buffs","Show helpful buffs")
        check("Auras","castableBuffs","Only buffs my character can cast","helpful apply filter player")
        check("Auras","debuffs","Show harmful debuffs","crowd control")
        number("Auras","auraScale","Aura icon and timer scale",60,200,5,"%","buff debuff countdown")
        local function placement(key,title)
            local r=row("Auras",title,"position placement anchor")
            addReset(r,key)
            label(r,title,4)
            local control
            control=button(r,"",210,146,function()
                for i,position in ipairs(A.auraPositions) do
                    if position==A.AuraPosition(key) then
                        A.db[key]=A.auraPositions[i % #A.auraPositions+1]
                        break
                    end
                end
                control:SetText(A.AuraPosition(key).." >")
                changed()
            end)
            r.sync=function() control:SetText(A.AuraPosition(key).." >") end
        end
        placement("buffPosition","Helpful buff position")
        placement("debuffPosition","Harmful debuff position")
        placement("controlPosition","Crowd control position")
        A.RefreshAuraExample=function()
            if example:IsVisible() then A.DrawAuraExample(example) end
        end

        for _,option in ipairs({{"targetColor","Target highlight colour"},{"quest","Quest objective colour"},{"hostile","Hostile"},{"neutral","Neutral"},{"friendly","Friendly"},{"aggro","Have aggro"},{"pulling","Gaining aggro"},{"partyAggro","Party member has aggro"},{"safe","No aggro"},{"castColor","Cast bar"}}) do
            local key,title=option[1],option[2]
            local r=row(key=="targetColor" and "Targeting" or key=="castColor" and "Castbar" or "Colours",title,"color colour threat")
            addReset(r,key)
            label(r,title,4)
            local field=input(r,218,76)
            local swatch=button(r,"",310,38,function() end)
            local fill=swatch:CreateTexture(nil,"OVERLAY")
            fill:SetPoint("TOPLEFT",4,-4);fill:SetPoint("BOTTOMRIGHT",-4,4)
            r.sync=function() field:SetText(A.db[key]);fill:SetColorTexture(rgb(A.db[key])) end
            local function set(hex)
                A.db[key]=hex
                A.previewColor=key~="targetColor" and key~="castColor" and key or nil
                r.sync();changed()
            end
            field:SetScript("OnEnterPressed",function()
                local hex=field:GetText():gsub("^#",""):upper()
                if #hex==6 and hex:match("^%x+$") then set(hex) else r.sync() end
                field:ClearFocus()
            end)
            field:SetScript("OnEscapePressed",function() field:ClearFocus();r.sync() end)
            swatch:SetScript("OnClick",function()
                local picker,original=ColorPickerFrame,A.db[key]
                local red,green,blue=rgb(original)
                local function choose()
                    local x,y,z=picker:GetColorRGB()
                    set(("%02X%02X%02X"):format(math.floor(x*255+.5),math.floor(y*255+.5),math.floor(z*255+.5)))
                end
                local function cancel() set(original) end
                if picker.SetupColorPickerAndShow then
                    picker:SetupColorPickerAndShow({r=red,g=green,b=blue,hasOpacity=false,swatchFunc=choose,cancelFunc=cancel})
                else
                    picker:Hide();picker.hasOpacity=false;picker.func=choose;picker.cancelFunc=cancel
                    picker:SetColorRGB(red,green,blue);picker:Show()
                end
            end)
        end
        search:SetScript("OnTextChanged",layout)
        search:SetScript("OnEscapePressed",function() search:SetText(""); search:ClearFocus() end)
        A.SyncOptions=function()
            for _,r in ipairs(rows) do if r.sync then r.sync() end end
        end
        return function() A.SyncOptions();layout() end
    end)
end
SLASH_RAYNNANAMEPLATES1="/rnp"
SlashCmdList.RAYNNANAMEPLATES=function(msg)
    if msg=="preview" then A.TogglePreview()
    elseif msg=="anchor" then print(A.nativeAnchor and "Raynna: attached to the native personal resource plate." or "Raynna: using a screen position.")
    else registry:Open("raynnanameplates") end
end
