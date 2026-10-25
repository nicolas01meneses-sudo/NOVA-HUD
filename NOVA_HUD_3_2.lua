-- NOVA HUD 3.2 — responsive mobile HUD + passive automatic world detection
-- Local client UI and cautious interaction diagnostics.
-- No server access is assumed. Interactions are attempted only at ordinary in-game range.
-- It does not manufacture money, bypass purchases, or inspect private remote events.

local Players = game:GetService('Players')
local Workspace = game:GetService('Workspace')
local TweenService = game:GetService('TweenService')
local UserInputService = game:GetService('UserInputService')
local player = Players.LocalPlayer
if not player then return end
local playerGui = player:WaitForChild('PlayerGui')
for _,oldName in ipairs({'NOVA_HUD_3_1','NOVA_HUD_3_2'}) do
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

local state={fruit=false,ice=false,cash=false,buy=false,needed=true,radar=false}
local running=true
local MAX_RANGE=14
local DELAY=1.5
local stats={attempts=0, errors=0, scanned=0, notices=0}
local hits={fruit={},ice={},cash={},buy={}}
local lastAttempt={}
local highlights={}
local switches={}
local onToggle=nil

local gui=make('ScreenGui',{
    Name='NOVA_HUD_3_2',ResetOnSpawn=false,DisplayOrder=100,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,IgnoreGuiInset=false
},playerGui)
local window=make('Frame',{
    Name='Window',Size=UDim2.fromOffset(900,495),
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
    scale.Scale=math.clamp(math.min((vp.X-28)/900,(vp.Y-54)/495),.48,1.15)
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
local title=textLabel(top,'NOVA',23,true,COLOR.bright)
title.Position=UDim2.fromOffset(19,0);title.Size=UDim2.fromOffset(92,56)
local version=textLabel(top,'v3.2   •   SELL LEMONS',12,true,COLOR.muted)
version.Position=UDim2.fromOffset(115,2);version.Size=UDim2.fromOffset(205,52)
local worldBadge=textLabel(top,'🌐 DETECTANDO...',11,true,COLOR.warning)
worldBadge.Position=UDim2.fromOffset(334,6)
worldBadge.Size=UDim2.fromOffset(310,44)
worldBadge.TextTruncate=Enum.TextTruncate.AtEnd
local autoButton=roundedButton(top,'AUTO: ON',COLOR.card,UDim2.fromOffset(85,30))
autoButton.Position=UDim2.new(1,-181,0,13)
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
    Position=UDim2.fromOffset(0,57),Size=UDim2.new(0,178,1,-94),
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
    Position=UDim2.fromOffset(193,70),Size=UDim2.new(1,-210,1,-112),
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
    ico.Position=UDim2.fromOffset(10,2)
    ico.Size=UDim2.fromOffset(29,41)
    local name=textLabel(b,labelText,12,true,COLOR.bright)
    name.Position=UDim2.fromOffset(43,0)
    name.Size=UDim2.new(1,-47,1,0)
    name.TextTruncate=Enum.TextTruncate.AtEnd
    navButtons[key]=b
    b.MouseButton1Click:Connect(function()
        if key~='Tools' then
            autoWorld=false
            autoButton.Text='AUTO: OFF'
            autoButton.TextColor3=COLOR.warning
        end
        showPage(key)
    end)
    return p
end
local p1=addPage('World1','MUNDO 1','🍋')
local p2=addPage('World2','MARTE','🪐')
local pd=addPage('Tools','DIAGNÓSTICO','⚙')

local function columns(page)
    local holder=make('Frame',{Size=UDim2.fromScale(1,1),BackgroundTransparency=1},page)
    local left=make('ScrollingFrame',{
        Position=UDim2.fromScale(0,0),Size=UDim2.new(.485,0,1,0),
        ScrollBarThickness=3,ScrollBarImageColor3=COLOR.border,
        AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),
        ScrollingDirection=Enum.ScrollingDirection.Y,
        BorderSizePixel=0,BackgroundTransparency=1
    },holder)
    local right=make('ScrollingFrame',{
        Position=UDim2.new(.515,0,0,0),Size=UDim2.new(.485,0,1,0),
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
    h.Size=UDim2.new(1,0,0,32)
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
    switches[key]=render
    row.MouseButton1Click:Connect(function()
        state[key]=not state[key]
        render()
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

local a,b=columns(p1)
local cBuild=section(a,'AUTO BUILD')
toggle(cBuild,'Auto Buy Buttons','buy')
toggle(cBuild,'Solo botones visibles','needed')
statusText(cBuild,'Solo prueba interacciones cercanas identificadas. No modifica dinero.',true)
local cProgress=section(a,'PROGRESSION')
statusText(cProgress,'Ascend y Powers: pendientes de verificar en el juego.',true)
local cCollect=section(b,'AUTO COLLECT')
toggle(cCollect,'Auto Collect Lemon Tree','fruit')
toggle(cCollect,'Auto Collect Cash Drops','cash')
statusText(cCollect,'Solo funciona con interacciones compatibles cercanas.',true)
local cAbout=section(b,'ESTADO MUNDO 1')
local w1Status=statusText(cAbout,'Buscando objetivos...',false)

local la,lb=columns(p2)
local iceBox=section(la,'AUTO COLLECT')
toggle(iceBox,'Auto Collect Ice Chunks','ice')
statusText(iceBox,'Interacción local con hielo cercano, si está disponible.',true)
local upgradeBox=section(la,'AUTO BUILD')
statusText(upgradeBox,'El control de compras está en Mundo 1.',true)
local iceStats=section(lb,'ESTADO MARTE')
local w2Status=statusText(iceStats,'Buscando objetivos...',false)
local scopeBox=section(lb,'LÍMITES')
statusText(scopeBox,'Los intentos no garantizan que el servidor registre una recolección.',true)

local da,db=columns(pd)
local scanBox=section(da,'OBJECT SCANNER')
local worldStatus=statusText(scanBox,'Mundo: buscando indicador de moneda...',true)
local scanStatus=statusText(scanBox,'Preparando escáner...',false)
local detection=statusText(scanBox,'Sin datos',true)
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
    local direct=parentName..' '..ownName..' '..labelText
    if hasAny(direct,{'robux','gamepass','developer product','premium','donate'}) then return nil end
    if hasAny(direct,{'ice chunk','icechunk','hielo','fragmento de hielo','ice pickup','ice collectible'}) then return 'ice' end
    if hasAny(direct,{'lemon','limon','fruit','fruta','orchard'}) then return 'fruit' end
    if hasAny(direct,{'cash drop','cashdrop','cash vine','cashvine','money drop','drop cash'}) then return 'cash' end
    if hasAny(direct,{'upgrade','button','boton','purchase','comprar','buy button'}) then return 'buy' end
    return nil
end
local function scanWorld()
    local found={fruit={},ice={},cash={},buy={}}
    local scanned=0
    for _,obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA('ProximityPrompt') or obj:IsA('ClickDetector') then
            scanned=scanned+1
            local category=classify(obj)
            if category then
                local part=anchorPart(obj)
                if part then
                    table.insert(found[category],{obj=obj,part=part})
                end
            end
        end
    end
    hits=found
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
onToggle=function(key)
    if key=='radar' then updateHighlights() end
end
local function nearby(bucket)
    local best,bestDist=nil,math.huge
    for _,hit in ipairs(bucket) do
        if hit.obj.Parent and hit.part.Parent and not (bucket==hits.buy and state.needed and hit.part.Transparency>0.85) then
            local d=distance(hit.part)
            if d<bestDist and d<=MAX_RANGE then
                local obj=hit.obj
                local maxDistance=(obj:IsA('ClickDetector') or obj:IsA('ProximityPrompt')) and obj.MaxActivationDistance or MAX_RANGE
                if d<=maxDistance then
                    best,bestDist=hit,d
                end
            end
        end
    end
    return best,bestDist
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
local detectedWorld=0
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
    worldBadge.Text=(detectedWorld==0 and '◌  ' or '●  ')..name
    worldBadge.TextColor3=detectedWorld==0 and COLOR.warning or COLOR.success
    autoButton.Text=autoWorld and 'AUTO: ON' or 'AUTO: OFF'
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
local function refresh()
    scanWorld()
    updateHighlights()
    local f,i,c,u=#hits.fruit,#hits.ice,#hits.cash,#hits.buy
    scanStatus.Text=string.format('Objetivos: limón %d  •  hielo %d\nDrops %d  •  botones %d',f,i,c,u)
    detection.Text=string.format('Interacciones examinadas: %d\nClick API: %s',stats.scanned,type(fireclickdetector)=='function' and 'disponible' or 'no disponible')
    w1Status.Text=string.format('Frutas: %d   |   Drops: %d\nBotones: %d',f,c,u)
    w2Status.Text=string.format('Ice Chunks: %d\nObjetivos cercanos: %s',i,nearby(hits.ice) and 'sí' or 'no')
    footer.Text=string.format('Limón %d  •  Hielo %d  •  Mejoras %d  |  Intentos %d',f,i,u,stats.attempts)
end
local debugBox=section(db,'CONTROL Y ESTADO')
local lastStatus=statusText(debugBox,'Sin intentos',true)
local radarBox=section(db,'VISUAL')
toggle(radarBox,'Resaltar objetivos detectados','radar')
local lastRefresh=0
local function doRefresh()
    refresh()
    lastRefresh=os.clock()
end
action(scanBox,'↻  Escanear objetivos',doRefresh)
action(scanBox,'Probar limón cercano',function()
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
action(debugBox,'Detener funciones',function()
    for k in pairs(state) do state[k]=false end
    for _,draw in pairs(switches) do draw() end
    clearHighlights()
    latestMessage='Todas las funciones detenidas'
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

-- Only attempt supported nearby interactions at a controlled rate.
-- If an entry cannot be identified, there is no action to fire.
local lastDetection=0
task.spawn(function()
    while running and gui.Parent do
        if os.clock()-lastRefresh>9 then doRefresh() end
        if os.clock()-(lastDetection or -1e9)>2.5 then
            lastDetection=os.clock()
            detectWorld()
        end
        for _,rule in ipairs({
            {key='fruit',bucket='fruit'},
            {key='ice',bucket='ice'},
            {key='cash',bucket='cash'},
            {key='buy',bucket='buy'}
        }) do
            local matchesWorld=(detectedWorld==0)
                or (detectedWorld==1 and rule.key~='ice')
                or (detectedWorld==2 and rule.key~='fruit' and rule.key~='cash')
            if state[rule.key] and matchesWorld then
                local h=nearby(hits[rule.bucket])
                if h then
                    local _,msg=attemptInteraction(h)
                    latestMessage=rule.key..': '..msg
                    lastStatus.Text=latestMessage
                end
            end
        end
        footer.Text=string.format('Limón %d  •  Hielo %d  •  Mejoras %d  |  Intentos %d',
            #hits.fruit,#hits.ice,#hits.buy,stats.attempts)
        task.wait(.7)
    end
end)
