local _, A = ...

local parts = {
    {"health","Health bar"}, {"value","Health value"}, {"name","Name"}, {"level","Level"},
    {"distance","Distance"}, {"threat","Threat"}, {"guild","Guild"}, {"classBadge","Class icon"},
    {"questBadge","Quest icon"}, {"power","Resource bar"}, {"powerValue","Resource value"},
    {"cast","Cast bar"}, {"castText","Cast name"}, {"castTime","Cast timer"},
    {"buffPosition","Buffs"}, {"debuffPosition","Debuffs"}, {"controlPosition","Crowd control"},
}
local states = setmetatable({}, {__mode="k"})
local function options(key)
    return A.db.designer and A.db.designer[key]
end
function A.DesignerAura(key)
    local opt=options(key)
    if opt then return opt.x,opt.y,opt.scale end
    return 0,0,1
end

-- Remember the unedited anchors. Existing layouts can re-anchor a region when
-- casts, guilds or resources appear, including while a custom layout is active.
local function transform(region,key)
    if not region then return end
    local opt=options(key)
    local state=states[region]
    if not opt and not state then return end
    state=state or {}
    states[region]=state
    local dx,dy,scale=A.DesignerAura(key)
    local count=region:GetNumPoints()
    if count==0 then return end
    local points={}
    for i=1,count do
        local point,parent,anchor,x,y=region:GetPoint(i)
        local old=state[point]
        if old and old.parent==parent and old.anchor==anchor and x==old.outX and y==old.outY then
            x,y=old.x,old.y
        end
        points[i]={point=point,parent=parent,anchor=anchor,x=x,y=y}
    end
    -- Single-anchor frames scale around their original anchor. A health bar
    -- stretched across its parent needs its opposing anchors spread instead.
    local stretch=count>1 and key=="health"
    if region.GetObjectType and region:GetObjectType()=="FontString" then
        local face,size,flags=region:GetFont()
        local base=region.rnpPixels or (size==state.fontOutput and state.fontBase or size)
        if base and face then
            state.fontBase,state.fontOutput=base,math.max(1,base*scale)
            if size~=state.fontOutput then region:SetFont(face,state.fontOutput,flags) end
        end
    elseif region.SetTextScale then region:SetTextScale(scale)
    elseif region.SetScale and not stretch then region:SetScale(scale)
    elseif count==1 and region.SetSize then
        local w,h=region:GetSize()
        if w~=state.outW or h~=state.outH then state.w,state.h=w,h end
        state.outW,state.outH=state.w*scale,state.h*scale
        region:SetSize(state.outW,state.outH)
    end
    local factor=region.SetScale and not state.fontBase and not region.SetTextScale and not stretch and scale or 1
    local w,h=region:GetParent():GetSize()
    region:ClearAllPoints()
    for _,p in ipairs(points) do
        local x,y=dx,dy
        if stretch then
            x=x+(p.point:find("LEFT") and -1 or p.point:find("RIGHT") and 1 or 0)*w*(scale-1)/2
            y=y+(p.point:find("BOTTOM") and -1 or p.point:find("TOP") and 1 or 0)*h*(scale-1)/2
        end
        p.outX,p.outY=(p.x+x)/factor,(p.y+y)/factor
        region:SetPoint(p.point,p.parent,p.anchor,p.outX,p.outY)
        state[p.point]=p
    end
    if not opt then states[region]=nil end
end
function A.DesignPlate(frame)
    if not A.db or (not A.db.designer and not frame.wasDesigned) then return end
    for _,part in ipairs(parts) do transform(frame[part[1]],part[1]) end
    frame.wasDesigned=A.db.designer~=nil
end
function A.DesignThreat(frame)
    transform(frame.threat,"threat")
end

