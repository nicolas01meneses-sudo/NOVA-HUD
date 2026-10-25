-- NOVA HUD 3.7 — ice rock reposition, mobile slider and upgrade diagnostics
-- Local client UI and cautious interaction diagnostics.
-- No server access is assumed. Interactions are attempted only at ordinary in-game range.
-- Ice range is a search radius, not an override of the game's activation limit.
-- Upgrade automation uses available GUI/part interactions, without fabricating currency.

local Players = game:GetService('Players')
local Workspace = game:GetService('Workspace')
local TweenService = game:GetService('TweenService')
local UserInputService = game:GetService('UserInputService')
local VirtualUser = game:GetService('VirtualUser')
local player = Players.LocalPlayer
if not player then return end
local playerGui = player:WaitForChild('PlayerGui')
for _,oldName in ipairs({'NOVA_HUD_3_1','NOVA_HUD_3_2','NOVA_HUD_3_3','NOVA_HUD_3_4','NOVA_HUD_3_5','NOVA_HUD_3_6','NOVA_HUD_3_7'}) do
    local previous=playerGui:FindFirstChild(oldName)
    if previous then previous:Destroy() end
end

local COLOR = {
    bg=Color3.fromRGB(12,13,17), panel=Color3.fromRGB(18,19,25),
    nav=Color3.fromRGB(23,24,31), card=Color3.fromRGB(27,28,36),
    border=Color3.fromRGB(52,54,65), accent=Color3.fromRGB(91,180,247),
    bright=Color3.fromRGB(238,240,246), muted=Color3.fromRGB(163,167,179),
    success=Color3.fromRGB(96,215,160), warning=Color3.fromRGB(244,191,94),
    danger=Color3.fromRGB(247,110,123)
}
local function make(class,props,parent)
    local obj=Instance.new(class)
    for k,v in pairs(props or {}) do obj[k]=v end
    obj.Parent=parent
    return obj
end
local function corner(obj,rad)
    make('UICorner',{CornerRadius=UDim.new(0,rad or 9)},obj)
end
local function outline(obj)
    make('UIStroke',{Color=COLOR.border,Thickness=1,Transparency=.3},obj)
end
local function textLabel(parent,str,size,bold,color)
    return make('TextLabel',{
        Text=str,TextSize=size or 13,TextColor3=color or COLOR.bright,
        Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,
        BackgroundTransparency=1,BorderSizePixel=0,
        TextTruncate=Enum.TextTruncate.AtEnd,
    },parent)
end
local function roundedButton(parent,title,background,size)
    local b=make('TextButton',{
        Size=size or UDim2.fromOffset(34,30),BackgroundColor3=background or COLOR.card,
        BorderSizePixel=0,Text=title,TextColor3=COLOR.bright,
        Font=Enum.Font.GothamBold,TextSize=14,AutoButtonColor=false
    },parent)
    corner(b,7);return b
end

local state={fruit=false,ice=false,cash=false,buy=false,buyMars=false,needed=true,radar=false,iceTeleport=false,buyTeleport=false}
local running=true
local MAX_RANGE=14 -- fallback interaction distance, measured in studs
local STUDS_PER_METER=1/0.28 -- approximate Roblox unit conversion
local iceSearchMeters=10 -- adjustable range in the HUD; server interaction limits still apply
local DELAY=1.5
local buildMoveDelay=1.0
local BUILD_RETRY_COOLDOWN=4.5
local BUY_SEARCH_STUDS=80
local stats={attempts=0, errors=0, scanned=0, notices=0}
local hits={fruit={},ice={},cash={},buy={}}
local guiUpgrades={} -- regular visible upgrade GUI buttons, not remote events
local lastMoveAt=0
local lastBuildMoveAt=0
local lastIceMoveAt=0
local buildHops=0
local teleportLog={}
local teleportsFailed=0
local savedPosition=nil
local teleportCount=0
local detectedWorld=0
local lastAttempt={}
local highlights={}
local switches={} -- key -> array of synchronized render callbacks
local onToggle=nil
local statusNotice=nil

local gui=make('ScreenGui',{
    Name='NOVA_HUD_3_7',ResetOnSpawn=false,DisplayOrder=100,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,IgnoreGuiInset=false
},playerGui)
local window=make('Frame',{
    Name='Window',Size=UDim2.fromOffset(930,520),
    Position=UDim2.fromScale(.5,.51),AnchorPoint=Vector2.new(.5,.5),
    BackgroundColor3=COLOR.bg,BorderSizePixel=0,Active=true
},gui)
corner(window,14);outline(window)
local scale=make('UIScale',{Scale=1},window)
local viewportConnection
local function fitWindow()
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local vp=cam.ViewportSize
    scale.Scale=math.clamp(math.min((vp.X-24)/930,(vp.Y-48)/520),.48,1.55)
end
local function bindViewport()
    if viewportConnection then viewportConnection:Disconnect() end
    if Workspace.CurrentCamera then
        viewportConnection=Workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(fitWindow)
    end
    fitWindow()
end
bindViewport()
local cameraChanged=Workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(bindViewport)

local top=make('Frame',{
    Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,0,56),
    BackgroundColor3=COLOR.panel,BorderSizePixel=0,Active=true
},window)
corner(top,14)
local title=textLabel(top,'NOVA',21,true,COLOR.bright)
title.Position=UDim2.fromOffset(16,0);title.Size=UDim2.fromOffset(140,56)
local version=textLabel(top,'v3.7 • SELL LEMONS',12,true,COLOR.muted)
version.Position=UDim2.fromOffset(110,0);version.Size=UDim2.fromOffset(188,56)
local worldBadge=textLabel(top,'DETECTANDO...',12,true,COLOR.warning)
worldBadge.Position=UDim2.fromOffset(302,5)
worldBadge.Size=UDim2.fromOffset(130,46)
worldBadge.TextTruncate=Enum.TextTruncate.None
local autoButton=roundedButton(top,'VISTA AUTO',COLOR.card,UDim2.fromOffset(123,30))
autoButton.Position=UDim2.new(1,-219,0,13)
autoButton.TextSize=11
local min=roundedButton(top,'−',COLOR.card)
min.Position=UDim2.new(1,-88,0,13)
local close=roundedButton(top,'×',COLOR.card)
close.Position=UDim2.new(1,-45,0,13)
close.TextColor3=COLOR.danger
local restore=roundedButton(gui,'NOVA',COLOR.accent,UDim2.fromOffset(74,38))
restore.Position=UDim2.fromOffset(16,115)
restore.TextColor3=COLOR.bg
restore.Visible=false

