local _, A = ...

local parts = {
    {"health","Health bar"}, {"value","Health value"}, {"name","Name"}, {"level","Level"},
    {"distance","Distance"}, {"threat","Threat"}, {"guild","Guild"}, {"classBadge","Class icon"},
    {"questBadge","Quest icon"}, {"power","Resource bar"}, {"powerValue","Resource value"},
    {"cast","Cast bar"}, {"castText","Cast name"}, {"castTime","Cast timer"},
    {"buffPosition","Buffs"}, {"debuffPosition","Debuffs"}, {"controlPosition","Crowd control"},
}
local states = setmetatable({}, {__mode="k"})
local renderingDraft
local function options(key)
    local layout=renderingDraft or A.db.designer
    return layout and layout[key]
end
function A.DesignerAura(key)
    local opt=options(key)
    if opt then return opt.x,opt.y,opt.scale end
    return 0,0,1
end

-- Remember the unedited anchors. Existing layouts can re-anchor a region when
-- casts, guilds or resources appear, including while a custom layout is active.
local function readAnchor(region,index)
    if region.rnpAnchor then
        local a=region.rnpAnchor
        return a.point,a.parent,a.anchor,a.x,a.y
    elseif region.rnpStretch then
        local point=index==1 and "TOPLEFT" or "BOTTOMRIGHT"
        return point,region:GetParent(),point,0,0
    end
    if region.IsAnchoringRestricted and region:IsAnchoringRestricted() then return end
    local ok,point,parent,anchor,x,y=pcall(region.GetPoint,region,index)
    if ok and point and not (issecretvalue and (issecretvalue(x) or issecretvalue(y))) then
        return point,parent,anchor,x,y
    end
end
local function transform(region,key,owners)
    if not region or (not region.rnpAnchor and not region.rnpStretch and region.IsAnchoringRestricted and region:IsAnchoringRestricted()) then return end
    local opt=options(key)
    local state=states[region]
    local compensate
    if owners then
        for i=1,(region.rnpAnchor and 1 or region.rnpStretch and 2 or region:GetNumPoints()) do
            local point,anchor=readAnchor(region,i)
            if not point then return end
            if anchor and owners[anchor] and options(owners[anchor]) then compensate=true; break end
        end
    end
    if not opt and not state and not compensate then return end
    state=state or {}
    states[region]=state
    local dx,dy,scale=A.DesignerAura(key)
    local count=region.rnpAnchor and 1 or region.rnpStretch and 2 or region:GetNumPoints()
    if count==0 then return end
    local points={}
    for i=1,count do
        local point,parent,anchor,x,y=readAnchor(region,i)
        if not point then return end
        local old=state[point]
        if not region.rnpAnchor and not region.rnpStretch and old and old.parent==parent and old.anchor==anchor and x==old.outX and y==old.outY then
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
        state.outW,state.outH=region:GetSize()
    end
    local factor=region.SetScale and not state.fontBase and not region.SetTextScale and not stretch and scale or 1
    local w,h=region:GetParent():GetSize()
    for _,p in ipairs(points) do
        local x,y=dx,dy
        local parentKey=owners and owners[p.parent]
        local moved=parentKey and options(parentKey)
        if moved then
            local units=p.parent:GetParent():GetEffectiveScale()/region:GetParent():GetEffectiveScale()
            x,y=x-moved.x*units,y-moved.y*units
        end
        if stretch then
            x=x+(p.point:find("LEFT") and -1 or p.point:find("RIGHT") and 1 or 0)*w*(scale-1)/2
            y=y+(p.point:find("BOTTOM") and -1 or p.point:find("TOP") and 1 or 0)*h*(scale-1)/2
        end
        p.outX,p.outY=(p.x+x)/factor,(p.y+y)/factor
        region:SetPoint(p.point,p.parent,p.anchor,p.outX,p.outY)
        -- WoW stores anchors at client precision. Cache the values it actually
        -- returns so a redraw cannot mistake rounding for a fresh layout.
        state[p.point]=p
    end
    if region.rnpAnchor or region.rnpStretch then
        if not opt and not compensate then states[region]=nil end
        return
    end
    for i=1,region:GetNumPoints() do
        local point,parent,anchor,x,y=readAnchor(region,i)
        if not point then return end
        local p=state[point]
        p.parent,p.anchor,p.outX,p.outY=parent,anchor,x,y
    end
    if not opt and not compensate then states[region]=nil end