function A.BuildDesigner(row, button, label, changed)
    local hint=row("Designer","Left-drag to move. Right-drag sideways to resize.","position scale layout")
    label(hint,"Left-drag to move. Right-drag sideways to resize.",3)
    local toolbar=row("Designer","Choose element and reset position","reset size layout")
    local canvas=row("Designer","Plate layout","drag move resize elements")
    canvas:SetHeight(252)
    local sample=CreateFrame("Frame",nil,canvas,"BackdropTemplate")
    sample:SetAllPoints()
    sample:SetClipsChildren(true)
    sample:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    sample:SetBackdropColor(.06,.045,.03,.96)
    sample:SetBackdropBorderColor(.48,.36,.17,1)
    local selected=1
    local selectButton,readout
    local function sync()
        selectButton:SetText(parts[selected][2].." >")
        local x,y,s=A.DesignerAura(parts[selected][1])
        readout:SetText(("%+d, %+d   %d%%"):format(x,y,math.floor(s*100+.5)))
    end
    selectButton=button(toolbar,"",0,138,function() selected=selected%#parts+1;sync() end)
    readout=label(toolbar,"",145)
    button(toolbar,"Reset part",307,96,function()
        if A.db.designer then A.db.designer[parts[selected][1]]=nil end
        changed(); A.DrawAuraExample(sample);sync()
    end)
    toolbar.sync=sync
    sync()
    sample.category="Designer"
    local surface=CreateFrame("Frame",nil,sample)
    surface:SetAllPoints()
    surface:SetFrameLevel(sample:GetFrameLevel()+40)
    surface:EnableMouse(true)
    local function hitPart(f)
        local best,area
        local cx,cy=GetCursorPosition()
        local function hit(index,region)
            if region and region:IsVisible() then
                local x,y,w,h=region:GetRect()
                local scale=region:GetEffectiveScale()
                if not x or cx<x*scale or cx>(x+w)*scale or cy<y*scale or cy>(y+h)*scale then return end
                local footprint=w*h*scale^2
                if not area or footprint<area then best,area=index,footprint end
            end
        end
        for i,part in ipairs(parts) do
            hit(i,f[part[1]])
            for _,icon in ipairs(f.icons or {}) do
                if icon.designKey==part[1] then hit(i,icon) end
            end
        end
        return best
    end
    local drag
    surface:SetScript("OnMouseDown",function(_,mouse)
        if mouse~="LeftButton" and mouse~="RightButton" then return end
        selected=hitPart(sample.sample) or selected
        local key=parts[selected][1]
        local x,y,s=A.DesignerAura(key)
        local cx,cy=GetCursorPosition()
        drag={mouse=mouse,key=key,x=x,y=y,scale=s,cx=cx,cy=cy}
        sync()
    end)
    surface:SetScript("OnUpdate",function()
        if not drag then return end
        if not IsMouseButtonDown(drag.mouse) then drag=nil;changed();return end
        local cx,cy=GetCursorPosition()
        local factor=sample.sample:GetEffectiveScale()
        local dx,dy=(cx-drag.cx)/factor,(cy-drag.cy)/factor
        local function round(n) return math.floor(n+.5) end
        local x,y,s=drag.x,drag.y,drag.scale
        if not drag.lastScale and math.abs(dx)+math.abs(dy)<2 then return end
        if drag.mouse=="RightButton" then s=math.max(.25,math.min(3,round(s*100+dx)/100))
        else x,y=round(x+dx),round(y+dy) end
        if drag.lastX==x and drag.lastY==y and drag.lastScale==s then return end
        drag.lastX,drag.lastY,drag.lastScale=x,y,s
        A.db.designer=A.db.designer or {}
        A.db.designer[drag.key]={x=x,y=y,scale=s}
        A.DrawAuraExample(sample)
        sync()
    end)
    local function finish()
        if drag then drag=nil;changed() end
    end
    surface:SetScript("OnMouseUp",finish)
    surface:SetScript("OnHide",finish)
    sample:SetScript("OnShow",function() A.DrawAuraExample(sample);sync() end)
    A.DrawAuraExample(sample)
    return function() if sample:IsVisible() then A.DrawAuraExample(sample) end end
end