local sidebar=make('Frame',{
    Position=UDim2.fromOffset(0,57),Size=UDim2.new(0,154,1,-94),
    BackgroundColor3=COLOR.panel,BorderSizePixel=0
},window)
make('UIListLayout',{
    FillDirection=Enum.FillDirection.Vertical,Padding=UDim.new(0,7),
    SortOrder=Enum.SortOrder.LayoutOrder
},sidebar)
make('UIPadding',{
    PaddingTop=UDim.new(0,14),PaddingLeft=UDim.new(0,10),
    PaddingRight=UDim.new(0,10)
},sidebar)
local content=make('Frame',{
    Position=UDim2.fromOffset(166,70),Size=UDim2.new(1,-182,1,-112),
    BackgroundTransparency=1
},window)
local footer=textLabel(window,'Iniciando escáner...',11,false,COLOR.muted)
footer.Position=UDim2.new(0,17,1,-28)
footer.Size=UDim2.new(1,-34,0,21)
footer.TextTruncate=Enum.TextTruncate.AtEnd

local pages,navButtons={},{}
local autoWorld=true
local selectedPage='World1'
local function showPage(key)
    if not pages[key] then return end
    selectedPage=key
    for name,page in pairs(pages) do page.Visible=(name==key) end
    for name,button in pairs(navButtons) do
        TweenService:Create(button,TweenInfo.new(.13),{
            BackgroundColor3=(name==key) and COLOR.accent or COLOR.nav,
            TextColor3=(name==key) and COLOR.bg or COLOR.bright
        }):Play()
    end
end
local function addPage(key,labelText,emoji)
    local p=make('Frame',{
        Name=key,Size=UDim2.fromScale(1,1),Visible=false,
        BackgroundTransparency=1
    },content)
    pages[key]=p
    local b=roundedButton(sidebar,'',COLOR.nav,UDim2.new(1,0,0,45))
    local ico=textLabel(b,emoji,18,true,COLOR.muted)
    ico.Position=UDim2.fromOffset(7,2)
    ico.Size=UDim2.fromOffset(24,41)
    local name=textLabel(b,labelText,12,true,COLOR.bright)
    name.Position=UDim2.fromOffset(33,0)
    name.Size=UDim2.new(1,-35,1,0)
    name.TextTruncate=Enum.TextTruncate.None
    navButtons[key]=b
    b.MouseButton1Click:Connect(function()
        if key~='Tools' then
            autoWorld=false
            autoButton.Text='VISTA MANUAL'
            autoButton.TextColor3=COLOR.warning
        end
        showPage(key)
    end)
    return p
end
local p1=addPage('World1','TIERRA','01')
local p2=addPage('World2','MARTE','02')
local pd=addPage('Tools','ESCÁNER','03')

local function columns(page)
    local holder=make('Frame',{Size=UDim2.fromScale(1,1),BackgroundTransparency=1},page)
    local left=make('ScrollingFrame',{
        Position=UDim2.fromScale(0,0),Size=UDim2.new(.49,0,1,0),
        ScrollBarThickness=3,ScrollBarImageColor3=COLOR.border,
        AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),
        ScrollingDirection=Enum.ScrollingDirection.Y,
        BorderSizePixel=0,BackgroundTransparency=1
    },holder)
    local right=make('ScrollingFrame',{
        Position=UDim2.new(.51,0,0,0),Size=UDim2.new(.49,0,1,0),
        ScrollBarThickness=3,ScrollBarImageColor3=COLOR.border,
        AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),
        ScrollingDirection=Enum.ScrollingDirection.Y,
        BorderSizePixel=0,BackgroundTransparency=1
    },holder)
    for _,v in ipairs({left,right}) do
        make('UIListLayout',{Padding=UDim.new(0,12),SortOrder=Enum.SortOrder.LayoutOrder},v)
        make('UIPadding',{
            PaddingLeft=UDim.new(0,2),PaddingRight=UDim.new(0,5),
            PaddingBottom=UDim.new(0,7)
        },v)
    end
    return left,right
end
local function section(parent,name)
    local holder=make('Frame',{
        Size=UDim2.new(1,-3,0,0),AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1
    },parent)
    make('UIListLayout',{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder},holder)
    local heading=textLabel(holder,name,13,true,COLOR.bright)
    heading.Size=UDim2.new(1,0,0,23)
    local card=make('Frame',{
        Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundColor3=COLOR.panel,BorderSizePixel=0
    },holder)
    corner(card,10);outline(card)
    make('UIListLayout',{Padding=UDim.new(0,0),SortOrder=Enum.SortOrder.LayoutOrder},card)
    make('UIPadding',{
        PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,4),
        PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)
    },card)
    return card
end
local function statusText(parent,str,dim)
    local h=textLabel(parent,str,dim and 11 or 12,false,dim and COLOR.muted or COLOR.bright)
    h.Size=UDim2.new(1,0,0,40)
    h.AutomaticSize=Enum.AutomaticSize.Y
    h.TextWrapped=true
    h.TextTruncate=Enum.TextTruncate.None
    h.TextYAlignment=Enum.TextYAlignment.Top
    return h