end
function A.DesignPlate(frame)
    if not A.db or (not renderingDraft and not A.db.designer and not frame.wasDesigned) then return end
    local owners=frame.designerOwners or {}
    frame.designerOwners=owners
    for _,part in ipairs(parts) do
        local region=frame[part[1]]
        if region then owners[region]=part[1] end
    end
    for _,part in ipairs(parts) do transform(frame[part[1]],part[1],owners) end
    transform(frame.auraAnchor,"auraAnchor",owners)
    frame.wasDesigned=renderingDraft~=nil or A.db.designer~=nil
end
function A.DesignThreat(frame)
    transform(frame.threat,"threat",frame.designerOwners)
end

function A.BuildDesigner(row, button, label, changed)
    local hint=row("Designer","Drag parts to move. Right-drag to resize. Scroll to zoom; drag empty space to pan.","position scale layout")
    label(hint,"Drag parts to move. Right-drag to resize. Scroll to zoom; drag empty space to pan.",3)
    local openRow=row("Designer","Open layout designer","drag move resize elements")
    local window=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
    window:SetFrameStrata("FULLSCREEN_DIALOG")
    window:SetClampedToScreen(true)
    window:SetPoint("CENTER")
    local maxW,maxH=UIParent:GetWidth(),UIParent:GetHeight()
    window:SetSize(math.min(820,maxW),math.min(530,maxH))
    window:SetResizable(true)
    if window.SetResizeBounds then window:SetResizeBounds(math.min(460,maxW),math.min(290,maxH),maxW,maxH)
    elseif window.SetMinResize then window:SetMinResize(math.min(460,maxW),math.min(290,maxH)) end
    window:SetMovable(true)
    window:EnableMouse(true)
    window:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    window:SetBackdropColor(.075,.05,.033,.98)
    window:SetBackdropBorderColor(.64,.46,.22,1)
    window:Hide()
    local title=CreateFrame("Frame",nil,window)
    title:SetPoint("TOPLEFT",8,-4); title:SetPoint("TOPRIGHT",-36,-4);title:SetHeight(28)
    label(title,"Raynna's Nameplate Designer",4)
    title:EnableMouse(true);title:RegisterForDrag("LeftButton")
    title:SetScript("OnDragStart",function() window:StartMoving() end)
    title:SetScript("OnDragStop",function() window:StopMovingOrSizing() end)
    local close=CreateFrame("Button",nil,window,"UIPanelCloseButton")
    close:SetPoint("TOPRIGHT",-2,-2)
    close:SetScript("OnClick",function() window:Hide() end)
    local grip=CreateFrame("Button",nil,window)
    grip:SetSize(20,20);grip:SetPoint("BOTTOMRIGHT",-2,2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetScript("OnMouseDown",function(_,mouse) if mouse=="LeftButton" then window:StartSizing("BOTTOMRIGHT") end end)
    grip:SetScript("OnMouseUp",function() window:StopMovingOrSizing() end)
    window:SetScript("OnHide",function() window:StopMovingOrSizing() end)
    local function open() window:Show();window:Raise() end
    A.CloseDesigner=function() window:Hide() end
    A.OpenDesigner=open
    button(openRow,"Open designer",0,140,open)
    local toolbar=CreateFrame("Frame",nil,window)
    toolbar:SetPoint("TOPLEFT",12,-34);toolbar:SetPoint("TOPRIGHT",-12,-34);toolbar:SetHeight(30)
    local canvas=CreateFrame("Frame",nil,window)
    canvas:SetPoint("TOPLEFT",12,-70);canvas:SetPoint("BOTTOMRIGHT",-12,34)
    local footer=CreateFrame("Frame",nil,window)
    footer:SetPoint("BOTTOMLEFT",12,3);footer:SetSize(410,25)
    local magnet=CreateFrame("CheckButton",nil,footer,"UICheckButtonTemplate")
    magnet:SetPoint("LEFT");magnet.Text:SetText("Snap edges and centres")
    magnet:SetScript("OnShow",function(self) self:SetChecked(A.db.designerSnap~=false) end)
    magnet:SetScript("OnClick",function(self) A.db.designerSnap=not not self:GetChecked() end)
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
    openRow.sync=function() sync();magnet:SetChecked(A.db.designerSnap~=false) end
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
    -- Store screen-space bounds at mouse-down so the snap targets never chase
    -- the moving part. Each axis releases when it leaves the magnetic radius.
    local function bounds(region)
        if not region or not region:IsVisible() then return end
        local x,y,w,h=region:GetRect()
        if not x or not y or not w or not h then return end
        local k=region:GetEffectiveScale()
        return {x*k,y*k,(x+w)*k,(y+h)*k}
    end
    local function snapAxis(first,last,near,far,delta,radius)
        local best
        for _,a in ipairs({first,last,(first+last)/2}) do
            for _,b in ipairs({near,far,(near+far)/2}) do
                local d=b-a-delta
                if math.abs(d)<=radius and (not best or math.abs(d)<math.abs(best)) then best=d end
            end
        end
        return best
    end
    local function snap(d,dx,dy)
        local r=d.rect
        if not r or A.db.designerSnap==false then return dx,dy end
        local bestX,bestY
        for _,t in ipairs(d.targets) do
            local gx=math.max(0,t[1]-r[3]-dx,r[1]+dx-t[3])
            local gy=math.max(0,t[2]-r[4]-dy,r[2]+dy-t[4])
            if gx<=16 and gy<=16 then
                local x=snapAxis(r[1],r[3],t[1],t[3],dx,5)
                local y=snapAxis(r[2],r[4],t[2],t[4],dy,5)
                if x and (not bestX or math.abs(x)<math.abs(bestX)) then bestX=x end
                if y and (not bestY or math.abs(y)<math.abs(bestY)) then bestY=y end
            end
        end
        return dx+(bestX or 0),dy+(bestY or 0)
    end
    local barFor={value="health",powerValue="power",castText="cast",castTime="cast"}
    local function union(a,b)
        if not a then return b end
        return {math.min(a[1],b[1]),math.min(a[2],b[2]),math.max(a[3],b[3]),math.max(a[4],b[4])}
    end
    local function overlaps(a,b)
        return a[1]<b[3] and a[3]>b[1] and a[2]<b[4] and a[4]>b[2]
    end
    -- Place neighbours against the dragged group first, then against each
    -- displaced group. Unaffected parts keep their mouse-down positions.
    local function moveNeighbours(d,draft,dx,dy)
        local moving=d.groups[d.key]
        if not moving or (dx==0 and dy==0) then return end
        local r=moving.rect
        local fixed={{r[1]+dx,r[2]+dy,r[3]+dx,r[4]+dy}}
        local function offset(key,x,y)
            local base=d.base[key] or {x=0,y=0,scale=1}
            local units=d.unitsByKey[key]
            draft[key]={x=base.x+x/units,y=base.y+y/units,scale=base.scale}
        end
        for _,key in ipairs(moving.members) do
            if key~=d.key then offset(key,dx,dy) end
        end
        local placed={[d.key]=true}
        for index=1,#parts do
            local obstacle=fixed[index]
            if not obstacle then break end
            for _,part in ipairs(parts) do
                local key=part[1]
                local group=d.groups[key]
                if group and not placed[key] and overlaps(group.rect,obstacle) then
                    local box=group.rect
                    local best
                    for _,other in ipairs(fixed) do
                        for _,delta in ipairs({{other[1]-box[3]-2,0},{other[3]-box[1]+2,0},
                            {0,other[2]-box[4]-2},{0,other[4]-box[2]+2}}) do
                            local x,y=delta[1],delta[2]
                            local rect={box[1]+x,box[2]+y,box[3]+x,box[4]+y}
                            local clear=true
                            for _,occupied in ipairs(fixed) do
                                if overlaps(rect,occupied) then clear=false;break end
                            end
                            local distance=math.abs(x)+math.abs(y)
                            if clear and (not best or distance<best.distance) then
                                best={x=x,y=y,rect=rect,distance=distance}
                            end
                        end
                    end
                    if best then
                        for _,member in ipairs(group.members) do offset(member,best.x,best.y) end
                        fixed[#fixed+1]=best.rect
                        placed[key]=true
                    end
                end
            end
        end
    end
    local drag,pan
    sample.cameraZoom=1
    sample.cameraX,sample.cameraY=0,0
    function sample:PositionCamera()
        local plate=self.sample
        if not plate or not self.designBaseScale then return end
        local scale=self.designBaseScale*self.cameraZoom
        plate:SetScale(scale)
        plate:ClearAllPoints()
        plate:SetPoint("CENTER",self,"CENTER",self.cameraX/scale,self.cameraY/scale)
    end
    local cameraText=label(footer,"100%",205)
    button(footer,"Centre view",259,103,function()
        sample.cameraX,sample.cameraY,sample.cameraZoom=0,0,1
        cameraText:SetText("100%")
        sample:PositionCamera()
    end)
    surface:EnableMouseWheel(true)
    surface:SetScript("OnMouseWheel",function(_,delta)
        if drag or pan then return end
        local old=sample.cameraZoom
        local zoom=math.max(.4,math.min(4,old*1.2^delta))
        local mx,my=GetCursorPosition()
        local cx,cy=sample:GetCenter()
        local k=sample:GetEffectiveScale()
        mx,my=mx/k-cx,my/k-cy
        sample.cameraX=mx+(sample.cameraX-mx)*zoom/old
        sample.cameraY=my+(sample.cameraY-my)*zoom/old
        sample.cameraZoom=zoom
        cameraText:SetText(("%d%%"):format(math.floor(zoom*100+.5)))
        sample:PositionCamera()
    end)
    surface:SetScript("OnMouseDown",function(_,mouse)
        if mouse~="LeftButton" and mouse~="RightButton" then return end
        if drag or pan then return end
        local hit=hitPart(sample.sample)
        if not hit then
            if mouse=="LeftButton" then
                local x,y=GetCursorPosition()
                pan={cx=x,cy=y,x=sample.cameraX,y=sample.cameraY}
            end
            return
        end
        selected=hit
        local key=parts[selected][1]
        local x,y,s=A.DesignerAura(key)
        local cx,cy=GetCursorPosition()
        local region=sample.sample[key]
        local owner=region and region:GetParent() or sample.sample
        local units=owner:GetEffectiveScale()
        drag={mouse=mouse,key=key,x=x,y=y,scale=s,cx=cx,cy=cy,units=units,region=region}
        drag.base=A.db.designer or {}
        drag.targets,drag.groups,drag.unitsByKey,drag.icons={},{},{},{}
        local function addBounds(r,k)
            local b=bounds(r)
            if not b then return end
            drag.unitsByKey[k]=r:GetParent():GetEffectiveScale()
            if k~=key then table.insert(drag.targets,b) else drag.rect=union(drag.rect,b) end
            -- A separately selected text label can be placed inside its own bar.
            local groupKey=barFor[k] or k
            if groupKey==barFor[key] and k~=key then return end
            if k==key then groupKey=key end
            local group=drag.groups[groupKey] or {members={}}
            drag.groups[groupKey]=group
            group.rect=union(group.rect,b)
            if group.members[#group.members]~=k then table.insert(group.members,k) end
        end
        for _,part in ipairs(parts) do addBounds(sample.sample[part[1]],part[1]) end
        for _,icon in ipairs(sample.sample.icons or {}) do
            if icon.designKey and icon:IsShown() then
                addBounds(icon,icon.designKey)
                local point,parent,anchor,px,py=icon:GetPoint(1)
                drag.icons[#drag.icons+1]={icon=icon,key=icon.designKey,point=point,parent=parent,anchor=anchor,
                    x=px,y=py,width=icon:GetWidth(),height=icon:GetHeight()}
            end
        end
        sample.designerDragging=true
        sync()
    end)
    local function finish(commit)
        if not drag then return end
        local draft=drag.draft
        drag=nil
        sample.designerDragging=nil
        if commit and draft then A.db.designer=draft;changed() end
        if sample:IsVisible() then A.DrawAuraExample(sample);sync() end
    end
    surface:SetScript("OnUpdate",function()
        if pan then
            if not IsMouseButtonDown("LeftButton") then pan=nil;return end
            local x,y=GetCursorPosition()
            local k=sample:GetEffectiveScale()
            sample.cameraX=pan.x+(x-pan.cx)/k
            sample.cameraY=pan.y+(y-pan.cy)/k
            sample:PositionCamera()
            return
        end
        if not drag then return end
        if not IsMouseButtonDown(drag.mouse) then finish(true);return end
        local cx,cy=GetCursorPosition()
        local factor=drag.units
        local dx,dy=cx-drag.cx,cy-drag.cy
        if drag.mouse=="LeftButton" then dx,dy=snap(drag,dx,dy) end
        dx,dy=dx/factor,dy/factor
        local function round(n) return math.floor(n+.5) end
        local x,y,s=drag.x,drag.y,drag.scale
        if not drag.lastScale and math.abs(dx)+math.abs(dy)<2 then return end
        if drag.mouse=="RightButton" then s=math.max(.25,math.min(3,round(s*100+dx)/100))
        else x,y=round(x+dx),round(y+dy) end
        if drag.lastX==x and drag.lastY==y and drag.lastScale==s then return end
        drag.lastX,drag.lastY,drag.lastScale=x,y,s
        local draft={}
        for k,v in pairs(drag.base) do draft[k]=v end
        draft[drag.key]={x=x,y=y,scale=s}
        if drag.mouse=="LeftButton" then moveNeighbours(drag,draft,(x-drag.x)*factor,(y-drag.y)*factor) end
        drag.draft=draft
        renderingDraft=draft
        A.DesignPlate(sample.sample)
        renderingDraft=nil
        local origins={}
        for _,saved in ipairs(drag.icons) do
            local base=drag.base[saved.key] or {x=0,y=0,scale=1}
            local now=draft[saved.key] or base
            local ratio=now.scale/base.scale
            local origin=origins[saved.key] or saved.x
            origins[saved.key]=origin
            saved.icon:SetSize(saved.width*ratio,saved.height*ratio)
            saved.icon:SetPoint(saved.point,saved.parent,saved.anchor,
                saved.x+now.x-base.x+(saved.x-origin)*(ratio-1),saved.y+now.y-base.y)
        end
        readout:SetText(("%+.0f, %+.0f   %d%%"):format(x,y,math.floor(s*100+.5)))
    end)
    surface:SetScript("OnMouseUp",function() pan=nil;finish(true) end)
    surface:SetScript("OnHide",function() pan=nil;finish(false) end)
    sample:SetScript("OnShow",function() A.DrawAuraExample(sample);sync() end)
    A.DrawAuraExample(sample)
    return function() if sample:IsVisible() and not sample.designerDragging then A.DrawAuraExample(sample);sync() end end
end
