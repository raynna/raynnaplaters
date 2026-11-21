local _, A = ...
local registry=RaynnaModsSettingsRegistry
local groups={"General","Personal","World","Auras","Colours"}
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
        nav:SetSize(420,26)
        local scroll=CreateFrame("ScrollFrame",nil,page,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",16,-78)
        scroll:SetPoint("BOTTOMRIGHT",-30,8)
        local body=CreateFrame("Frame",nil,scroll)
        body:SetSize(405,1)
        scroll:SetScrollChild(body)
        local empty=label(body,"No matching settings",6)
        empty:ClearAllPoints()
        empty:SetPoint("TOPLEFT",6,-8)
        local rows,tabs={},{}
        local current="General"
        local function layout()
            local query=(search:GetText() or ""):lower():match("^%s*(.-)%s*$")
            local count=0
            for _,r in ipairs(rows) do
                local visible=query=="" and r.group==current or query~="" and r.terms:find(query,1,true)
                r:SetShown(not not visible)
                if visible then
                    r:ClearAllPoints()
                    r:SetPoint("TOPLEFT",0,-count*32)
                    count=count+1
                end
            end
            empty:SetShown(count==0)
            body:SetHeight(math.max(32,count*32))
            scroll:SetVerticalScroll(0)
            for name,b in pairs(tabs) do b:SetEnabled(query~="" or name~=current) end
        end
        for i,group in ipairs(groups) do
            local name=group
            tabs[name]=button(nav,name,(i-1)*78,75,function()
                current=name;search:SetText("");search:ClearFocus();layout()
            end)
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
            A.launcher:SetShown(A.db.minimap)
            A.Refresh()
        end
        local function check(group,key,title,aliases)
            local r=row(group,title,aliases)
            local c=CreateFrame("CheckButton",nil,r,"UICheckButtonTemplate")
            c:SetPoint("LEFT",0,0)
            c.Text:SetText(title)
            c:SetScript("OnClick",function()
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
            field:SetScript("OnEnterPressed",function() apply(tonumber((field:GetText():gsub("%%","")))) end)
            field:SetScript("OnEscapePressed",function() field:ClearFocus();r.sync() end)
        end
        check("General","preview","Show all four preview plates","test demo")
        check("General","previewTarget","Preview world plates as selected","target glow")
        check("General","previewFriendlyNPC","Show a friendly NPC in the preview","hostile enemy mob preview")
        check("General","minimap","Show minimap button","launcher shortcut")
        if Plater and Plater.OpenOptionsPanel then
            button(row("General","Advanced Plater settings"),"Advanced Plater settings",4,200,function() Plater.OpenOptionsPanel() end)
        end
        check("Personal","personal","Show my personal plate","self health")
        check("Personal","unlock","Unlock my plate for dragging","move")
        number("Personal","scale","Personal plate scale",40,180,5,"%")
        button(row("Personal","Center my plate","reset position"),"Center my plate",4,150,function() A.db.x,A.db.y=nil,nil;changed() end)
        check("Personal","native","Request native personal anchor","overhead")
        check("Personal","hideName","Hide my original overhead name")
        check("Personal","hideGuild","Hide overhead guild names (all players)")
        for _,v in ipairs(A.scaleGroups) do number("World",v[1],v[2].." scale",40,180,5,"%") end
        check("World","targetOutline","Highlight selected target","glow corner pins")
        check("World","power","Show player resource bars","energy mana rage")
        check("World","badges","Show player class badges","icon")
        check("World","spec","Prefer specialization icons when known","spec badge")
        number("World","iconSize","Class badge size",14,36,1,"","icon")
        check("Auras","casts","Show casts and channels","castbar spells")
        check("Auras","buffs","Show helpful buffs above the name")
        check("Auras","castableBuffs","Only buffs my character can cast","helpful apply filter player")
        check("Auras","debuffs","Show harmful debuffs","crowd control")
        number("Auras","auraScale","Aura icon and timer scale",60,200,5,"%","buff debuff countdown")
        for _,option in ipairs({{"hostile","Hostile"},{"neutral","Neutral"},{"friendly","Friendly"},{"aggro","Have aggro"},{"pulling","Gaining aggro"},{"safe","No aggro"},{"castColor","Cast bar"}}) do
            local key,title=option[1],option[2]
            local r=row("Colours",title,"color colour threat")
            label(r,title,4)
            local field=input(r,218,76)
            local swatch=button(r,"",310,38,function() end)
            local fill=swatch:CreateTexture(nil,"OVERLAY")
            fill:SetPoint("TOPLEFT",4,-4);fill:SetPoint("BOTTOMRIGHT",-4,4)
            r.sync=function() field:SetText(A.db[key]);fill:SetColorTexture(rgb(A.db[key])) end
            local function set(hex)
                A.db[key]=hex
                A.previewColor=key~="castColor" and key or nil
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