end
local function toggle(parent,titleText,key)
    local row=make('TextButton',{
        Text='',Size=UDim2.new(1,0,0,52),
        BackgroundColor3=COLOR.panel,BorderSizePixel=0,AutoButtonColor=false
    },parent)
    local txt=textLabel(row,titleText,12,false,COLOR.bright)
    txt.Position=UDim2.fromOffset(4,0)
    txt.Size=UDim2.new(1,-69,1,0)
    txt.TextWrapped=true
    txt.TextTruncate=Enum.TextTruncate.None
    local pill=make('Frame',{
        Position=UDim2.new(1,-58,.5,-12),Size=UDim2.fromOffset(50,24),
        BackgroundColor3=COLOR.border,BorderSizePixel=0
    },row)
    corner(pill,12)
    local dot=make('Frame',{
        Size=UDim2.fromOffset(18,18),Position=UDim2.fromOffset(3,3),
        BackgroundColor3=COLOR.bright,BorderSizePixel=0
    },pill)
    corner(dot,10)
    local function render()
        TweenService:Create(pill,TweenInfo.new(.16),{
            BackgroundColor3=state[key] and COLOR.success or COLOR.border
        }):Play()
        TweenService:Create(dot,TweenInfo.new(.16),{
            Position=UDim2.fromOffset(state[key] and 29 or 3,3)
        }):Play()
    end
    if not switches[key] then switches[key]={} end
    table.insert(switches[key],render)
    render() -- synchronize initial UI with actual state (needed starts ON)
    row.MouseButton1Click:Connect(function()
        local targetClass=({fruit='fruit',cash='cash',ice='ice',buy='buy',buyMars='buy'})[key]
        if not state[key] and targetClass and #hits[targetClass]==0
            and not (targetClass=='buy' and #guiUpgrades>0) then
            if onToggle then onToggle(key,'no-target') end
        end
        state[key]=not state[key]
        for _,draw in ipairs(switches[key]) do draw() end
        if onToggle then onToggle(key) end
    end)
    return row
end
local function action(parent,name,fn)
    local b=roundedButton(parent,name,COLOR.card,UDim2.new(1,0,0,44))
    b.TextSize=12
    b.TextWrapped=true
    b.TextTruncate=Enum.TextTruncate.None
    b.MouseButton1Click:Connect(fn)
    return b
end

-- La barra controla la búsqueda de objetivos, no la activación permitida.
local function distanceSlider(parent)
    local frame=make('Frame',{Size=UDim2.new(1,0,0,87),BackgroundTransparency=1},parent)
    local label=textLabel(frame,'RADIO DE BÚSQUEDA',12,true,COLOR.bright)
    label.Position=UDim2.fromOffset(6,0);label.Size=UDim2.new(.60,-6,0,28)
    local value=textLabel(frame,'10 m',12,true,COLOR.accent)
    value.TextXAlignment=Enum.TextXAlignment.Right
    value.Position=UDim2.new(.60,0,0,0);value.Size=UDim2.new(.40,-6,0,28)
    local track=make('TextButton',{Text='',AutoButtonColor=false,
        Position=UDim2.fromOffset(13,42),Size=UDim2.new(1,-26,0,10),
        BackgroundColor3=COLOR.border,BorderSizePixel=0},frame)
    corner(track,6)
    local fill=make('Frame',{Size=UDim2.fromScale(0,1),BackgroundColor3=COLOR.accent,BorderSizePixel=0},track)
    corner(fill,6)
    local knob=make('Frame',{Size=UDim2.fromOffset(20,20),AnchorPoint=Vector2.new(.5,.5),
        Position=UDim2.fromScale(0,.5),BackgroundColor3=COLOR.bright,BorderSizePixel=0},track)
    corner(knob,10)
    local left=textLabel(frame,'2 m',11,false,COLOR.muted)
    left.Position=UDim2.fromOffset(11,61);left.Size=UDim2.fromOffset(60,20)
    local right=textLabel(frame,'20 m',11,false,COLOR.muted)
    right.TextXAlignment=Enum.TextXAlignment.Right
    right.Position=UDim2.new(1,-75,0,61);right.Size=UDim2.fromOffset(62,20)
    local function paint()
        local t=(iceSearchMeters-2)/18
        fill.Size=UDim2.fromScale(t,1)
        knob.Position=UDim2.fromScale(t,.5)
        value.Text=string.format('%d m',iceSearchMeters)
    end
    local function setFromX(x)
        local t=math.clamp((x-track.AbsolutePosition.X)/math.max(1,track.AbsoluteSize.X),0,1)
        iceSearchMeters=math.clamp(math.floor(2+t*18+.5),2,20)
        paint()
    end
    local drag=nil
    track.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            drag=input;setFromX(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if drag and (input==drag or (drag.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement)) then setFromX(input.Position.X) end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input==drag or (drag and drag.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseButton1) then drag=nil end
    end)
    paint()
    return frame
end

-- Adjustable spacing between Auto Build platform visits (not server purchases).
local speedViews={}
local function addBuildSpeed(parent)
    local panel=make('Frame',{Size=UDim2.new(1,0,0,83),BackgroundTransparency=1},parent)
    local caption=textLabel(panel,'PAUSA ENTRE PLATAFORMAS',12,true,COLOR.bright)
    caption.Position=UDim2.fromOffset(6,0);caption.Size=UDim2.new(.7,-6,0,28)
    local value=textLabel(panel,'1.0 s',12,true,COLOR.accent)
    value.Position=UDim2.new(.7,0,0,0);value.Size=UDim2.new(.3,-6,0,28)
    value.TextXAlignment=Enum.TextXAlignment.Right
    table.insert(speedViews,value)
    local rail=make('TextButton',{Text='',AutoButtonColor=false,Size=UDim2.new(1,-28,0,10),
        Position=UDim2.fromOffset(14,40),BackgroundColor3=COLOR.border,BorderSizePixel=0},panel)
    corner(rail,6)
    local fill=make('Frame',{Size=UDim2.fromScale(0,1),BackgroundColor3=COLOR.accent,BorderSizePixel=0},rail)
    corner(fill,6)
    local knob=make('Frame',{Size=UDim2.fromOffset(20,20),AnchorPoint=Vector2.new(.5,.5),
        Position=UDim2.fromScale(0,.5),BackgroundColor3=COLOR.bright,BorderSizePixel=0},rail)
    corner(knob,10)
    local low=textLabel(panel,'RÁPIDO 0.6s',11,false,COLOR.muted)
    low.Position=UDim2.fromOffset(8,59);low.Size=UDim2.fromOffset(100,20)
    local high=textLabel(panel,'SUAVE 3.0s',11,false,COLOR.muted)
    high.Position=UDim2.new(1,-115,0,59);high.Size=UDim2.fromOffset(105,20)
    high.TextXAlignment=Enum.TextXAlignment.Right
    local function paint()
        local t=(buildMoveDelay-.6)/2.4
        fill.Size=UDim2.fromScale(t,1);knob.Position=UDim2.fromScale(t,.5)
        for _,v in ipairs(speedViews) do
            if v and v.Parent then v.Text=string.format('%.1f s',buildMoveDelay) end
        end
    end
    local dragging=false
    local function update(x)
        local t=math.clamp((x-rail.AbsolutePosition.X)/math.max(rail.AbsoluteSize.X,1),0,1)
        buildMoveDelay=math.floor((.6+2.4*t)*10+.5)/10
        paint()
    end
    rail.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging=true;update(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
            update(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
    end)
    paint()
end

local a,b=columns(p1)
local cBuild=section(a,'AUTO BUILD')
toggle(cBuild,'Comprar mejoras cercanas','buy')
toggle(cBuild,'Omitir botones invisibles','needed')
toggle(cBuild,'Ir a plataformas (experimental)','buyTeleport')
addBuildSpeed(cBuild)
statusText(cBuild,'Pausa ajustable entre plataformas. El salto no confirma una compra del servidor.',true)
local cProgress=section(a,'PROGRESSION')
statusText(cProgress,'Ascend y Powers: pendientes de verificar en el juego.',true)
local cCollect=section(b,'AUTO COLLECT')
toggle(cCollect,'Recoger fruta cercana','fruit')
toggle(cCollect,'Recoger dinero cercano','cash')
statusText(cCollect,'Si no hay objetivos, el interruptor no se activará.',true)
local cAbout=section(b,'ESTADO MUNDO 1')
local w1Status=statusText(cAbout,'Buscando objetivos...',false)

local la,lb=columns(p2)
local iceBox=section(la,'AUTO COLLECT')
toggle(iceBox,'Recoger hielo cercano','ice')
distanceSlider(iceBox)
toggle(iceBox,'Ir directamente a rocas lejanas','iceTeleport')
statusText(iceBox,'Activa también Recoger hielo. El radio solo limita qué rocas se buscan.',true)
local upgradeBox=section(la,'AUTO BUILD')
toggle(upgradeBox,'Comprar mejoras (Marte)','buyMars')
toggle(upgradeBox,'Ir a plataformas (experimental)','buyTeleport')
addBuildSpeed(upgradeBox)
statusText(upgradeBox,'Prioriza otras plataformas después de un salto. El juego valida las compras.',true)
local iceStats=section(lb,'ESTADO MARTE')
local w2Status=statusText(iceStats,'Buscando objetivos...',false)
local scopeBox=section(lb,'LÍMITES')
statusText(scopeBox,'El servidor puede corregir saltos y rechazar compras. NOVA detiene los saltos tras dos correcciones.',true)

local da,db=columns(pd)
local scanBox=section(da,'ESCÁNER DE OBJETOS')
local worldStatus=statusText(scanBox,'Mundo: buscando indicador de moneda...',true)
local scanStatus=statusText(scanBox,'Preparando escáner...',false)
local detection=statusText(scanBox,'Sin datos',true)
local inspection=statusText(scanBox,'Inspección: sin objetivo',true)
local function rootPart()
    local character=player.Character
    local root=character and character:FindFirstChild('HumanoidRootPart')
    return root and root:IsA('BasePart') and root or nil
end
local function anchorPart(obj)
    local cur=obj.Parent
    while cur and cur~=Workspace do
        if cur:IsA('BasePart') then return cur end
        cur=cur.Parent
    end
    return nil
end
local function distance(part)
    local root=rootPart()
    if not root then return math.huge end
    return (root.Position-part.Position).Magnitude
end
local function hasAny(haystack,words)
    for _,w in ipairs(words) do
        if string.find(haystack,w,1,true) then return true end
    end
    return false
end
local function isVisibleGui(item)
    local parent=item
    while parent and parent~=playerGui do
        if parent:IsA('GuiObject') and not parent.Visible then return false end
        if parent:IsA('ScreenGui') and not parent.Enabled then return false end
        parent=parent.Parent
    end
    return true
end
local BAD_PURCHASE={'robux','premium','gamepass','game pass','developer product','donate','donar','r$','skip','pagar con robux'}
local GOOD_UPGRADE={'upgrade','mejora','mejorar','buy button','comprar mejora','buy upgrade','remote buy'}
local function isSafeUpgradeText(str,context)
    local t=string.lower(str or '')
    local contextText=string.lower(context or '')
    if hasAny(t..' '..contextText,BAD_PURCHASE) then return false end
    if hasAny(contextText,{'robux','shop','store','tienda','pases'}) then return false end
    if hasAny(t,GOOD_UPGRADE) then return true end
    -- A regular Remote Buy button can simply be labelled BUY or COMPRAR.
    -- Only count that short label inside a contextual tycoon/remote-buy UI.
    if t:match('^%s*buy%s*$') or t:match('^%s*comprar%s*$') then
        return hasAny(contextText,{'tycoon','remotebuy','remote buy','plot','build','purchase'})
    end
    return false
end
local function scanUpgradeGui()
    local list={}
    local inspected=0
    -- Screen GUIs and real 3D SurfaceGui upgrade buttons are both supported.
    for _,host in ipairs({playerGui,Workspace}) do
        for _,item in ipairs(host:GetDescendants()) do
            if item:IsA('GuiButton') and not item:IsDescendantOf(gui) and isVisibleGui(item) then
                local surface=item:FindFirstAncestorOfClass('SurfaceGui')
                local billboard=item:FindFirstAncestorOfClass('BillboardGui')
                if host==playerGui or surface or billboard then
                    inspected=inspected+1
                    if inspected>1250 then break end
                    local words=(item:IsA('TextButton') and item.Text or '')
                    for _,desc in ipairs(item:GetDescendants()) do
                        if desc:IsA('TextLabel') and #words<220 then words=words..' '..desc.Text end
                    end
                    local context=''
                    local n=item.Parent
                    for _=1,4 do
                        if not n then break end
                        context=context..' '..n.Name
                        n=n.Parent
                    end
                    local hostPart=surface and (surface.Adornee or anchorPart(surface))
                        or (billboard and (billboard.Adornee or anchorPart(billboard)))
                    local closeEnough=host==playerGui or (hostPart and hostPart:IsA('BasePart') and distance(hostPart)<35)
                    if closeEnough and isSafeUpgradeText(words,context) then
                        table.insert(list,{obj=item,part=hostPart})
                    end
                end
            end
        end
    end
    return list
end
local function modelUpgradeLabels(part)
    local out={part.Name}
    if part.Parent then table.insert(out,part.Parent.Name) end
    local model=part:FindFirstAncestorOfClass('Model')
    if not model then return table.concat(out,' ') end
    local checks=0
    for _,d in ipairs(model:GetDescendants()) do
        checks=checks+1
        if checks>140 then break end
        if (d:IsA('TextLabel') or d:IsA('TextButton')) and d.Parent
            and (d:FindFirstAncestorOfClass('SurfaceGui') or d:FindFirstAncestorOfClass('BillboardGui')) then
            local t=d.Text or ''
            if #t<90 then table.insert(out,t) end
        end
    end
    return table.concat(out,' ')
end
local function classify(interaction)
    local parent=interaction.Parent
    local parentName=parent and string.lower(parent.Name) or ''
    local ownName=string.lower(interaction.Name)
    local labelText=''
    if interaction:IsA('ProximityPrompt') then
        labelText=string.lower((interaction.ActionText or '')..' '..(interaction.ObjectText or ''))
    end
    -- Limit labels to the interaction, its immediate parent and the prompt action.
    -- Do not classify an entire planet by an ancestor containing 'ice'.
    local grandparent=parent and parent.Parent
    local grandname=grandparent and grandparent~=Workspace and string.lower(grandparent.Name) or ''
    local direct=parentName..' '..ownName..' '..labelText..' '..grandname
    if interaction:IsA('TouchTransmitter') and parent and parent:IsA('BasePart') then
        direct=direct..' '..modelUpgradeLabels(parent)
    end
    if hasAny(direct,BAD_PURCHASE) then return nil end
    if hasAny(direct,{'ice chunk','icechunk','hielo','fragmento de hielo','ice pickup','ice collectible'}) then return 'ice' end
    if hasAny(direct,{'lemon','limon','fruit','fruta','orchard'}) then return 'fruit' end
    if hasAny(direct,{'cash drop','cashdrop','cash vine','cashvine','money drop','drop cash'}) then return 'cash' end
    if hasAny(direct,{'upgrade','button','boton','purchase','comprar','buy button','mejora','mejorar'}) then return 'buy' end
    return nil
end
local function scanWorld()
    local found={fruit={},ice={},cash={},buy={}}
    local scanned=0
    for _,obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA('ProximityPrompt') or obj:IsA('ClickDetector') or obj:IsA('TouchTransmitter') then
            scanned=scanned+1
            local category=classify(obj)
            if category then
                local part=anchorPart(obj)
                -- Only count compatible interactions in the nearby loaded zone.
                -- The previous version counted thousands of possible 'lemons'
                -- from the entire Workspace while standing on Mars.
                if part and distance(part)<=125
                    and not (detectedWorld==2 and (category=='fruit' or category=='cash'))
                    and not (detectedWorld==1 and category=='ice') then
                    table.insert(found[category],{obj=obj,part=part})
                end
            end
        end
    end
    hits=found
    guiUpgrades=scanUpgradeGui()
    stats.scanned=scanned
    return found
end
local function clearHighlights()
    for obj,h in pairs(highlights) do
        if h then h:Destroy() end
        highlights[obj]=nil
    end
end
local function updateHighlights()
    clearHighlights()
    if not state.radar then return end
    local added=0
    for _,bucket in ipairs({hits.fruit,hits.ice,hits.buy}) do
        for _,hit in ipairs(bucket) do
            if added>=22 then return end
            if hit.part:IsDescendantOf(Workspace) and not highlights[hit.part] then
                local h=make('Highlight',{
                    Adornee=hit.part,FillTransparency=.85,OutlineTransparency=0,
                    FillColor=COLOR.warning,OutlineColor=COLOR.accent,
                    DepthMode=Enum.HighlightDepthMode.Occluded
                },hit.part)
                highlights[hit.part]=h
                added=added+1
            end
        end
    end
end
onToggle=function(key,reason)
    if key=='radar' then updateHighlights() end
    if reason=='no-target' then
        -- Toggle remains available: show explicitly why there are no actions yet.
        if statusNotice then statusNotice('Activado sin objetivos compatibles para '..key..'. Revisa el escáner.') end
    end
end
-- Respect each prompt/click detector's MaxActivationDistance. Increasing
-- the slider does NOT bypass that distance: it only increases the search area.
local function allowedActivationDistance(obj)
    if obj:IsA('ClickDetector') or obj:IsA('ProximityPrompt') then
        return math.max(0,obj.MaxActivationDistance)
    end
    return 3 -- physical contact on touch pads
end
local function candidate(bucket,searchDistance,mustBeInRange)
    local best,bestDist=nil,math.huge
    for _,hit in ipairs(bucket) do
        if hit.obj.Parent and hit.part and hit.part.Parent
            and not (bucket==hits.buy and state.needed and hit.part.Transparency>0.85) then
            local d=distance(hit.part)
            if d<bestDist and d<=searchDistance
                and (not mustBeInRange or d<=allowedActivationDistance(hit.obj)) then
                best,bestDist=hit,d
            end
        end
    end
    return best,bestDist
end
local function nearby(bucket,range)
    return candidate(bucket,range or MAX_RANGE,true)
end
-- Reubicación local opcional: el servidor puede corregirla.
-- Do not keep returning to the same nearest upgrade pad.
local function nextBuildTarget()
    local now=os.clock()
    local best,bestScore=nil,math.huge
    for _,hit in ipairs(hits.buy) do
        if hit.obj and hit.obj.Parent and hit.part and hit.part:IsDescendantOf(Workspace)
            and (not state.needed or hit.part.Transparency<=.85)
            and (hit.obj:IsA('TouchTransmitter') or hit.obj:IsA('ProximityPrompt') or hit.obj:IsA('ClickDetector')) then
            local d=distance(hit.part)
            if d<=BUY_SEARCH_STUDS and now-(teleportLog[hit.obj] or -1e9)>=BUILD_RETRY_COOLDOWN then
                local score=d+(teleportLog[hit.obj] and 1000 or 0)
                if score<bestScore then best,bestScore=hit,score end
            end
        end
    end
    return best
end

local function repositionNear(hit,label,isPurchase)
    local root=rootPart()
    if not root or not hit or not hit.part or not hit.part:IsDescendantOf(Workspace) then return false end
    local char=player.Character
    local humanoid=char and char:FindFirstChildOfClass('Humanoid')
    if not char or not humanoid or humanoid.Health<=0 then return false end
    local now=os.clock()
    local delay=isPurchase and buildMoveDelay or 2.8
    local previous=isPurchase and lastBuildMoveAt or lastIceMoveAt
    local revisit=isPurchase and BUILD_RETRY_COOLDOWN or 12
    if now-lastMoveAt<.5 or now-previous<delay or now-(teleportLog[hit.obj] or -1e9)<revisit then return false end
    if distance(hit.part)>(isPurchase and BUY_SEARCH_STUDS or iceSearchMeters*STUDS_PER_METER) then return false end
    lastMoveAt=now
    if isPurchase then lastBuildMoveAt=now else lastIceMoveAt=now end
    teleportLog[hit.obj]=now
    if not savedPosition then savedPosition=char:GetPivot() end
    local part=hit.part
    local dest=part.Position+Vector3.new(0,math.clamp(part.Size.Y*.5+3,3,8),0)
    local before=root.Position
    local ok,err=pcall(function() char:PivotTo(CFrame.new(dest,dest+root.CFrame.LookVector)) end)
    if not ok then
        if statusNotice then statusNotice('Salto fallido: '..tostring(err)) end
        return false
    end
    teleportCount=teleportCount+1
    if isPurchase then buildHops=buildHops+1 end
    if statusNotice then statusNotice(label..': salto local enviado (sin confirmar recolección)') end
    task.delay(.55,function()
        if not running or not gui.Parent then return end
        local current=rootPart()
        if not current then return end
        if (current.Position-dest).Magnitude>18 and (current.Position-before).Magnitude<9 then
            teleportsFailed=teleportsFailed+1
            if statusNotice then statusNotice('Posición corregida por el juego: '..teleportsFailed..'/2') end
            if teleportsFailed>=2 then
                state.iceTeleport=false;state.buyTeleport=false
                for _,key in ipairs({'iceTeleport','buyTeleport'}) do
                    for _,draw in ipairs(switches[key] or {}) do draw() end
                end
                if statusNotice then statusNotice('Saltos desactivados: el juego revirtió el movimiento') end
            end
        else teleportsFailed=0 end
    end)
    return true
end
local function attemptInteraction(hit)
    if not hit then return false,'Sin objetivos cercanos' end
    local obj=hit.obj
    if os.clock()-(lastAttempt[obj] or -1e9)<DELAY then return false,'En espera' end
    lastAttempt[obj]=os.clock()
    local ok,err
    if obj:IsA('ClickDetector') then
        if type(fireclickdetector)~='function' then return false,'Click API no disponible' end
        ok,err=pcall(function() fireclickdetector(obj) end)
    elseif obj:IsA('GuiButton') then
        if not isVisibleGui(obj) then return false,'Botón fuera de pantalla' end
        -- GuiButton.Activated is an EVENT, not a callable method.
        -- Use Roblox's supported virtual input API if it is available.
        local p=obj.AbsolutePosition
        local z=obj.AbsoluteSize
        local center=Vector2.new(p.X+z.X/2,p.Y+z.Y/2)
        if z.X<6 or z.Y<6 then return false,'Botón sin área visible' end
        if window.Visible then
            local wp,wz=window.AbsolutePosition,window.AbsoluteSize
            if center.X>=wp.X and center.X<=wp.X+wz.X
                and center.Y>=wp.Y and center.Y<=wp.Y+wz.Y then
                return false,'Minimiza NOVA: tapa el botón de compra'
            end
        end
        -- GuiButton.Activated es un evento, no un método.
        ok,err=pcall(function()
            local cam=Workspace.CurrentCamera
            VirtualUser:CaptureController()
            VirtualUser:Button1Down(center,cam and cam.CFrame or CFrame.new())
            task.wait(.08)
            VirtualUser:Button1Up(center,cam and cam.CFrame or CFrame.new())
        end)
        if not ok then return false,'Entrada UI no disponible: '..tostring(err) end
    elseif obj:IsA('TouchTransmitter') then
        -- Touch-based upgrades need the character to stand on the pad.
        -- A local "firetouchinterest" call alone would not prove a real purchase.
        return false,'Plataforma: acercarse caminando (opcional)'
    elseif obj:IsA('ProximityPrompt') then
        if not obj.Enabled then return false,'Prompt deshabilitado' end
        ok,err=pcall(function()
            obj:InputHoldBegin()
            task.delay(math.max(obj.HoldDuration,0)+.06,function()
                if running and obj.Parent then pcall(function() obj:InputHoldEnd() end) end
            end)
        end)
    else
        return false,'Interacción no compatible'
    end
    if ok then stats.attempts=stats.attempts+1 else stats.errors=stats.errors+1 end
    return ok,ok and 'Intento enviado (sin confirmación)' or tostring(err)
end
-- Automatic world detection: read only public UI/attributes; never manipulate game state.
-- World 1 currency in supplied screenshots starts with '$'; Mars starts with 'Φ'.
local detectedReason='Indicador de mundo no encontrado'
local pendingWorld,pendingCount=0,0
local unknownCount=0
local function parseWorldValue(value)
    if value==1 or value=='1' then return 1 end
    if value==2 or value=='2' then return 2 end
    if type(value)=='string' then
        local s=value:lower()
        if s=='mars' or s=='marte' or s=='world2' or s=='mundo2' or s=='world 2' or s=='mundo 2' then return 2 end
        if s=='earth' or s=='tierra' or s=='world1' or s=='mundo1' or s=='world 1' or s=='mundo 1' then return 1 end
    end
    return 0
end
local function inspectWorld()
    for _,host in ipairs({player,Workspace}) do
        for _,key in ipairs({'CurrentWorld','WorldNumber','WorldIndex','World','MundoActual','CurrentPlanet'}) do
            local v=parseWorldValue(host:GetAttribute(key))
            if v~=0 then return v,'Atributo '..key end
        end
    end
    local w1,w2=0,0
    local why1,why2='',''
    local checked=0
    for _,item in ipairs(playerGui:GetDescendants()) do
        if checked>1400 then break end
        if (item:IsA('TextLabel') or item:IsA('TextButton')) and not item:IsDescendantOf(gui) then
            checked=checked+1
            local t=item.Text or ''
            if t~='' and #t<160 then
                local isVisible=item.Visible
                local a=item.Parent
                while a and a~=playerGui and isVisible do
                    if a:IsA('GuiObject') and not a.Visible then isVisible=false end
                    if a:IsA('ScreenGui') and not a.Enabled then isVisible=false end
                    a=a.Parent
                end
                if isVisible then
                    if t:match('^%s*Φ') or t:match('^%s*ϕ') or t:match('^%s*φ') then
                        local points=(item.TextSize>=17 and 12 or 7) + ((item.AbsolutePosition.Y<125 and item.AbsolutePosition.Y>=0) and 7 or 0)
                        if points>w2 then w2=points;why2='Moneda Φ en HUD' end
                    elseif t:match('^%s*%$') then
                        local points=(item.TextSize>=17 and 12 or 7) + ((item.AbsolutePosition.Y<125 and item.AbsolutePosition.Y>=0) and 7 or 0)
                        if points>w1 then w1=points;why1='Moneda $ en HUD' end
                    end
                    local lc=t:lower()
                    if lc:find('oxygen',1,true) and w2<2 then w2=2;why2='Texto Oxygen' end
                    if lc:find('marte',1,true) and w2<2 then w2=2;why2='Texto Marte' end
                end
            end
        end
    end
    if w2>=7 and w2>w1 then return 2,why2 end
    if w1>=7 and w1>w2 then return 1,why1 end
    return 0,'Sin indicador de moneda fiable'
end
local function displayDetection()
    local name=detectedWorld==1 and 'MUNDO 1' or (detectedWorld==2 and 'MARTE' or 'SIN DETECTAR')
    worldBadge.Text=name
    worldBadge.TextColor3=detectedWorld==0 and COLOR.warning or COLOR.success
    autoButton.Text=autoWorld and 'VISTA AUTO' or 'VISTA MANUAL'
    autoButton.TextColor3=autoWorld and COLOR.success or COLOR.warning
    worldStatus.Text='Mundo: '..name..'  |  '..detectedReason..'\nVista: '..(autoWorld and 'automática' or 'manual')
end
local function detectWorld()
    local candidate,reason=inspectWorld()
    if candidate==0 then
        pendingWorld,pendingCount=0,0
        unknownCount=unknownCount+1
        if unknownCount>=4 then
            detectedWorld=0
            detectedReason=reason
        end
        displayDetection()
        return
    end
    unknownCount=0
    if pendingWorld==candidate then pendingCount=pendingCount+1
    else pendingWorld,pendingCount=candidate,1 end
    if pendingCount>=2 then
        local changed=detectedWorld~=candidate
        detectedWorld,detectedReason=candidate,reason
        if changed and autoWorld then showPage(candidate==1 and 'World1' or 'World2') end
    end
    displayDetection()
end
autoButton.MouseButton1Click:Connect(function()
    autoWorld=not autoWorld
    if autoWorld and detectedWorld~=0 then
        showPage(detectedWorld==1 and 'World1' or 'World2')
    end
    displayDetection()
end)
local latestMessage='Sin intentos todavía'
local function countBlueParts()
    local root=rootPart()
    if not root then return 0 end
    local op=OverlapParams.new()
    op.FilterType=Enum.RaycastFilterType.Exclude
    op.FilterDescendantsInstances=player.Character and {player.Character} or {}
    op.MaxParts=1800
    local ok,parts=pcall(function()return Workspace:GetPartBoundsInRadius(root.Position,70,op)end)
    if not ok then return 0 end
    local n=0
    for _,part in ipairs(parts) do
        if part:IsA('BasePart') then
            local c=part.Color
            -- Bright cyan parts like the crystals in the user video. Visual clue ONLY.
            if c.B>.64 and c.G>.55 and c.R<.70 and c.B>c.R*1.24
                and part.Size.Magnitude<30 then n=n+1 end
        end
    end
    return n
end
local function refresh()
    scanWorld()
    updateHighlights()
    local f,i,c,u=#hits.fruit,#hits.ice,#hits.cash,#hits.buy
    scanStatus.Text=string.format('Candidatos próximos (125 studs):\nfruta %d | hielo %d | dinero %d | mejoras %d\nBotones UI de mejoras: %d',f,i,c,u,#guiUpgrades)
    detection.Text=string.format('Interacciones examinadas: %d\nClick API: %s | saltos: %d',stats.scanned,type(fireclickdetector)=='function' and 'disponible' or 'no disponible',teleportCount)
    w1Status.Text=string.format('Fruta %d  |  dinero %d\nMejoras: %d físicas + %d UI',f,c,u,#guiUpgrades)
    local iceRadius=iceSearchMeters*STUDS_PER_METER
    local iceInSearch=candidate(hits.ice,iceRadius,false)
    local iceInReach=nearby(hits.ice,iceRadius)
    w2Status.Text=string.format('Hielo: %d compatible | %d cristales visuales\nRadio de búsqueda: %d m (≈ %d studs)\n%s\nMejoras: %d físicas + %d UI',
        i,countBlueParts(),iceSearchMeters,math.floor(iceRadius+.5),
        iceInReach and 'Hielo al alcance de interacción' or (iceInSearch and 'Hielo localizado, demasiado lejos para interactuar' or 'No hay hielo en el radio'),
        u,#guiUpgrades)
    footer.Text=string.format('Hielo %d | mejoras %d + UI %d | saltos %d (build %d) | intentos %d',i,u,#guiUpgrades,teleportCount,buildHops,stats.attempts)
end
local debugBox=section(db,'CONTROL Y ESTADO')
local lastStatus=statusText(debugBox,'Sin intentos',true)
statusNotice=function(message) lastStatus.Text=message end
local radarBox=section(db,'VISUAL')
toggle(radarBox,'Resaltar objetivos detectados','radar')
local lastRefresh=0
local function doRefresh()
    refresh()
    lastRefresh=os.clock()
end
action(scanBox,'↻ Escanear zona cercana',doRefresh)
-- Raycast is only diagnostic: it does not interact with the game.
action(scanBox,'Inspeccionar centro de pantalla',function()
    local camera=Workspace.CurrentCamera
    if not camera then inspection.Text='Sin cámara activa';return end
    local vp=camera.ViewportSize
    local ray=camera:ViewportPointToRay(vp.X/2,vp.Y/2)
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances=player.Character and {player.Character} or {}
    local result=Workspace:Raycast(ray.Origin,ray.Direction*150,params)
    if not result then inspection.Text='No hay pieza frente a la cámara';return end
    local part=result.Instance
    local parent=part.Parent
    local clickCount,promptCount=0,0
    -- Ancestors/descendants are read only to report available interaction types.
    for _,obj in ipairs(parent and parent:GetDescendants() or {}) do
        if obj:IsA('ClickDetector') then clickCount=clickCount+1 end
        if obj:IsA('ProximityPrompt') then promptCount=promptCount+1 end
    end
    inspection.Text=string.format('Pieza: %s\nModelo: %s\nClickDetector: %d | Prompt: %d',
        part.Name, parent and parent.Name or 'ninguno',clickCount,promptCount)
end)
-- Touch inspection: lets a user precisely select the BLUE crystal instead of
-- always raycasting the screen centre (which selected GroundMain in the video).
local tapConnection=nil
local tapSequence=0
local hint=roundedButton(gui,'TOCA EL CRISTAL  •  cancelar',COLOR.accent,UDim2.fromOffset(390,46))
hint.Position=UDim2.new(.5,-195,0,100)
hint.TextColor3=COLOR.bg
hint.TextSize=15
hint.Visible=false
local function inspectPartAt(pos)
    local cam=Workspace.CurrentCamera
    if not cam then return 'Sin camara' end
    -- InputObject.Position is in screen coordinates, so ScreenPointToRay
    -- handles Roblox top-bar inset appropriately.
    local ray=cam:ScreenPointToRay(pos.X,pos.Y)
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances=player.Character and {player.Character} or {}
    local result=Workspace:Raycast(ray.Origin,ray.Direction*300,params)
    if not result then return 'Sin pieza bajo el toque' end
    local part=result.Instance
    local model=part:FindFirstAncestorOfClass('Model')
    local scope=model or part.Parent
    local clues={}
    local ancestor=part
    for _=1,4 do
        if not ancestor or ancestor==Workspace then break end
        table.insert(clues,ancestor.Name)
        ancestor=ancestor.Parent
    end
    local detectors,prompts=0,0
    if scope then
        for _,desc in ipairs(scope:GetDescendants()) do
            if desc:IsA('ClickDetector') then detectors=detectors+1 end
            if desc:IsA('ProximityPrompt') then prompts=prompts+1 end
        end
    end
    local color=part.Color
    return string.format('Tocado: %s\nRuta corta: %s\nColor RGB: %d/%d/%d\nClick: %d  |  Prompt: %d',
        part.Name,table.concat(clues,' / '),math.floor(color.R*255+.5),
        math.floor(color.G*255+.5),math.floor(color.B*255+.5),detectors,prompts)
end
local function finishTap()
    if tapConnection then tapConnection:Disconnect();tapConnection=nil end
    hint.Visible=false
    window.Visible=true
    restore.Visible=false
    showPage('Tools')
end
hint.MouseButton1Click:Connect(function()tapSequence=tapSequence+1;finishTap()end)
action(scanBox,'TOCAR OBJETO EN EL MAPA',function()
    tapSequence=tapSequence+1
    local seq=tapSequence
    if tapConnection then tapConnection:Disconnect();tapConnection=nil end
    window.Visible=false
    restore.Visible=false
    hint.Visible=true
    inspection.Text='Modo toque: selecciona un cristal azul, no el suelo.'
    task.delay(.25,function()
        if seq~=tapSequence or not gui.Parent then return end
        tapConnection=UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType~=Enum.UserInputType.Touch and input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
            local px,py=input.Position.X,input.Position.Y
            -- The small top banner is a cancel button, not a resource target.
            local hp=hint.AbsolutePosition
            local hs=hint.AbsoluteSize
            if px>=hp.X and px<=hp.X+hs.X and py>=hp.Y and py<=hp.Y+hs.Y then return end
            inspection.Text=inspectPartAt(input.Position)
            tapSequence=tapSequence+1
            finishTap()
        end)
    end)
    task.delay(18,function()
        if seq==tapSequence and gui.Parent then
            inspection.Text='Inspección cancelada: no se tocó un objeto.'
            tapSequence=tapSequence+1
            finishTap()
        end
    end)
end)
action(scanBox,'Ver tipos de botones de mejora',function()
    local near=candidate(hits.buy,125,false)
    local names={}
    for _,h in ipairs(guiUpgrades) do
        table.insert(names,(h.obj:IsA('TextButton') and h.obj.Text or h.obj.Name):sub(1,26))
        if #names>=3 then break end
    end
    local detail=(#names>0) and table.concat(names,' / ') or 'ninguno'
    inspection.Text=string.format('Compras físicas: %d | UI: %d\nCercana: %s (%s)\nBotones UI: %s',
        #hits.buy,#guiUpgrades,near and near.part.Name or 'ninguno',near and near.obj.ClassName or '-',detail)
end)
action(scanBox,'Probar fruta cercana',function()
    local h=nearby(hits.fruit)
    local ok,msg=attemptInteraction(h)
    latestMessage=(ok and 'Limón: ' or 'Limón: ')..msg
    lastStatus.Text=latestMessage
    refresh()
end)
action(scanBox,'Probar hielo cercano',function()
    local h=nearby(hits.ice)
    local _,msg=attemptInteraction(h)
    latestMessage='Hielo: '..msg
    lastStatus.Text=latestMessage
    refresh()
end)
action(scanBox,'Ir a hielo lejano (prueba)',function()
    if detectedWorld~=2 then if statusNotice then statusNotice('Prueba disponible en Marte') end return end
    local hit=candidate(hits.ice,iceSearchMeters*STUDS_PER_METER,false)
    if not hit then if statusNotice then statusNotice('No hay roca compatible en el radio') end return end
    if not repositionNear(hit,'Prueba: roca con hielo',false) and statusNotice then
        statusNotice('No se pudo saltar: objetivo o límite de espera')
    end
end)
action(scanBox,'Probar mejora cercana',function()
    local hit=nearby(hits.buy)
    if hit and (hit.obj:IsA('ClickDetector') or hit.obj:IsA('ProximityPrompt')) then
        local _,msg=attemptInteraction(hit)
        if statusNotice then statusNotice('Mejora física: '..msg) end
    elseif #guiUpgrades>0 then
        local _,msg=attemptInteraction(guiUpgrades[1])
        if statusNotice then statusNotice('Mejora UI: '..msg) end
    elseif statusNotice then
        statusNotice('Sin botón compatible; abre Manage y vuelve a escanear')
    end
end)
action(debugBox,'Volver a posición guardada',function()
    local char=player.Character
    if not savedPosition or not char then lastStatus.Text='No hay posición guardada';return end
    local ok=pcall(function() char:PivotTo(savedPosition) end)
    if statusNotice then statusNotice(ok and 'Regreso solicitado' or 'Regreso fallido') end
    if ok then savedPosition=nil end
end)
action(debugBox,'Detener funciones',function()
    for k in pairs(state) do state[k]=false end
    for _,draws in pairs(switches) do
        for _,draw in ipairs(draws) do draw() end
    end
    clearHighlights()
    latestMessage='Controles desactivados; no hay confirmación de recolección'
    lastStatus.Text=latestMessage
end)

local function stopHud()
    running=false
    clearHighlights()
    if viewportConnection then viewportConnection:Disconnect() end
    if cameraChanged then cameraChanged:Disconnect() end
    gui:Destroy()
end
close.MouseButton1Click:Connect(stopHud)
min.MouseButton1Click:Connect(function()
    window.Visible=false;restore.Visible=true
end)
restore.MouseButton1Click:Connect(function()
    window.Visible=true;restore.Visible=false
end)
local dragging=false
local dragInput,dragStart,windowStart
local function dragTo(input)
    if not dragging or not dragStart then return end
    local delta=input.Position-dragStart
    window.Position=UDim2.new(windowStart.X.Scale,windowStart.X.Offset+delta.X,windowStart.Y.Scale,windowStart.Y.Offset+delta.Y)
end
top.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        dragging=true;dragInput=input;dragStart=input.Position;windowStart=window.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input==dragInput) then dragTo(input) end
end)
UserInputService.InputEnded:Connect(function(input)
    if input==dragInput then dragging=false;dragInput=nil end
end)
UserInputService.InputBegan:Connect(function(input,gameProcessed)
    if not gameProcessed and input.KeyCode==Enum.KeyCode.RightShift and gui.Parent then
        window.Visible=not window.Visible
        restore.Visible=not window.Visible
    end
end)
showPage('World1')
detectWorld()
refresh()

-- Only attempt visible or near-enough interactions at a controlled rate.
-- Not tested in Sell Lemons. A successful API call does not confirm collection.
-- If an entry cannot be identified, there is no action to fire.
local lastDetection=0
task.spawn(function()
    while running and gui.Parent do
        local buildActive=(detectedWorld==1 and state.buy) or (detectedWorld==2 and state.buyMars)
        if os.clock()-lastRefresh>(buildActive and 1.7 or 9) then doRefresh() end
        if os.clock()-(lastDetection or -1e9)>2.5 then
            lastDetection=os.clock()
            detectWorld()
        end
        for _,rule in ipairs({
            {key='fruit',bucket='fruit'},
            {key='ice',bucket='ice'},
            {key='cash',bucket='cash'},
            {key='buy',bucket='buy'},
            {key='buyMars',bucket='buy'}
        }) do
            local matchesWorld=(detectedWorld==1 and rule.key~='ice' and rule.key~='buyMars')
                or (detectedWorld==2 and (rule.key=='ice' or rule.key=='buyMars'))
            if state[rule.key] and matchesWorld then
                local isIce=rule.key=='ice'
                local isBuy=rule.key=='buy' or rule.key=='buyMars'
                local iceRadius=iceSearchMeters*STUDS_PER_METER
                local h=nearby(hits[rule.bucket],isIce and iceRadius or MAX_RANGE)
                if isBuy then
                    local nearPhysical=nil
                    for _,item in ipairs(hits.buy) do
                        if item.part and item.part.Parent and item.obj.Parent
                            and (item.obj:IsA('ClickDetector') or item.obj:IsA('ProximityPrompt'))
                            and distance(item.part)<=allowedActivationDistance(item.obj) then
                            nearPhysical=item;break
                        end
                    end
                    if nearPhysical then
                        local _,msg=attemptInteraction(nearPhysical)
                        if statusNotice then statusNotice('Mejora: '..msg) end
                    elseif state.buyTeleport then
                        local far=nextBuildTarget()
                        if far then
                            repositionNear(far,'Siguiente plataforma',true)
                        elseif #guiUpgrades>0 then
                            local _,msg=attemptInteraction(guiUpgrades[1])
                            if statusNotice then statusNotice('Mejora UI: '..msg) end
                        end
                    elseif #guiUpgrades>0 then
                        local _,msg=attemptInteraction(guiUpgrades[1])
                        if statusNotice then statusNotice('Mejora UI: '..msg) end
                    end
                elseif h then
                    local _,msg=attemptInteraction(h)
                    if statusNotice then statusNotice(rule.key..': '..msg) end
                elseif isIce and state.iceTeleport and not (state.buyTeleport and buildActive) then
                    local far=candidate(hits.ice,iceRadius,false)
                    if far then repositionNear(far,'Roca con hielo',false) end
                end
            end
        end
        footer.Text=string.format('Hielo %d | mejoras %d + UI %d | saltos %d (build %d) | intentos %d',
            #hits.ice,#hits.buy,#guiUpgrades,teleportCount,buildHops,stats.attempts)
        task.wait(buildActive and .25 or .7)
    end
end)
