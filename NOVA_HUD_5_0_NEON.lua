-- NOVA HUD 5.0 NEON — ice rock reposition, mobile slider and upgrade diagnostics
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
for _,oldName in ipairs({'NOVA_HUD_3_1','NOVA_HUD_3_2','NOVA_HUD_3_3','NOVA_HUD_3_4','NOVA_HUD_3_5','NOVA_HUD_3_6','NOVA_HUD_3_7','NOVA_HUD_3_8','NOVA_HUD_3_9','NOVA_HUD_4_0_NEON','NOVA_HUD_4_1_NEON','NOVA_HUD_4_2_NEON','NOVA_HUD_4_3_NEON','NOVA_HUD_4_4_NEON','NOVA_HUD_4_5_NEON','NOVA_HUD_4_5_1_NEON','NOVA_HUD_4_5_2_NEON','NOVA_HUD_4_5_3_NEON','NOVA_HUD_4_5_4_NEON','NOVA_HUD_4_6_NEON','NOVA_HUD_4_7_NEON','NOVA_HUD_4_8_NEON','NOVA_HUD_4_9_NEON','NOVA_HUD_5_0_NEON'}) do
    local previous=playerGui:FindFirstChild(oldName)
    if previous then previous:Destroy() end
end


local COLOR = {
    bg=Color3.fromRGB(3,9,22),panel=Color3.fromRGB(7,17,36),
    nav=Color3.fromRGB(9,21,43),card=Color3.fromRGB(12,27,51),
    border=Color3.fromRGB(0,127,210),accent=Color3.fromRGB(0,223,255),
    blue=Color3.fromRGB(57,116,255),purple=Color3.fromRGB(156,91,255),
    bright=Color3.fromRGB(238,247,255),muted=Color3.fromRGB(147,176,207),
    success=Color3.fromRGB(0,237,180),warning=Color3.fromRGB(255,191,90),
    danger=Color3.fromRGB(255,89,118)
}
local neonBorders={}
local neonGlow=true
local scalePercent=100 -- 10%-150% relativo al ajuste de pantalla

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
    local stroke=make('UIStroke',{Color=COLOR.border,Thickness=1.15,Transparency=.2},obj)
    table.insert(neonBorders,stroke)
    return stroke
end
local function textLabel(parent,str,size,bold,color)
    return make('TextLabel',{
        Text=str,TextSize=size or 13,TextColor3=color or COLOR.bright,
        Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,
        BackgroundTransparency=1,BorderSizePixel=0,
        TextTruncate=Enum.TextTruncate.None,
    },parent)
end
local function fitText(label,minSize,maxSize)
    label.TextScaled=true
    label.TextTruncate=Enum.TextTruncate.None
    label.TextWrapped=false
    make('UITextSizeConstraint',{
        MinTextSize=minSize or 9,MaxTextSize=maxSize or label.TextSize
    },label)
    return label
end
local function roundedButton(parent,title,background,size)
    local b=make('TextButton',{
        Size=size or UDim2.fromOffset(34,30),BackgroundColor3=background or COLOR.card,
        BorderSizePixel=0,Text=title,TextColor3=COLOR.bright,
        Font=Enum.Font.GothamBold,TextSize=14,AutoButtonColor=false,
        TextTruncate=Enum.TextTruncate.None,TextWrapped=true
    },parent)
    corner(b,7);return b
end

local state={fruit=false,ice=false,cash=false,buy=false,buyMars=false,needed=true,radar=false,iceTeleport=false,buyTeleport=true,cheapFirst=true,iceBatch=true,autoRebirth=false,bulkBuy=false,remoteBuy=false,startOnly=false,autoStations=false}
local running=true
local NOVA_CORE={} -- estado agrupado para reducir registros locales de Luau
NOVA_CORE.MAX_RANGE=14 -- fallback interaction distance, measured in studs
NOVA_CORE.STUDS_PER_METER=1/0.28 -- approximate Roblox unit conversion
NOVA_CORE.iceSearchMeters=350 -- adjustable range in the HUD; server interaction limits still apply
NOVA_CORE.DELAY=1.5
-- Lotes de hielo: interacciones independientes, con intervalos moderados.
NOVA_CORE.ICE_TARGET_DELAY=.85       -- por fragmento, no por lote
NOVA_CORE.ICE_BATCH_LIMIT=6          -- hasta seis objetivos distintos por vuelta
NOVA_CORE.ICE_GROUP_RADIUS=12        -- studs, para identificar la misma roca
NOVA_CORE.ICE_GROUP_COOLDOWN=7       -- segundos antes de repetir roca
NOVA_CORE.ICE_MOVE_INTERVAL=.65
NOVA_CORE.ICE_MIN_DWELL=.75
NOVA_CORE.ICE_MAX_DWELL=1.35
NOVA_CORE.buildMoveDelay=.45
NOVA_CORE.batchSize=5 -- 1..8 solicitudes por ciclo, sólo interfaces que el cliente reconoce
NOVA_CORE.BATCH_INTERACTION_DELAY=.22
NOVA_CORE.lastBatchRun=-1e9
NOVA_CORE.remoteBuyAttempts=0
NOVA_CORE.batchAttempts=0
NOVA_CORE.latestBatchStatus='No se han enviado compras rápidas'
NOVA_CORE.BUILD_RETRY_COOLDOWN=1.05
NOVA_CORE.BUY_SEARCH_STUDS=1800
NOVA_CORE.touchMoveAt=-1e9
NOVA_CORE.buyRoute={active=false,target=nil,world=nil}
NOVA_CORE.buyCooldown={} -- failed physical pads wait before retry
NOVA_CORE.buyFailCounts={} -- prevent getting stuck at the same failed pad
NOVA_CORE.buyAreaOrigin=nil -- reference near player's tycoon
NOVA_CORE.buyAreaWorld=nil
NOVA_CORE.buyWasActive=false
NOVA_CORE.buyRouteAttempts=0
NOVA_CORE.buyRouteVerified=0
NOVA_CORE.buyLastReason='Sin compra iniciada'
NOVA_CORE.zoneStage={[1]=1,[2]=1}
NOVA_CORE.zoneNames={
 [1]={'Lemon Stand','LemonDash','Lemon Depot','Lemon Trading','Lemon Labs','Lemon Robotics','Lemon Republic','LemonX'},
 [2]={'Oxygen Pump','Fast O2','Oxygen Warehouse','Oxygen Center','Oxygen Garden','Oxygen Resort','Oxygen Bars'}
}
NOVA_CORE.zoneStatus='Zona inicial: buscando referencias'
NOVA_CORE.zoneStatusLabels={}
NOVA_CORE.buyPending=nil
NOVA_CORE.startAnchor={}
NOVA_CORE.startRadius=190
NOVA_CORE.startAnchorMethod={}
NOVA_CORE.buyQueueStats={seen=0,area=0,priced=0,affordable=0,station=0}
NOVA_CORE.buyPendingHint=''
NOVA_CORE.lastBuyDecision='Marca el inicio antes de comprar'
local stats={attempts=0, errors=0, scanned=0, notices=0,iceAttempts=0,iceBatches=0,iceRocks=0}
local hits={fruit={},ice={},cash={},buy={}}
local guiUpgrades={} -- regular visible upgrade GUI buttons, not remote events
NOVA_CORE.lastMoveAt=0
NOVA_CORE.lastBuildMoveAt=0
NOVA_CORE.lastIceMoveAt=0
NOVA_CORE.buildHops=0
NOVA_CORE.teleportLog={}
NOVA_CORE.iceRockVisits={} -- zonas recientemente exploradas
NOVA_CORE.teleportsFailed=0
NOVA_CORE.savedPosition=nil
NOVA_CORE.teleportCount=0
NOVA_CORE.detectedWorld=0
NOVA_CORE.lastAttempt={}
NOVA_CORE.highlights={}
NOVA_CORE.switches={} -- key -> array of synchronized render callbacks
NOVA_CORE.onToggle=nil
NOVA_CORE.statusNotice=nil


local gui=make('ScreenGui',{
    Name='NOVA_HUD_5_0_NEON',ResetOnSpawn=false,DisplayOrder=105,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,IgnoreGuiInset=false
},playerGui)
local window=make('Frame',{
    Name='NeonWindow',Size=UDim2.fromOffset(1180,550),
    Position=UDim2.fromScale(.5,.55),AnchorPoint=Vector2.new(.5,.5),
    BackgroundColor3=COLOR.bg,BorderSizePixel=0,Active=true
},gui)
corner(window,15);outline(window)
make('UIGradient',{Rotation=110,Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,COLOR.bg),
    ColorSequenceKeypoint.new(.53,Color3.fromRGB(5,15,34)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(3,10,26))
})},window)
local scale=make('UIScale',{Scale=1},window)
local viewportConnection
local function fitWindow()
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local vp=cam.ViewportSize
    -- Reserve space for Roblox controls at the top and gesture area at the bottom.
    local base=math.max(.05,math.min((vp.X-32)/1180,(vp.Y-158)/550))
    -- 100% se adapta a pantalla; 10% y 150% son relativos a ese tamaño.
    -- No bloquear 10% con una escala mínima artificial.
    scale.Scale=base*(scalePercent/100)
end
local function bindViewport()
    if viewportConnection then viewportConnection:Disconnect() end
    local cam=Workspace.CurrentCamera
    if cam then viewportConnection=cam:GetPropertyChangedSignal('ViewportSize'):Connect(fitWindow) end
    fitWindow()
end
bindViewport()
local cameraChanged=Workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(bindViewport)

local top=make('Frame',{
    Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,0,73),
    BackgroundColor3=COLOR.panel,BorderSizePixel=0,Active=true
},window)
corner(top,15)
make('UIGradient',{Rotation=0,Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(6,20,49)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(4,10,25))
})},top)
make('Frame',{Position=UDim2.new(0,0,1,-2),Size=UDim2.new(1,0,0,2),
    BackgroundColor3=COLOR.accent,BackgroundTransparency=.42,BorderSizePixel=0},top)
do
local logo=make('Frame',{Size=UDim2.fromOffset(52,52),
    Position=UDim2.fromOffset(13,10),BackgroundColor3=Color3.fromRGB(6,38,79),
    BorderSizePixel=0},top)
corner(logo,13)
local ls=outline(logo);ls.Color=COLOR.accent;ls.Thickness=1.8
local logoGlyph=textLabel(logo,'N',35,true,COLOR.accent)
logoGlyph.TextXAlignment=Enum.TextXAlignment.Center
logoGlyph.Size=UDim2.fromScale(1,1)
logoGlyph.TextStrokeColor3=COLOR.blue;logoGlyph.TextStrokeTransparency=.45
local title=textLabel(top,'NOVA',28,true,COLOR.bright)
title.Position=UDim2.fromOffset(78,3);title.Size=UDim2.fromOffset(188,43)
title.TextStrokeColor3=COLOR.blue;title.TextStrokeTransparency=.59
local version=textLabel(top,'v5.0 - SELL LEMONS',12,true,COLOR.muted)
version.Position=UDim2.fromOffset(80,40);version.Size=UDim2.fromOffset(208,23)
end

local badgeBackground=make('Frame',{Position=UDim2.fromOffset(301,15),
    Size=UDim2.fromOffset(156,42),BackgroundColor3=COLOR.nav,
    BorderSizePixel=0},top)
corner(badgeBackground,10)
local bs=outline(badgeBackground);bs.Color=COLOR.accent
local worldBadge=textLabel(badgeBackground,'DETECTANDO...',15,true,COLOR.accent)
worldBadge.Position=UDim2.fromOffset(12,1);worldBadge.Size=UDim2.new(1,-20,1,-2)
fitText(worldBadge,11,15)
local autoButton=roundedButton(top,'VISTA AUTO',COLOR.nav,UDim2.fromOffset(110,33))
autoButton.Position=UDim2.fromOffset(470,19)
autoButton.TextColor3=COLOR.success;autoButton.TextSize=11;outline(autoButton)

do
local userPanel=make('Frame',{Position=UDim2.new(1,-437,0,12),
    Size=UDim2.fromOffset(218,47),BackgroundColor3=COLOR.nav,BorderSizePixel=0},top)
corner(userPanel,9);outline(userPanel)
local userIcon=textLabel(userPanel,'U',22,true,COLOR.purple)
userIcon.Position=UDim2.fromOffset(10,3);userIcon.Size=UDim2.fromOffset(32,41)
local userCaption=textLabel(userPanel,'USUARIO',10,false,COLOR.muted)
userCaption.Position=UDim2.fromOffset(48,4);userCaption.Size=UDim2.new(1,-54,0,18)
local userName=textLabel(userPanel,player.DisplayName or player.Name,13,true,COLOR.bright)
userName.Position=UDim2.fromOffset(48,21);userName.Size=UDim2.new(1,-54,0,21)
fitText(userName,10,13)
end

local timePanel=make('Frame',{Position=UDim2.new(1,-211,0,12),
    Size=UDim2.fromOffset(113,47),BackgroundColor3=COLOR.nav,BorderSizePixel=0},top)
corner(timePanel,9);outline(timePanel)
local timeCaption=textLabel(timePanel,'ACTIVO',10,false,COLOR.muted)
timeCaption.Position=UDim2.fromOffset(12,3);timeCaption.Size=UDim2.new(1,-24,0,17)
local timeValue=textLabel(timePanel,'00:00',16,true,COLOR.bright)
timeValue.Position=UDim2.fromOffset(12,21);timeValue.Size=UDim2.new(1,-24,0,21)
local startTime=os.clock()

local min=roundedButton(top,'−',COLOR.nav,UDim2.fromOffset(37,36))
min.Position=UDim2.new(1,-88,0,18);outline(min)
local close=roundedButton(top,'×',Color3.fromRGB(51,12,33),UDim2.fromOffset(37,36))
close.Position=UDim2.new(1,-46,0,18);close.TextColor3=COLOR.danger
local closeStroke=outline(close);closeStroke.Color=COLOR.danger
-- Floating minimized icon: square with a large, legible N.
local restore=roundedButton(gui,'N',COLOR.nav,UDim2.fromOffset(62,62))
restore.Position=UDim2.fromOffset(22,145)
restore.TextColor3=COLOR.accent
restore.TextSize=39
restore.TextStrokeColor3=COLOR.blue
restore.TextStrokeTransparency=.55
restore.TextWrapped=false
restore.ZIndex=50
restore.Active=true
restore.Visible=true -- botón N siempre disponible
local restoreCorner=restore:FindFirstChildOfClass('UICorner')
if restoreCorner then restoreCorner.CornerRadius=UDim.new(0,13) end
local restoreStroke=outline(restore)
restoreStroke.Color=COLOR.accent
restoreStroke.Thickness=1.8
make('UIGradient',{Rotation=70,Color=ColorSequence.new(
    Color3.fromRGB(15,46,88),Color3.fromRGB(5,14,31))},restore)

local sidebar=make('Frame',{Position=UDim2.fromOffset(0,74),
    Size=UDim2.new(0,173,1,-107),BackgroundColor3=COLOR.panel,BorderSizePixel=0},window)
make('UIGradient',{Rotation=90,Color=ColorSequence.new(COLOR.panel,COLOR.bg)},sidebar)
local sideMenu=make('Frame',{Position=UDim2.fromOffset(0,7),
    Size=UDim2.new(1,0,1,-89),BackgroundTransparency=1},sidebar)
make('UIListLayout',{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder},sideMenu)
make('UIPadding',{PaddingTop=UDim.new(0,7),PaddingLeft=UDim.new(0,10),
    PaddingRight=UDim.new(0,10)},sideMenu)
do
local sideBrand=make('Frame',{Position=UDim2.new(0,10,1,-70),
    Size=UDim2.new(1,-20,0,65),BackgroundColor3=COLOR.nav,BorderSizePixel=0},sidebar)
corner(sideBrand,10);outline(sideBrand)
local brandLogo=textLabel(sideBrand,'N',25,true,COLOR.accent)
brandLogo.Position=UDim2.fromOffset(13,8);brandLogo.Size=UDim2.fromOffset(31,48)
local brandTitle=textLabel(sideBrand,'NOVA HUD',11,true,COLOR.accent)
brandTitle.Position=UDim2.fromOffset(48,9);brandTitle.Size=UDim2.new(1,-51,0,22)
fitText(brandTitle,9,11)
local brandSub=textLabel(sideBrand,'Interfaz Neon',10,false,COLOR.muted)
brandSub.Position=UDim2.fromOffset(48,29);brandSub.Size=UDim2.new(1,-50,0,20)
fitText(brandSub,8,10)
end

local content=make('Frame',{Position=UDim2.fromOffset(184,87),
    Size=UDim2.new(1,-195,1,-125),BackgroundTransparency=1},window)

local bottom=make('Frame',{Position=UDim2.new(0,0,1,-33),
    Size=UDim2.new(1,0,0,33),BackgroundColor3=COLOR.panel,BorderSizePixel=0},window)
make('Frame',{Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,0,1),
    BackgroundColor3=COLOR.border,BackgroundTransparency=.36,BorderSizePixel=0},bottom)
do
local onlineDot=make('Frame',{Position=UDim2.fromOffset(23,13),Size=UDim2.fromOffset(9,9),
    BackgroundColor3=COLOR.success,BorderSizePixel=0},bottom)
corner(onlineDot,9)
local online=textLabel(bottom,'SISTEMA ACTIVO',10,false,COLOR.muted)
online.Position=UDim2.fromOffset(39,6);online.Size=UDim2.fromOffset(154,21)
fitText(online,9,10)
local bottomBrand=textLabel(bottom,'NOVA v5.0 NEON • SELL LEMONS',11,true,COLOR.accent)
bottomBrand.TextXAlignment=Enum.TextXAlignment.Center
bottomBrand.Position=UDim2.new(.30,0,0,6);bottomBrand.Size=UDim2.new(.41,0,0,21)
fitText(bottomBrand,10,11)
end
local footer=textLabel(bottom,'Iniciando...',10,false,COLOR.muted)
footer.TextXAlignment=Enum.TextXAlignment.Right
footer.Position=UDim2.new(.72,0,0,6)
footer.Size=UDim2.new(.27,-12,0,21)
fitText(footer,9,10)


local pages,navButtons,navVisuals={}, {}, {}
local autoWorld=true
local selectedPage='World1'
local function showPage(key)
    if not pages[key] then return end
    selectedPage=key
    for name,page in pairs(pages) do page.Visible=(name==key) end
    for name,button in pairs(navButtons) do
        local active=(name==key)
        TweenService:Create(button,TweenInfo.new(.22,Enum.EasingStyle.Quad),{
            BackgroundColor3=active and Color3.fromRGB(16,61,134) or COLOR.nav
        }):Play()
        local v=navVisuals[name]
        if v then
            v.bar.Visible=active
            TweenService:Create(v.text,TweenInfo.new(.22),{TextColor3=active and COLOR.accent or COLOR.bright}):Play()
            TweenService:Create(v.icon,TweenInfo.new(.22),{TextColor3=active and COLOR.accent or COLOR.muted}):Play()
            v.stroke.Transparency=active and .13 or .86
        end
    end
end
local function addPage(key,labelText,emoji)
    local p=make('Frame',{Name=key,Size=UDim2.fromScale(1,1),
        Visible=false,BackgroundTransparency=1},content)
    pages[key]=p
    local b=roundedButton(sideMenu,'',COLOR.nav,UDim2.new(1,0,0,50))
    b.LayoutOrder=({World1=1,World2=2,Build=3,Tools=4,Visual=5,Config=6})[key] or 7
    local stroke=outline(b);stroke.Transparency=.86
    local bar=make('Frame',{Position=UDim2.fromOffset(0,8),Size=UDim2.fromOffset(3,34),
        BackgroundColor3=COLOR.accent,BorderSizePixel=0,Visible=false},b)
    corner(bar,3)
    local ico=textLabel(b,emoji,19,true,COLOR.muted)
    ico.Position=UDim2.fromOffset(10,2);ico.Size=UDim2.fromOffset(27,46)
    ico.TextXAlignment=Enum.TextXAlignment.Center
    local name=textLabel(b,labelText,13,true,COLOR.bright)
    name.Position=UDim2.fromOffset(44,0);name.Size=UDim2.new(1,-47,1,0)
    name.TextTruncate=Enum.TextTruncate.None
    fitText(name,11,13)
    navButtons[key]=b
    navVisuals[key]={bar=bar,icon=ico,text=name,stroke=stroke}
    b.MouseButton1Click:Connect(function()
        if key~='World1' and key~='World2' then
            autoWorld=false
        elseif key=='World1' or key=='World2' then
            autoWorld=false
        end
        autoButton.Text='VISTA MANUAL'
        autoButton.TextColor3=COLOR.warning
        showPage(key)
    end)
    return p
end
local p1=addPage('World1','Mundo 1','1')
local p2=addPage('World2','Marte','2')
local pBuild=addPage('Build','Build','B')
local pd=addPage('Tools','Scanner','S')
local pVisual=addPage('Visual','Visual','V')
local pConfig=addPage('Config','Config','C')


local dashboardStatLabels={}
local dashboardScanButtons={}
local dashboardScanMeta={}
local requestScan=nil
local function columns(page)
    local isDashboard=(page==p1 or page==p2)
    local holder=make('Frame',{Size=UDim2.fromScale(1,1),BackgroundTransparency=1},page)
    if isDashboard then
        local topGrid=make('Frame',{Size=UDim2.new(1,0,1,-123),BackgroundTransparency=1},holder)
        local col={}
        for i=1,3 do
            local x=(i-1)*.337
            local c=make('ScrollingFrame',{
                Position=UDim2.new(x,0,0,0),
                Size=UDim2.new(.326,0,1,0),BackgroundTransparency=1,
                BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=COLOR.accent,
                CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,
                ScrollingDirection=Enum.ScrollingDirection.Y
            },topGrid)
            make('UIListLayout',{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},c)
            make('UIPadding',{PaddingLeft=UDim.new(0,2),PaddingRight=UDim.new(0,4),
                PaddingBottom=UDim.new(0,5)},c)
            col[i]=c
        end
        local lower=make('Frame',{Position=UDim2.new(0,0,1,-116),
            Size=UDim2.new(1,0,0,116),BackgroundTransparency=1},holder)
        local scanCard=make('Frame',{Position=UDim2.fromScale(0,0),
            Size=UDim2.new(.49,0,1,0),BackgroundColor3=COLOR.panel,BorderSizePixel=0},lower)
        corner(scanCard,12);outline(scanCard)
        local scanTitle=textLabel(scanCard,'SCANNER RÁPIDO',15,true,COLOR.accent)
        scanTitle.Position=UDim2.fromOffset(14,8);scanTitle.Size=UDim2.new(1,-26,0,24)
fitText(scanTitle,12,15)
        local scanButton=roundedButton(scanCard,'ESCANEAR TODO',Color3.fromRGB(12,48,107),
            UDim2.new(.50,-18,0,40))
        scanButton.Position=UDim2.fromOffset(14,60)
        scanButton.TextColor3=COLOR.bright;scanButton.TextSize=13
        local scanStroke=outline(scanButton);scanStroke.Color=COLOR.accent
        scanButton.MouseButton1Click:Connect(function()
            if requestScan then requestScan() end
        end)
        dashboardScanButtons[page]=scanButton
        local scanMeta=textLabel(scanCard,'Rocas —   •  Mejoras —\nObjetos —   •  Intentos —',12,false,COLOR.muted)
        scanMeta.Position=UDim2.new(.53,0,0,45)
        scanMeta.Size=UDim2.new(.46,-12,0,64)
        scanMeta.TextWrapped=true
        scanMeta.TextTruncate=Enum.TextTruncate.None
        dashboardScanMeta[page]=scanMeta

        local statPanel=make('Frame',{Position=UDim2.new(.505,0,0,0),
            Size=UDim2.new(.495,0,1,0),BackgroundColor3=COLOR.panel,BorderSizePixel=0},lower)
        corner(statPanel,12);outline(statPanel)
        local statTitle=textLabel(statPanel,'SISTEMA / STATS',15,true,COLOR.accent)
        statTitle.Position=UDim2.fromOffset(12,7);statTitle.Size=UDim2.new(1,-24,0,24)
fitText(statTitle,12,15)
        dashboardStatLabels[page]={}
        for i,info in ipairs({
            {'HIELO',COLOR.accent}, {'MEJORAS',COLOR.success},
            {'SALTOS',COLOR.purple}, {'INTENTOS',COLOR.warning}
        }) do
            local tile=make('Frame',{Position=UDim2.new((i-1)*.247+0.012,0,0,37),
                Size=UDim2.new(.233,-3,0,69),BackgroundColor3=COLOR.card,BorderSizePixel=0},statPanel)
            corner(tile,8)
            local small=textLabel(tile,info[1],10,false,COLOR.muted)
            small.TextXAlignment=Enum.TextXAlignment.Center
            small.Size=UDim2.new(1,0,0,24)
            fitText(small,9,10)
            local val=textLabel(tile,'—',19,true,info[2])
            val.TextXAlignment=Enum.TextXAlignment.Center
            val.Position=UDim2.fromOffset(0,25);val.Size=UDim2.new(1,0,0,33)
            dashboardStatLabels[page][i]=val
        end
        return col[1],col[2],col[3]
    end
    local left=make('ScrollingFrame',{
        Position=UDim2.fromScale(0,0),Size=UDim2.new(.49,0,1,0),
        ScrollBarThickness=3,ScrollBarImageColor3=COLOR.accent,
        AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),
        ScrollingDirection=Enum.ScrollingDirection.Y,
        BorderSizePixel=0,BackgroundTransparency=1
    },holder)
    local right=make('ScrollingFrame',{
        Position=UDim2.new(.51,0,0,0),Size=UDim2.new(.49,0,1,0),
        ScrollBarThickness=3,ScrollBarImageColor3=COLOR.accent,
        AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),
        ScrollingDirection=Enum.ScrollingDirection.Y,
        BorderSizePixel=0,BackgroundTransparency=1
    },holder)
    for _,v in ipairs({left,right}) do
        make('UIListLayout',{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder},v)
        make('UIPadding',{PaddingLeft=UDim.new(0,3),PaddingRight=UDim.new(0,5),
            PaddingBottom=UDim.new(0,7)},v)
    end
    return left,right
end


local function section(parent,name)
    local holder=make('Frame',{Size=UDim2.new(1,-3,0,0),AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1},parent)
    make('UIListLayout',{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},holder)
    local heading=textLabel(holder,name,14,true,COLOR.accent)
    heading.Size=UDim2.new(1,0,0,26)
    heading.TextWrapped=false
    fitText(heading,11,14)
    local card=make('Frame',{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundColor3=COLOR.panel,BorderSizePixel=0},holder)
    corner(card,11);outline(card)
    make('UIGradient',{Rotation=95,Color=ColorSequence.new(
        Color3.fromRGB(9,23,47),Color3.fromRGB(5,15,33))},card)
    make('UIListLayout',{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder},card)
    make('UIPadding',{PaddingTop=UDim.new(0,8),PaddingBottom=UDim.new(0,8),
        PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)},card)
    return card
end

local function statusText(parent,str,dim)
    local h=textLabel(parent,str,dim and 12 or 13,false,dim and COLOR.muted or COLOR.bright)
    h.Size=UDim2.new(1,-4,0,34)
    h.AutomaticSize=Enum.AutomaticSize.Y
    h.TextWrapped=true
    h.TextTruncate=Enum.TextTruncate.None
    h.TextYAlignment=Enum.TextYAlignment.Top
    return h
end

local function toggle(parent,titleText,key)
    local row=make('TextButton',{Text='',Size=UDim2.new(1,0,0,42),
        BackgroundTransparency=1,BorderSizePixel=0,AutoButtonColor=false},parent)
    local txt=textLabel(row,titleText,12,false,COLOR.bright)
    txt.Position=UDim2.fromOffset(3,0)
    txt.Size=UDim2.new(1,-70,1,0)
    txt.TextWrapped=true;txt.TextTruncate=Enum.TextTruncate.None
    local pill=make('Frame',{Position=UDim2.new(1,-55,.5,-11),
        Size=UDim2.fromOffset(50,22),BackgroundColor3=COLOR.border,BorderSizePixel=0},row)
    corner(pill,11)
    local dot=make('Frame',{Size=UDim2.fromOffset(16,16),
        Position=UDim2.fromOffset(3,3),BackgroundColor3=COLOR.bright,BorderSizePixel=0},pill)
    corner(dot,9)
    local glow=make('UIStroke',{Color=COLOR.accent,Thickness=1.1,Transparency=.9},pill)
    make('Frame',{Position=UDim2.new(0,4,1,-1),Size=UDim2.new(1,-8,0,1),
        BackgroundColor3=COLOR.border,BackgroundTransparency=.84,BorderSizePixel=0},row)
    local function render()
        TweenService:Create(pill,TweenInfo.new(.17,Enum.EasingStyle.Quad),{
            BackgroundColor3=state[key] and Color3.fromRGB(0,104,110) or Color3.fromRGB(36,49,76)}):Play()
        TweenService:Create(dot,TweenInfo.new(.17,Enum.EasingStyle.Quad),{
            Position=UDim2.fromOffset(state[key] and 31 or 3,3),
            BackgroundColor3=state[key] and COLOR.success or COLOR.bright}):Play()
        glow.Transparency=(state[key] and neonGlow) and .22 or .93
    end
    if not NOVA_CORE.switches[key] then NOVA_CORE.switches[key]={} end
    table.insert(NOVA_CORE.switches[key],render);render()
    row.MouseButton1Click:Connect(function()
        local targetClass=({fruit='fruit',cash='cash',ice='ice',buy='buy',buyMars='buy'})[key]
        if not state[key] and targetClass and #hits[targetClass]==0
            and not (targetClass=='buy' and #guiUpgrades>0) then
            if NOVA_CORE.onToggle then NOVA_CORE.onToggle(key,'no-target') end
        end
        state[key]=not state[key]
        for _,draw in ipairs(NOVA_CORE.switches[key]) do draw() end
        if NOVA_CORE.onToggle then NOVA_CORE.onToggle(key) end
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
    local frame=make('Frame',{Size=UDim2.new(1,0,0,84),BackgroundTransparency=1},parent)
    local label=textLabel(frame,'ALCANCE DEL HIELO',11,true,COLOR.muted)
    label.Position=UDim2.fromOffset(6,0)
    label.Size=UDim2.new(1,-95,0,28)
    fitText(label,10,11)
    local value=textLabel(frame,'350 m',12,true,COLOR.accent)
    value.TextXAlignment=Enum.TextXAlignment.Right
    value.Position=UDim2.new(1,-88,0,0)
    value.Size=UDim2.fromOffset(82,28)
    fitText(value,10,12)
    local track=make('TextButton',{Text='',AutoButtonColor=false,
        Position=UDim2.fromOffset(13,42),Size=UDim2.new(1,-26,0,10),
        BackgroundColor3=COLOR.border,BorderSizePixel=0},frame)
    corner(track,6)
    local fill=make('Frame',{Size=UDim2.fromScale(0,1),BackgroundColor3=COLOR.accent,BorderSizePixel=0},track)
    corner(fill,6)
    local knob=make('Frame',{Size=UDim2.fromOffset(20,20),AnchorPoint=Vector2.new(.5,.5),
        Position=UDim2.fromScale(0,.5),BackgroundColor3=COLOR.bright,BorderSizePixel=0},track)
    corner(knob,10)
    local left=textLabel(frame,'20 m',11,false,COLOR.muted)
    left.Position=UDim2.fromOffset(11,61);left.Size=UDim2.fromOffset(60,20)
    local right=textLabel(frame,'1500 m',11,false,COLOR.muted)
    right.TextXAlignment=Enum.TextXAlignment.Right
    right.Position=UDim2.new(1,-106,0,61);right.Size=UDim2.fromOffset(95,20)
    local function paint()
        local t=(NOVA_CORE.iceSearchMeters-20)/1480
        fill.Size=UDim2.fromScale(t,1)
        knob.Position=UDim2.fromScale(t,.5)
        value.Text=string.format('%d m',NOVA_CORE.iceSearchMeters)
    end
    local function setFromX(x)
        local t=math.clamp((x-track.AbsolutePosition.X)/math.max(1,track.AbsoluteSize.X),0,1)
        NOVA_CORE.iceSearchMeters=math.clamp(math.floor((20+t*1480)/10+.5)*10,20,1500)
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
    local caption=textLabel(panel,'VELOCIDAD DE PROGRESO',11,true,COLOR.muted)
    caption.Position=UDim2.fromOffset(6,0)
    caption.Size=UDim2.new(1,-78,0,28)
    fitText(caption,10,11)
    local value=textLabel(panel,'1.0 s',12,true,COLOR.accent)
    value.Position=UDim2.new(1,-73,0,0)
    value.Size=UDim2.fromOffset(67,28)
    fitText(value,10,12)
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
    local low=textLabel(panel,'RÁPIDO',10,false,COLOR.muted)
    low.Position=UDim2.fromOffset(8,59);low.Size=UDim2.fromOffset(100,20)
    local high=textLabel(panel,'SUAVE',10,false,COLOR.muted)
    high.Position=UDim2.new(1,-115,0,59);high.Size=UDim2.fromOffset(105,20)
    high.TextXAlignment=Enum.TextXAlignment.Right
    local function paint()
        local t=(NOVA_CORE.buildMoveDelay-.35)/1.65
        fill.Size=UDim2.fromScale(t,1);knob.Position=UDim2.fromScale(t,.5)
        for _,v in ipairs(speedViews) do
            if v and v.Parent then v.Text=string.format('%.1f s',NOVA_CORE.buildMoveDelay) end
        end
    end
    local dragging=false
    local function update(x)
        local t=math.clamp((x-rail.AbsolutePosition.X)/math.max(rail.AbsoluteSize.X,1),0,1)
        NOVA_CORE.buildMoveDelay=math.floor((.35+1.65*t)*20+.5)/20
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

local w1Status,w2Status
local budgetLabels={} -- estado compacto en dos mundos
local buildActionButtons={} -- botones principales, sincronizados con NOVA_CORE.switches
local startAnchorLabels={}
local buildBatchStatusLabels={}
buildBatchStatusLabels.purchasePathLabels={}
buildBatchStatusLabels.activePurchasePath=''
local remoteBuyCaption=nil -- botón oficial visible en el juego, si existe
local investorLabels={}
local investorStatus='Inversores: abre el menú de Joe para consultar la oferta.'
local investorProbe=nil
local INVESTOR_REQUIRED_MULTIPLE=10 -- regla solicitada por el jugador
local rebirthLastAction=-1e9
local rebirthStage=0
local rebirthStageDeadline=0
local lastInvestorRefresh=-1e9
local investorSnapshot=nil

do
local a,b,worldOneInfo=columns(p1)
local cBuild=section(a,'AUTO MEJORAS')
local quickBuyEarth=roundedButton(cBuild,'AUTO PROGRESO: OFF',COLOR.nav,UDim2.new(1,0,0,44))
quickBuyEarth.TextColor3=COLOR.accent;outline(quickBuyEarth)
table.insert(buildActionButtons,{button=quickBuyEarth,world=1})
statusText(cBuild,'Un botón activa compra + TP + mejoras de puestos. Sigue los negocios por zonas.',true)
addBuildSpeed(cBuild)
table.insert(NOVA_CORE.zoneStatusLabels,statusText(cBuild,'Zona 1: Lemon Stand',true))
table.insert(budgetLabels,statusText(cBuild,'Saldo: sin leer | 0 pagables',true))
table.insert(startAnchorLabels,statusText(cBuild,'Marca el inicio en la pestaña Build.',true))
table.insert(buildBatchStatusLabels.purchasePathLabels,statusText(cBuild,'MÉTODO: verificando opciones...',true))
local cProgress=section(a,'INVERSORES / RENACIMIENTO')
toggle(cProgress,'Auto renacimiento x10','autoRebirth')
table.insert(investorLabels,statusText(cProgress,
    'Abre el menú de inversores (Joe) para comprobar los valores.',true))
statusText(cProgress,
    'Desactivado inicialmente. Requiere inversores actuales y ganancia legibles. Puede reiniciar tu dinero y tus mejoras.',true)
local cCollect=section(b,'AUTO COLLECT')
toggle(cCollect,'Recoger fruta cercana','fruit')
toggle(cCollect,'Recoger dinero cercano','cash')
statusText(cCollect,'Si no hay objetivos, el interruptor no se activará.',true)
local cAbout=section(worldOneInfo,'ESTADO MUNDO 1')
w1Status=statusText(cAbout,'Buscando objetivos...',false)
end

do
local la,lb,marsInfo=columns(p2)
local iceBox=section(la,'AUTO COLLECT')
toggle(iceBox,'Recoger hielo cercano','ice')
toggle(iceBox,'Recoger varios hielos por roca','iceBatch')
distanceSlider(iceBox)
toggle(iceBox,'Ir directamente a rocas lejanas','iceTeleport')
statusText(iceBox,'Recoge hielo cercano. Puedes desplazarte entre rocas.',true)
local upgradeBox=section(lb,'AUTO MEJORAS')
local quickBuyMars=roundedButton(upgradeBox,'AUTO PROGRESO: OFF',COLOR.nav,UDim2.new(1,0,0,44))
quickBuyMars.TextColor3=COLOR.accent;outline(quickBuyMars)
table.insert(buildActionButtons,{button=quickBuyMars,world=2})
statusText(upgradeBox,'Un botón activa compra + TP + mejoras de puestos. Avanza negocio por negocio.',true)
addBuildSpeed(upgradeBox)
table.insert(NOVA_CORE.zoneStatusLabels,statusText(upgradeBox,'Zona 1: Oxygen Pump',true))
table.insert(budgetLabels,statusText(upgradeBox,'Saldo: sin leer | 0 pagables',true))
table.insert(startAnchorLabels,statusText(upgradeBox,'Marca el inicio en la pestaña Build.',true))
table.insert(buildBatchStatusLabels.purchasePathLabels,statusText(upgradeBox,'MÉTODO: verificando opciones...',true))

-- Composición decorativa: cristales neon dibujados con instancias de UI, sin recursos externos.
local art=make('Frame',{Size=UDim2.new(1,-3,0,112),BackgroundColor3=Color3.fromRGB(16,37,73),
    BorderSizePixel=0,ClipsDescendants=true},marsInfo)
corner(art,11);outline(art)
make('UIGradient',{Rotation=30,Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(39,19,69)),
    ColorSequenceKeypoint.new(.5,Color3.fromRGB(10,37,85)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(4,14,35))
})},art)
for i=1,9 do
    local x=((i*47)%250)/310
    local height=20+(i*19)%66
    local crystal=make('Frame',{
        Position=UDim2.new(x,0,1,-4),
        Size=UDim2.fromOffset(10+(i%3)*4,height),
        AnchorPoint=Vector2.new(.5,1),
        Rotation=28+(i%2)*25,BackgroundColor3=(i%3==0) and COLOR.blue or COLOR.accent,
        BackgroundTransparency=.20,BorderSizePixel=0
    },art)
    local st=outline(crystal);st.Color=COLOR.accent;st.Transparency=.32
    make('UIGradient',{Rotation=0,Color=ColorSequence.new(
        Color3.fromRGB(128,235,255),Color3.fromRGB(2,63,143))},crystal)
end
local artName=textLabel(art,'MARTE  /  ICE WORLD',12,true,COLOR.bright)
artName.Position=UDim2.new(0,10,1,-28);artName.Size=UDim2.new(1,-20,0,24)
local iceStats=section(marsInfo,'ESTADO MARTE')
w2Status=statusText(iceStats,'Buscando objetivos...',false)
local scopeBox=section(marsInfo,'LÍMITES')
statusText(scopeBox,'El servidor decide qué compras y movimientos acepta.',true)
end

-- El menú BUILD permite acceder rápidamente a los controles reales del mundo.
local resetUiScale=nil

do
local buildL,buildR=columns(pBuild)
local buildIntro=section(buildL,'AUTO MEJORAS / BUILD')
statusText(buildIntro,'AUTO PROGRESO incluye TP y mejoras de puestos. El botón único está en el mundo correspondiente.',true)
local buildWorld1=roundedButton(buildIntro,'🍋  AUTO PROGRESO TIERRA',COLOR.card,UDim2.new(1,0,0,46))
buildWorld1.TextColor3=COLOR.accent;outline(buildWorld1)
buildWorld1.MouseButton1Click:Connect(function() showPage('World1') end)
local buildWorld2=roundedButton(buildIntro,'◈  AUTO PROGRESO MARTE',COLOR.card,UDim2.new(1,0,0,46))
buildWorld2.TextColor3=COLOR.accent;outline(buildWorld2)
buildWorld2.MouseButton1Click:Connect(function() showPage('World2') end)
local buildFastPanel=section(buildL,'COMPRA POR PRECIO')
statusText(buildFastPanel,'Zona 1, Zona 2, Zona 3... Elige la mejora más barata dentro de la zona activa.',true)
statusText(buildFastPanel,'AUTO PROGRESO activa Comprar + TP + Mejoras de puestos desde un único botón.',true)
local startPanel=section(buildL,'PUNTO DE INICIO')
local anchorStatus=statusText(startPanel,'Buscando zona inicial automáticamente…',true)
table.insert(startAnchorLabels,anchorStatus)
local markStart=roundedButton(startPanel,'MARCAR INICIO AQUÍ',COLOR.nav,UDim2.new(1,0,0,44))
markStart.TextColor3=COLOR.accent;outline(markStart)
markStart.MouseButton1Click:Connect(function()
    local char=player.Character
    local root=char and char:FindFirstChild('HumanoidRootPart')
    if not root or (NOVA_CORE.detectedWorld~=1 and NOVA_CORE.detectedWorld~=2) then
        anchorStatus.Text='No se pudo leer el personaje o mundo actual.'
        return
    end
    local world=NOVA_CORE.detectedWorld
    NOVA_CORE.startAnchor[world]=root.Position
    NOVA_CORE.buyCooldown={}
    NOVA_CORE.buyAreaOrigin=root.Position
    NOVA_CORE.buyAreaWorld=world
    local msg='Inicio manual en Mundo '..world..' (radio '..NOVA_CORE.startRadius..' studs).'
    NOVA_CORE.startAnchorMethod[world]='manual'
    for _,label in ipairs(startAnchorLabels) do
        if label and label.Parent then label.Text=msg end
    end
end)
local buildTips=section(buildR,'ESTADO DE COMPRAS')
local buildGuide=statusText(buildTips,'Abre un mundo para activar Auto Mejoras. Los intentos no son compras confirmadas.',true)
local batchStatusView=statusText(buildTips,'Compras: sin intentos todavía',true)
table.insert(buildBatchStatusLabels,batchStatusView)
remoteBuyCaption=statusText(buildTips,'Compra secuencial por TP (sin Remote Buy).',true)
table.insert(budgetLabels,statusText(buildTips,'Saldo: esperando lectura',true))

local visualL,visualR=columns(pVisual)
local visualCard=section(visualL,'NEON APPEARANCE')
local visualText=statusText(visualCard,'Ajustes visuales del HUD. No afectan el mundo del juego.',true)
local glowToggle=roundedButton(visualCard,'✦  BRILLO NEÓN: ON',COLOR.card,UDim2.new(1,0,0,44))
outline(glowToggle)
glowToggle.TextColor3=COLOR.accent
glowToggle.MouseButton1Click:Connect(function()
    neonGlow=not neonGlow
    glowToggle.Text=neonGlow and '✦  BRILLO NEÓN: ON' or '✦  BRILLO NEÓN: OFF'
    for _,stroke in ipairs(neonBorders) do
        if stroke.Parent then
            TweenService:Create(stroke,TweenInfo.new(.25),{
                Transparency=neonGlow and .2 or .85}):Play()
        end
    end
    for _,draws in pairs(NOVA_CORE.switches) do
        for _,draw in ipairs(draws) do draw() end
    end
end)
local visualScale=section(visualL,'ESCALA DEL HUD')
local scaleCaption=statusText(visualScale,'Escala seleccionada: 100%',true)
scaleCaption.Size=UDim2.new(1,0,0,34)
local scaleValue=textLabel(visualScale,'100%',23,true,COLOR.accent)
scaleValue.Size=UDim2.new(1,0,0,32)
scaleValue.TextXAlignment=Enum.TextXAlignment.Center

local scaleTrack=make('Frame',{
    Size=UDim2.new(1,-24,0,12),BackgroundColor3=COLOR.card,
    BorderSizePixel=0,Active=true
},visualScale)
corner(scaleTrack,7)
local scaleFill=make('Frame',{Size=UDim2.fromScale(0,1),
    BackgroundColor3=COLOR.accent,BorderSizePixel=0},scaleTrack)
corner(scaleFill,7)
local scaleKnob=make('Frame',{Size=UDim2.fromOffset(20,20),
    AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(0,.5),
    BackgroundColor3=COLOR.bright,BorderSizePixel=0},scaleTrack)
corner(scaleKnob,10)

local limits=make('Frame',{Size=UDim2.new(1,0,0,24),BackgroundTransparency=1},visualScale)
local low=textLabel(limits,'10%',12,true,COLOR.muted)
low.Size=UDim2.new(.5,0,1,0)
local high=textLabel(limits,'150%',12,true,COLOR.muted)
high.Position=UDim2.fromScale(.5,0);high.Size=UDim2.new(.5,0,1,0)
high.TextXAlignment=Enum.TextXAlignment.Right

local controls=make('Frame',{Size=UDim2.new(1,0,0,46),BackgroundTransparency=1},visualScale)
local decrease=roundedButton(controls,'−',COLOR.card,UDim2.new(.18,0,1,0))
decrease.TextSize=23;outline(decrease)
local increase=roundedButton(controls,'+',COLOR.card,UDim2.new(.18,0,1,0))
increase.Position=UDim2.new(.82,0,0,0)
increase.TextSize=23;outline(increase)
local percentage=make('TextBox',{
    Name='PorcentajeExacto',
    Position=UDim2.new(.22,0,0,0),
    Size=UDim2.new(.56,0,1,0),
    BackgroundColor3=COLOR.nav,BorderSizePixel=0,
    Font=Enum.Font.GothamBold,Text='100',
    TextColor3=COLOR.bright,TextSize=17,
    TextXAlignment=Enum.TextXAlignment.Center,
    PlaceholderText='10 a 150',
    PlaceholderColor3=COLOR.muted,
    ClearTextOnFocus=false,
    MultiLine=false
},controls)
corner(percentage,8);outline(percentage)
local help=statusText(visualScale,
    'Toca la barra o escribe un número. Doble toque en N para volver al 100%.',true)
help.Size=UDim2.new(1,0,0,55)

local function applyScalePercent(value)
    local n=tonumber(value)
    if not n or n~=n then n=scalePercent end
    scalePercent=math.clamp(math.floor(n+.5),10,150)
    local fraction=(scalePercent-10)/140
    scaleCaption.Text='Escala seleccionada: '..scalePercent..'%'
    scaleValue.Text=tostring(scalePercent)..'%'
    scaleFill.Size=UDim2.fromScale(fraction,1)
    scaleKnob.Position=UDim2.fromScale(fraction,.5)
    percentage.Text=tostring(scalePercent)
    fitWindow()
end
resetUiScale=function() applyScalePercent(100) end
decrease.MouseButton1Click:Connect(function() applyScalePercent(scalePercent-5) end)
increase.MouseButton1Click:Connect(function() applyScalePercent(scalePercent+5) end)
percentage.FocusLost:Connect(function()
    local typed=percentage.Text:gsub('%%',''):gsub('%s+','')
    applyScalePercent(typed)
end)

-- Guardar posición inicial del carril durante el arrastre evita que se
-- desplace al escalar en tiempo real.
local isDragging=false
local finger=nil
local dragX,dragWidth=0,1
local function updateFromX(x)
    local fraction=math.clamp((x-dragX)/dragWidth,0,1)
    applyScalePercent(10+fraction*140)
end
scaleTrack.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1
        or input.UserInputType==Enum.UserInputType.Touch then
        isDragging=true
        finger=input.UserInputType==Enum.UserInputType.Touch and input or nil
        dragX=scaleTrack.AbsolutePosition.X
        dragWidth=math.max(1,scaleTrack.AbsoluteSize.X)
        updateFromX(input.Position.X)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if not isDragging then return end
    if input.UserInputType==Enum.UserInputType.MouseMovement
        or (finger and input==finger) then updateFromX(input.Position.X) end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1
        or (finger and input==finger) then
        isDragging=false
        finger=nil
    end
end)
applyScalePercent(100)
local preview=section(visualR,'NOVA NEON v5.0')
statusText(preview,'Carbono oscuro • contornos cian • acentos azules y violetas • controles suaves.',true)
local configL,configR=columns(pConfig)
local configCard=section(configL,'CONFIGURACIÓN')
statusText(configCard,'En Visual puedes elegir desde 10% hasta 150%. La N queda siempre visible.',true)
local resetView=roundedButton(configCard,'RESTABLECER ESCALA',COLOR.card,UDim2.new(1,0,0,42))
outline(resetView)
resetView.MouseButton1Click:Connect(function()
    if resetUiScale then resetUiScale() end
end)
local configInfo=section(configR,'INFORMACIÓN')
statusText(configInfo,'NOVA v5.0 NEON\nInterfaz optimizada para móvil.\nLas estadísticas registran intentos, no recompensas confirmadas.',true)
end

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
-- Compare suffix ranks instead of overflowing on giant numbers.
local moneyUnits={['']=0,k=1,mil=1,m=2,million=2,["millón"]=2,millones=2,b=3,billion=3,
["billón"]=3,billones=3,t=4,trillion=4,["trillón"]=4,trillones=4,
quadrillion=5,["cuatrillón"]=5,quintillion=6,["quintillón"]=6,
sextillion=7,["sextillón"]=7,septillion=8,["septillón"]=8,
octillion=9,["octillón"]=9,nonillion=10,["nonillón"]=10,
decillion=11,["decillón"]=11,undecillion=12,["undecillón"]=12,
duodecillion=13,["duodecillón"]=13,tredecillion=14,["tredecillón"]=14,
vigintillion=21,["vigintillón"]=21,trigintillion=31,["trigintillón"]=31}
local function amountFromText(t)
 if type(t)~='string' then return nil end
 local c=NOVA_CORE.detectedWorld==2 and 'Φ' or '$'
 local i=t:find(c,1,true)
 if not i then return nil end
 local txt=t:sub(i+#c)
 local digits,unit=txt:match('^%s*([%d][%d%.,]*)%s*([^%s]*)')
 if not digits then return nil end
 unit=(unit or ''):lower():gsub('[%p]+$','')
 local rank=moneyUnits[unit]
 if not rank then return nil end
 local nsep=select(2,digits:gsub('[,%.]',''))
 if nsep>1 then digits=digits:gsub('[,%.]','')
 elseif nsep==1 then
 local tail=digits:match('[,%.](%d+)$')
 if tail and #tail==3 and rank==0 then digits=digits:gsub('[,%.]','')
 else digits=digits:gsub(',','.') end
 end
 local number=tonumber(digits)
 if not number then return nil end
 return {rank=rank,n=number,label=c..txt:sub(1,32)}
end
local function normalizarMonto(valor)
    if not valor or type(valor.rank)~='number' or type(valor.n)~='number' then return nil end
    local r,n=valor.rank,valor.n
    if n~=n or n<0 then return nil end
    if n==0 then return {rank=0,n=0,label=valor.label} end
    -- E.g., 112950 (sin sufijo) = 112.95K, que es MAYOR que 8.8K.
    while n>=1000 and r<500 do n=n/1000;r=r+1 end
    while n<1 and r>0 do n=n*1000;r=r-1 end
    return {rank=r,n=n,label=valor.label}
end
local function cheaper(a,b)
    local x,y=normalizarMonto(a),normalizarMonto(b)
    if not x or not y then return false end
    return x.rank<y.rank or (x.rank==y.rank and x.n<y.n)
end
local function walletMoney()
 local result,score=nil,-1e9
 for _,item in ipairs(playerGui:GetDescendants()) do
 if (item:IsA('TextLabel') or item:IsA('TextButton'))
 and not item:IsDescendantOf(gui) and isVisibleGui(item) then
 local val=item.Text or ''
 if #val<140 then
 local m=amountFromText(val)
 if m then
 local n=item.TextSize+(item.AbsolutePosition.Y<140 and 50 or 0)
 if n>score then score=n;result=m end
 end
 end
 end
 end
 return result
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
                    local closeEnough=host==playerGui or (hostPart and hostPart:IsA('BasePart') and distance(hostPart)<=NOVA_CORE.BUY_SEARCH_STUDS)
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
-- Classifications for WORKSTATION upgrades, not made-up purchase prices.
-- World 1 sources: Lemon Stand -> LemonX.
-- World 2 sources: Oxygen Pump -> Oxygen Bars.
NOVA_CORE.SOURCE_NAMES={
    [1]={'lemon stand','lemonstand','lemondash','lemon dash','lemon depot',
        'lemon trading','lemon labs','lemon robotics','lemon republic','lemonx'},
    [2]={'oxygen pump','oxygenpump','fast oxygen','fast o2','oxygen warehouse',
        'oxygen center','oxygen garden','oxygen resort','oxygen bars'}
}
NOVA_CORE.WORK_UPGRADE_LABELS={
    'juicer','cup stand','billboard','sugar mixer','street fliers',
    'ice maker','bogo deals','cash register','higher fees',
    'company vehicle','bigger fleet','refrigerated trucks','manager',
    'cash upgrade','speed upgrade','upgrade cash','upgrade speed',
    'income upgrade','speed boost','cash boost','production speed',
    'income multiplier','automator','automatic register','automation',
    'product display','kiosk','productivity','more tips',
    'mejora dinero','mejora velocidad','administrador','automatización',
    'mejorar ingresos','mejorar velocidad'
}
NOVA_CORE.WORK_BAD_LABELS={
    'floor','wall','roof','fence','decoration','cosmetic','staircase',
    'door','window','rebirth','investor','ascension','evolution',
    'piso','pared','techo','decoración','renacimiento','portal','robux'
}
local function padIdentity(hit)
    local p=hit and hit.part
    if not p then return '' end
    local names={p.Name}
    if hit.obj then table.insert(names,hit.obj.Name) end
    if p.Parent then
        table.insert(names,p.Parent.Name)
        if p.Parent.Parent and p.Parent.Parent~=Workspace then
            table.insert(names,p.Parent.Parent.Name)
        end
    end
    local n=0
    for _,desc in ipairs(p:GetDescendants()) do
        n=n+1
        if n>55 then break end
        if (desc:IsA('TextLabel') or desc:IsA('TextButton')) and #desc.Text<80 then
            table.insert(names,desc.Text)
        elseif desc:IsA('ProximityPrompt') then
            table.insert(names,desc.ActionText or '')
            table.insert(names,desc.ObjectText or '')
        end
    end
    return table.concat(names,' '):lower()
end
local function isWorkUpgrade(hit)
    local name=padIdentity(hit)
    if hasAny(name,NOVA_CORE.WORK_BAD_LABELS) then return false end
    if hasAny(name,NOVA_CORE.WORK_UPGRADE_LABELS) then return true end
    if hasAny(name,NOVA_CORE.SOURCE_NAMES[NOVA_CORE.detectedWorld] or {})
        and hasAny(name,{'upgrade','mejora','speed','cash','x2','x3','boost',
            'multiplier','manager','automat'}) then
        return true
    end
    return false
end

-- Precio comprobable: buscamos primero la etiqueta asociada con la pieza o GUI.
-- Evitamos asumir que el primer número del modelo representa el costo.
local function priceFromAttribute(inst)
    if not inst then return nil end
    for _,name in ipairs({'Price','Cost','PurchasePrice','PurchaseCost','CashCost','RequiredCash'}) do
        local raw=inst:GetAttribute(name)
        if type(raw)=='number' and raw>=0 and raw<math.huge then
            if raw==0 then return {rank=0,n=0,label='0 ('..name..')'} end
            local rank=math.max(0,math.floor(math.log(raw)/math.log(1000)))
            local divisor=1000^rank
            return {rank=rank,n=raw/divisor,label=name..': '..string.format('%.3g',raw)}
        elseif type(raw)=='string' then
            local parsed=amountFromText(raw)
            if parsed then return parsed end
        end
    end
    for _,child in ipairs(inst:GetChildren()) do
        if (child:IsA('NumberValue') or child:IsA('IntValue')) and
            hasAny(child.Name:lower(),{'price','cost','precio','costo'}) then
            local val=child.Value
            if val>=0 and val<math.huge then
                local rank=val==0 and 0 or math.max(0,math.floor(math.log(val)/math.log(1000)))
                return {rank=rank,n=val==0 and 0 or val/(1000^rank),label=child.Name..': '..string.format('%.3g',val)}
            end
        end
    end
    return nil
end
local function optionalPriceText(txt,name)
    local direct=amountFromText(txt)
    if direct then return direct end
    -- Si no hay simbolo monetario, exigir contexto explícito de precio.
    local context=(name or ''):lower()..' '..(txt or ''):lower()
    if not hasAny(context,{'cost','price','precio','costo'}) then return nil end
    local number,unit=(txt or ''):match('([%d][%d%.,]*)%s*([^%s]*)')
    if not number then return nil end
    unit=(unit or ''):lower():gsub('[%p]+$','')
    if unit=='investors' or unit=='inversores' then return nil end
    if moneyUnits[unit]==nil then return nil end
    local value=amountFromText((NOVA_CORE.detectedWorld==2 and 'Φ' or '$')..number..' '..unit)
    return value
end
local function uniqueScopePrice(scope,maxDesc)
    if not scope then return nil,'sin alcance' end
    local a=priceFromAttribute(scope)
    if a then return a,'atributo' end
    local values,seen={},{}
    local function check(text,name)
        local v=optionalPriceText(text,name)
        if not v then return end
        local id=v.rank..':'..string.format('%.10g',v.n)
        if not seen[id] then seen[id]=true;table.insert(values,v) end
    end
    if scope:IsA('TextButton') or scope:IsA('TextLabel') then check(scope.Text,scope.Name) end
    local used=0
    for _,v in ipairs(scope:GetDescendants()) do
        used=used+1
        if used>(maxDesc or 100) then break end
        if v:IsA('TextLabel') or v:IsA('TextButton') then check(v.Text,v.Name) end
    end
    if #values==1 then return values[1],'etiqueta' end
    if #values>1 then return nil,'varios precios distintos' end
    return nil,'sin precio'
end
local function upgradeCost(hit)
    if not hit or not hit.obj or not hit.obj.Parent then return nil,'objeto ausente' end
    local object=hit.obj
    local part=hit.part
    -- Un modelo completo puede incluir cientos de botones y precios ajenos:
    -- leer SOLO el pad específico y los rótulos que contiene.
    local scopes={}
    if part then
        table.insert(scopes,part)
        if object~=part then table.insert(scopes,object) end
    else
        table.insert(scopes,object)
    end
    local reason='sin precio del botón'
    for _,scope in ipairs(scopes) do
        local v,why=uniqueScopePrice(scope,70)
        if v then return v,why end
        if why=='varios precios distintos' then return nil,'precios ambiguos' end
        reason=why or reason
    end
    if part then
        local fromName=optionalPriceText(part.Name,part.Name)
        if fromName then return fromName,'nombre del botón' end
    end
    return nil,reason
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
    -- Un Lemon Stand o una mejora de oxígeno pueden contener "lemon" o "ice"
    -- en su nombre. La intención de compra debe tener prioridad.
    if hasAny(direct,{'upgrade','purchase','comprar','buy button','mejora',
        'mejorar','upgradebutton','buybutton'}) then return 'buy' end
    if hasAny(direct,{'ice chunk','icechunk','hielo','fragmento de hielo','ice pickup','ice collectible'}) then return 'ice' end
    if hasAny(direct,{'cash drop','cashdrop','cash vine','cashvine','money drop','drop cash'}) then return 'cash' end
    if hasAny(direct,{'lemon','limon','fruit','fruta','orchard'}) then return 'fruit' end
    if hasAny(direct,{'button','boton'}) then return 'buy' end
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
                if part and distance(part)<=math.max(125,NOVA_CORE.BUY_SEARCH_STUDS,NOVA_CORE.iceSearchMeters*NOVA_CORE.STUDS_PER_METER)
                    and not (NOVA_CORE.detectedWorld==2 and (category=='fruit' or category=='cash'))
                    and not (NOVA_CORE.detectedWorld==1 and category=='ice') then
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
    for obj,h in pairs(NOVA_CORE.highlights) do
        if h then h:Destroy() end
        NOVA_CORE.highlights[obj]=nil
    end
end
local function updateHighlights()
    clearHighlights()
    if not state.radar then return end
    local added=0
    for _,bucket in ipairs({hits.fruit,hits.ice,hits.buy}) do
        for _,hit in ipairs(bucket) do
            if added>=22 then return end
            if hit.part:IsDescendantOf(Workspace) and not NOVA_CORE.highlights[hit.part] then
                local h=make('Highlight',{
                    Adornee=hit.part,FillTransparency=.85,OutlineTransparency=0,
                    FillColor=COLOR.warning,OutlineColor=COLOR.accent,
                    DepthMode=Enum.HighlightDepthMode.Occluded
                },hit.part)
                NOVA_CORE.highlights[hit.part]=h
                added=added+1
            end
        end
    end
end
NOVA_CORE.onToggle=function(key,reason)
    if key=='radar' then updateHighlights() end
    if reason=='no-target' then
        -- Toggle remains available: show explicitly why there are no actions yet.
        if NOVA_CORE.statusNotice then NOVA_CORE.statusNotice('Activado sin objetivos compatibles para '..key..'. Revisa el escáner.') end
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
    return candidate(bucket,range or NOVA_CORE.MAX_RANGE,true)
end
-- Reubicación local opcional: el servidor puede corregirla.
-- Do not keep returning to the same nearest upgrade pad.
local budgetMessage='Saldo no identificado'
local lastBudgetMessage=0
local lastBudgetRefresh=0
local buildSummary={wallet=nil,next=nil,nextPrice=nil,priced=0,payable=0,unknown=0,unaffordable=0}

-- Filtro conservador: ignora otras parcelas cuando el servidor publica dueño.
-- Sin metadatos de propietario, elige sólo plataformas próximas a la
-- posición donde se activó Auto Mejoras, en vez de saltar miles de studs.
local function plotOwnedByPlayer(part)
    local ancestor=part
    for _=1,7 do
        if not ancestor or ancestor==Workspace then break end
        for _,field in ipairs({'Owner','OwnerId','OwnerUserId','PlotOwner','ClaimedBy','PlayerOwner'}) do
            local raw=ancestor:GetAttribute(field)
            local value=ancestor:FindFirstChild(field)
            if raw==nil and value then
                if value:IsA('ObjectValue') then raw=value.Value
                elseif value:IsA('StringValue') or value:IsA('IntValue') or value:IsA('NumberValue') then
                    raw=value.Value
                end
            end
            if raw~=nil and raw~='' and raw~=0 then
                if typeof(raw)=='Instance' and raw:IsA('Player') then
                    return raw==player
                elseif type(raw)=='number' then
                    return raw==player.UserId
                elseif type(raw)=='string' then
                    local norm=raw:lower()
                    if norm==player.Name:lower() or norm==tostring(player.UserId)
                        or norm==player.DisplayName:lower() then return true end
                    if tonumber(norm) then return tonumber(norm)==player.UserId end
                    if #norm>2 and norm~='none' and norm~='unclaimed' then return false end
                end
            end
        end
        ancestor=ancestor.Parent
    end
    return nil
end
-- Ubicación inicial inferida sólo si hay evidencia cercana.
-- Preferir fuentes iniciales conocidas y precios pequeños; nunca elegir
-- ciegamente la posición actual en el final del tycoon.
NOVA_CORE.autoLocateStart=function()
    local world=NOVA_CORE.detectedWorld
    if world~=1 and world~=2 then return false,'Mundo desconocido' end
    if NOVA_CORE.startAnchor[world] then return true,'Referencia existente' end
    local root=rootPart()
    if not root then return false,'Personaje no disponible' end
    local wallet=walletMoney()
    local best,priceBest,distBest,preferStarter=nil,nil,math.huge,false
    local startTokens=world==1 and {'lemon stand','lemonstand','starter','first stand'}
        or {'oxygen pump','oxygenpump','starter','first pump'}
    local eligibleCount=0
    for _,hit in ipairs(hits.buy) do
        local p=hit.part
        if p and p:IsDescendantOf(Workspace)
            and plotOwnedByPlayer(p)~=false then
            local d=(p.Position-root.Position).Magnitude
            if d<=1200 then
                local value=upgradeCost(hit)
                if value then
                    eligibleCount=eligibleCount+1
                    local identity=padIdentity(hit)
                    local starter=hasAny(identity,startTokens)
                    -- Si no hay indicador inicial, no anclar a compras que
                    -- cuestan miles de veces más que el saldo actual.
                    local economicallyPlausible=false
                    if wallet then
                        local w=normalizarMonto(wallet)
                        local q=normalizarMonto(value)
                        if w and q then
                            economicallyPlausible=q.rank<=w.rank+1
                                and (q.rank<w.rank+1 or q.n<=w.n*.1)
                        end
                    end
                    if starter or (d<=270 and economicallyPlausible) then
                        if not best
                            or (starter and not preferStarter)
                            or (starter==preferStarter and
                                (cheaper(value,priceBest)
                                or (not cheaper(priceBest,value) and d<distBest))) then
                            best,priceBest,distBest,preferStarter=hit,value,d,starter
                        end
                    end
                end
            end
        end
    end
    if best then
        NOVA_CORE.startAnchor[world]=best.part.Position
        NOVA_CORE.startAnchorMethod[world]=preferStarter and 'puesto inicial detectado' or 'precio económico cercano'
        NOVA_CORE.buyCooldown={}
        return true,'Inicio automático: '..NOVA_CORE.startAnchorMethod[world]
    end
    if not wallet then
        return false,'Saldo no legible; marca el inicio manualmente'
    end
    if eligibleCount==0 then
        return false,'No se detectaron precios cerca; marca el inicio en Build'
    end
    return false,'Los botones próximos parecen caros; marca el inicio manualmente'
end

-- NOVA Zones. Known production sources take precedence over geometry.
-- Geometry is only a fallback when game object labels are generic.
NOVA_CORE.explicitZone=function(hit)
    if not hit or not hit.part then return nil end
    local text=padIdentity(hit)
    local names=NOVA_CORE.zoneNames[NOVA_CORE.detectedWorld] or {}
    for index,name in ipairs(names) do
        if text:find(name:lower(),1,true) then return index end
    end
    if NOVA_CORE.detectedWorld==2 then
        if hasAny(text,{'fast oxygen','fastoxygen','fast o2','fasto2'}) then return 2 end
        if hasAny(text,{'oxygen pump','oxygenpump'}) then return 1 end
    end
    if NOVA_CORE.detectedWorld==1 then
        if hasAny(text,{'lemon dash','lemondash'}) then return 2 end
        if hasAny(text,{'lemon stand','lemonstand'}) then return 1 end
    end
    return nil
end
NOVA_CORE.zoneLandmarks=function()
    local landmarks={}
    local start=NOVA_CORE.startAnchor[NOVA_CORE.detectedWorld]
    for _,hit in ipairs(hits.buy) do
        if hit.part and hit.part:IsDescendantOf(Workspace) and
            plotOwnedByPlayer(hit.part)~=false and
            (not start or (hit.part.Position-start).Magnitude<=1000) then
            local index=NOVA_CORE.explicitZone(hit)
            if index then
                landmarks[index]=landmarks[index] or {}
                -- Limit landmark samples to keep large tycoons responsive on mobile.
                if #landmarks[index]<12 then
                    table.insert(landmarks[index],hit.part.Position)
                end
            end
        end
    end
    return landmarks
end
NOVA_CORE.zoneOfHit=function(hit,landmarks)
    if not hit or not hit.part then return nil end
    local known=NOVA_CORE.explicitZone(hit)
    if known then return known end
    local part=hit.part
    -- Buttons with generic names often belong to the nearest named station.
    local nearIndex,nearDist=nil,120
    for index,positions in pairs(landmarks or {}) do
        for _,position in ipairs(positions) do
            local d=(part.Position-position).Magnitude
            if d<nearDist then nearDist=d;nearIndex=index end
        end
    end
    if nearIndex then return nearIndex end
    local anchor=NOVA_CORE.startAnchor[NOVA_CORE.detectedWorld]
    if not anchor then return 1 end
    -- Fallback: bands radiating outward from the verified starter location.
    local flat=Vector3.new(part.Position.X-anchor.X,0,part.Position.Z-anchor.Z).Magnitude
    local names=NOVA_CORE.zoneNames[NOVA_CORE.detectedWorld] or {'Inicio'}
    return math.clamp(math.floor(flat/120)+1,1,#names)
end
NOVA_CORE.setZoneStatus=function(message)
    NOVA_CORE.zoneStatus=message
    for _,label in ipairs(NOVA_CORE.zoneStatusLabels) do
        if label and label.Parent then label.Text=message end
    end
end

local function eligibleBuyArea(part)
    if not part or not part:IsDescendantOf(Workspace) then return false end
    local owned=plotOwnedByPlayer(part)
    if owned==false then return false end
    local start=NOVA_CORE.startAnchor[NOVA_CORE.detectedWorld]
    if not start then return false end -- nunca adivinar que estamos al inicio
    local d=(part.Position-start).Magnitude
    -- Zone progression covers all reachable stations, not only the first 190 studs.
    -- Honor explicit ownership whenever available and constrain unknown plots.
    if owned==true then return d<=1250 end
    return d<=850
end
local function nextBuildTarget()
    local now=os.clock()
    local wallet=walletMoney()
    local summary={wallet=wallet,next=nil,nextPrice=nil,priced=0,payable=0,unknown=0,unaffordable=0}
    if not wallet then
        budgetMessage='Saldo no legible | compras pausadas'
        buildSummary=summary
        return nil
    end
    local best,bestPrice,bestDistance=nil,nil,math.huge
    local function tryCandidate(hit)
        local obj=hit.obj
        if not obj or not obj.Parent then return end
        local isGui=obj:IsA('GuiButton')
        local part=hit.part
        local d=part and distance(part) or 0
        if isGui then
            if not isVisibleGui(obj) then return end
        else
            if not part or not part:IsDescendantOf(Workspace) or d>NOVA_CORE.BUY_SEARCH_STUDS then return end
            if state.needed and part.Transparency>.85 then return end
            if not eligibleBuyArea(part) then return end
        end
        -- El precio cambia despues de las mejoras. Se revalida cada ~1 s.
        if not hit.priceReadAt or now-hit.priceReadAt>1 then
            hit.price,hit.priceReason=upgradeCost(hit)
            hit.priceReadAt=now
        end
        local price=hit.price
        if not price then summary.unknown=summary.unknown+1;return end
        if state.autoStations and not (state.buy or state.buyMars) and not isWorkUpgrade(hit) then return end
        summary.priced=summary.priced+1
        if cheaper(wallet,price) then summary.unaffordable=summary.unaffordable+1;return end
        summary.payable=summary.payable+1
        if not isGui and d>allowedActivationDistance(obj) and not state.buyTeleport then return end
        if not isGui and now-(NOVA_CORE.teleportLog[obj] or -1e9)<NOVA_CORE.BUILD_RETRY_COOLDOWN then return end
        if isGui and now-(NOVA_CORE.lastAttempt[obj] or -1e9)<NOVA_CORE.DELAY then return end
        if not best or
            (state.cheapFirst and (cheaper(price,bestPrice)
            or (not cheaper(bestPrice,price) and d<bestDistance)))
            or (not state.cheapFirst and d<bestDistance) then
            best,bestPrice,bestDistance=hit,price,d
        end
    end
    for _,hit in ipairs(hits.buy) do tryCandidate(hit) end
    -- Solo objetivos fisicos aptos para TP.
    summary.next=best
    summary.nextPrice=bestPrice
    buildSummary=summary
    local nextText=bestPrice and bestPrice.label or 'ninguna'
    budgetMessage=string.format('Saldo: %s | Precios asequibles: %d\nSiguiente objetivo: %s',
        wallet.label,summary.payable,nextText)
    return best
end


-- Acceso rápido seguro al botón Remote Buy integrado por el propio juego.
-- No intenta comprar poderes, gamepasses ni artículos por Robux.
local function findOfficialRemoteBuy()
    local root=playerGui
    for _,button in ipairs(root:GetDescendants()) do
        if button:IsA('GuiButton') and not button:IsDescendantOf(gui)
            and isVisibleGui(button) and button.AbsoluteSize.X>=10
            and button.AbsoluteSize.Y>=10 then
            local words=(button:IsA('TextButton') and button.Text or ''):lower()
            local path=''
            local cur=button
            for _=1,4 do
                if not cur or cur==playerGui then break end
                path=path..' '..cur.Name:lower()
                cur=cur.Parent
            end
            for _,child in ipairs(button:GetDescendants()) do
                if child:IsA('TextLabel') and #words<190 then
                    words=words..' '..child.Text:lower()
                end
            end
            local combined=path..' '..words
            -- No tocar la opción de compra del poder en Powers/Shop.
            -- Solo es válido el botón de Remote Buy presente en el HUD de juego.
            local storeContext=hasAny(path,{
                'power','shop','store','tienda','gamepass','catalog',
                'purchaseoffer','marketplace','inventory','robux'})
            local inScroll=button:FindFirstAncestorOfClass('ScrollingFrame')~=nil
            local view=Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize
            local hudPosition=(view and view.Y>0)
                and button.AbsolutePosition.Y>view.Y*.34
            if not storeContext and not inScroll and hudPosition
                and not hasAny(combined,BAD_PURCHASE)
                and (hasAny(path,{'remotebuy','remote_buy','remote buy'})
                or hasAny(words,{'remote buy','compra remota'})) then
                return {obj=button,part=nil}
            end
        end
    end
    return nil
end
local officialRemoteBuy=nil
local lastOfficialScan=-1e9
local function refreshOfficialRemoteBuy()
    local now=os.clock()
    if now-lastOfficialScan>3 then
        officialRemoteBuy=findOfficialRemoteBuy()
        lastOfficialScan=now
    end
    return officialRemoteBuy
end

-- Botones grandes: encienden el mismo interruptor de Auto Mejoras de cada mundo.
for _,entry in ipairs(buildActionButtons) do
    local key=entry.world==1 and 'buy' or 'buyMars'
    local button=entry.button
    local function paint()
        local on=state[key]
        button.Text=on and 'AUTO PROGRESO: ON' or 'AUTO PROGRESO: OFF'
        button.BackgroundColor3=on and Color3.fromRGB(0,70,92) or COLOR.nav
        button.TextColor3=on and COLOR.success or COLOR.accent
    end
    if not NOVA_CORE.switches[key] then NOVA_CORE.switches[key]={} end
    table.insert(NOVA_CORE.switches[key],paint)
    paint()
    button.MouseButton1Click:Connect(function()
        state[key]=not state[key]
        if state[key] then
            state[entry.world==1 and 'buyMars' or 'buy']=false
            state.buyTeleport=true
            state.autoStations=true
            state.startOnly=false
            NOVA_CORE.buyPending=nil
            NOVA_CORE.zoneStage[entry.world]=1
            NOVA_CORE.buyCooldown={}
        else
            if not state.buy and not state.buyMars then
                state.autoStations=false
                NOVA_CORE.buyPending=nil
            end
        end
        for _,name in ipairs({'buy','buyMars'}) do
            for _,draw in ipairs(NOVA_CORE.switches[name] or {}) do draw() end
        end
    end)
end

local function repositionNear(hit,label,isPurchase)
    local root=rootPart()
    if not root or not hit or not hit.part or not hit.part:IsDescendantOf(Workspace) then return false end
    local char=player.Character
    local humanoid=char and char:FindFirstChildOfClass('Humanoid')
    if not char or not humanoid or humanoid.Health<=0 then return false end
    local now=os.clock()
    local delay=isPurchase and NOVA_CORE.buildMoveDelay or NOVA_CORE.ICE_MOVE_INTERVAL
    local previous=isPurchase and NOVA_CORE.lastBuildMoveAt or NOVA_CORE.lastIceMoveAt
    local revisit=isPurchase and NOVA_CORE.BUILD_RETRY_COOLDOWN or 1.5
    if now-NOVA_CORE.lastMoveAt<.25 or now-previous<delay or now-(NOVA_CORE.teleportLog[hit.obj] or -1e9)<revisit then return false end
    if distance(hit.part)>(isPurchase and NOVA_CORE.BUY_SEARCH_STUDS or NOVA_CORE.iceSearchMeters*NOVA_CORE.STUDS_PER_METER) then return false end
    NOVA_CORE.lastMoveAt=now
    if isPurchase then NOVA_CORE.lastBuildMoveAt=now else NOVA_CORE.lastIceMoveAt=now end
    NOVA_CORE.teleportLog[hit.obj]=now
    if not NOVA_CORE.savedPosition then NOVA_CORE.savedPosition=char:GetPivot() end
    local part=hit.part
    local height
    if isPurchase then
        height=part.Size.Y*.5+math.max(2.7,humanoid.HipHeight+root.Size.Y*.5+.65)
    else
        height=math.clamp(part.Size.Y*.5+3,3,8)
    end
    local dest=part.Position+Vector3.new(0,height,0)
    local before=root.Position
    local ok,err=pcall(function() char:PivotTo(CFrame.new(dest,dest+root.CFrame.LookVector)) end)
    if not ok then
        if NOVA_CORE.statusNotice then NOVA_CORE.statusNotice('Salto fallido: '..tostring(err)) end
        return false
    end
    NOVA_CORE.teleportCount=NOVA_CORE.teleportCount+1
    if isPurchase then
        NOVA_CORE.buildHops=NOVA_CORE.buildHops+1
    else
        stats.iceRocks=stats.iceRocks+1
        table.insert(NOVA_CORE.iceRockVisits,{position=part.Position,at=now})
    end
    if NOVA_CORE.statusNotice then NOVA_CORE.statusNotice(label..': salto local enviado (sin confirmar recolección)') end
    task.delay(.55,function()
        if not running or not gui.Parent then return end
        local current=rootPart()
        if not current then return end
        if (current.Position-dest).Magnitude>18 and (current.Position-before).Magnitude<9 then
            NOVA_CORE.teleportsFailed=NOVA_CORE.teleportsFailed+1
            if NOVA_CORE.statusNotice then NOVA_CORE.statusNotice('Posición corregida por el juego: '..NOVA_CORE.teleportsFailed..'/2') end
            if NOVA_CORE.teleportsFailed>=2 then
                local key=isPurchase and 'buyTeleport' or 'iceTeleport'
                state[key]=false
                for _,draw in ipairs(NOVA_CORE.switches[key] or {}) do draw() end
                if NOVA_CORE.statusNotice then
                    NOVA_CORE.statusNotice('TP detenido: el juego revirtió la posición')
                end
            end
        else NOVA_CORE.teleportsFailed=0 end
    end)
    return true
end
local function attemptInteraction(hit,perTargetDelay)
    if not hit then return false,'Sin objetivos cercanos' end
    local obj=hit.obj
    if os.clock()-(NOVA_CORE.lastAttempt[obj] or -1e9)<(perTargetDelay or NOVA_CORE.DELAY) then return false,'En espera' end
    NOVA_CORE.lastAttempt[obj]=os.clock()
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
                NOVA_CORE.lastAttempt[obj]=nil
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

-- Comparación aproximada de presupuestos con notación de millares.
-- Nunca se supone que el saldo haya cambiado de verdad: se reserva en el lote
-- y se vuelve a consultar la pantalla en el siguiente ciclo.
local function subtractBudget(wallet,price)
    if not wallet or not price or cheaper(wallet,price) then return nil end
    local rank=math.max(wallet.rank,price.rank)
    local amount=(wallet.n*1000^(wallet.rank-rank))-
        (price.n*1000^(price.rank-rank))
    if amount< -1e-9 then return nil end
    amount=math.max(0,amount)
    while amount>0 and amount<1 and rank>0 do
        amount=amount*1000
        rank=rank-1
    end
    while amount>=1000 do
        amount=amount/1000
        rank=rank+1
    end
    return {rank=rank,n=amount,label='saldo reservado en lote'}
end

local function pricedBuildQueue()
    local wallet=walletMoney()
    if not wallet then
        NOVA_CORE.setZoneStatus('Zona en espera: saldo no reconocido')
        return nil,{}
    end
    local world=NOVA_CORE.detectedWorld
    if not NOVA_CORE.startAnchor[world] then
        local located,reason=NOVA_CORE.autoLocateStart()
        if not located then
            NOVA_CORE.buyPendingHint=reason
            NOVA_CORE.buyQueueStats={seen=#hits.buy,area=0,priced=0,affordable=0,station=0}
            NOVA_CORE.setZoneStatus('Zona sin identificar: '..reason)
            return wallet,{}
        end
    end
    local now=os.clock()
    local groups,waiting,seen={}, {}, {}
    local landmarks=NOVA_CORE.zoneLandmarks()
    local names=NOVA_CORE.zoneNames[world] or {'Inicio'}
    local summary={seen=#hits.buy,area=0,priced=0,affordable=0,station=0}
    for _,hit in ipairs(hits.buy) do
        local obj,part=hit.obj,hit.part
        if obj and obj.Parent and part and part:IsDescendantOf(Workspace)
            and not seen[obj] and distance(part)<=NOVA_CORE.BUY_SEARCH_STUDS
            and (not state.needed or part.Transparency<=.85)
            and eligibleBuyArea(part) then
            seen[obj]=true
            summary.area=summary.area+1
            -- Never use an old price for a button that has changed.
            if not hit.priceReadAt or now-hit.priceReadAt>.75 then
                hit.price,hit.priceReason=upgradeCost(hit)
                hit.priceReadAt=now
            end
            local price=hit.price
            if price then
                summary.priced=summary.priced+1
                if not cheaper(wallet,price) then
                    summary.affordable=summary.affordable+1
                    if isWorkUpgrade(hit) then summary.station=summary.station+1 end
                    local zone=NOVA_CORE.zoneOfHit(hit,landmarks)
                    if zone then
                        local cool=NOVA_CORE.buyCooldown[obj] or 0
                        local lastMove=NOVA_CORE.teleportLog[obj] or -1e9
                        if cool>now or now-lastMove<NOVA_CORE.BUILD_RETRY_COOLDOWN then
                            waiting[zone]=math.max(waiting[zone] or 0,cool,lastMove+NOVA_CORE.BUILD_RETRY_COOLDOWN)
                        else
                            groups[zone]=groups[zone] or {}
                            table.insert(groups[zone],{hit=hit,price=price,d=distance(part),zone=zone})
                        end
                    end
                end
            end
        end
    end
    NOVA_CORE.buyQueueStats=summary
    for _,list in pairs(groups) do
        table.sort(list,function(a,b)
            if cheaper(a.price,b.price) then return true end
            if cheaper(b.price,a.price) then return false end
            return a.d<b.d
        end)
    end
    local current=math.clamp(NOVA_CORE.zoneStage[world] or 1,1,#names)
    local chosen=nil
    -- Continue at the current station; when exhausted, move to the next one.
    -- If the active zone is cooling down for less than 2 seconds, wait.
    if groups[current] and #groups[current]>0 then
        chosen=current
    elseif waiting[current] and waiting[current]-now<2 then
        NOVA_CORE.setZoneStatus('Zona '..current..': '..names[current]..' · verificando botón')
        return wallet,{}
    else
        for index=current+1,#names do
            if groups[index] and #groups[index]>0 then chosen=index;break end
        end
        if not chosen then
            -- Backfill old businesses after reaching the end of the progression.
            for index=1,current-1 do
                if groups[index] and #groups[index]>0 then chosen=index;break end
            end
        end
    end
    if not chosen then
        local why=summary.affordable==0 and 'sin mejoras pagables'
            or 'sin botones disponibles (espera de reintentos)'
        NOVA_CORE.setZoneStatus('Zona '..current..': '..names[current]..' · '..why)
        return wallet,{}
    end
    if chosen~=current then
        NOVA_CORE.zoneStage[world]=chosen
    end
    local msg='Zona '..chosen..'/'..#names..': '..names[chosen]
        ..' · '..#groups[chosen]..' mejora(s) disponible(s)'
    NOVA_CORE.setZoneStatus(msg)
    return wallet,groups[chosen]
end

local function showBatchStatus(message)
    NOVA_CORE.latestBatchStatus=message
    for _,label in ipairs(buildBatchStatusLabels) do
        if label and label.Parent then label.Text=message end
    end
end

-- v4.5.1: mantener las variables auxiliares dentro de un bloque para
-- reducir los locales activos del archivo principal (límite de Luau).
local runAutoUpgrades
do
local lastRemoteLabelUpdate=-1e9
local remoteAttemptsWithoutConfirmation=0
local function purchasePath(message)
    if buildBatchStatusLabels.activePurchasePath==message then return end
    buildBatchStatusLabels.activePurchasePath=message
    for _,label in ipairs(buildBatchStatusLabels.purchasePathLabels) do
        if label and label.Parent then label.Text=message end
    end
end
-- Una solicitud de clic no confirma una compra. Si el juego expone un contador
-- claro de botones comprados, ese contador sí puede servir de evidencia.
local function observedBoughtCount()
    for _,node in ipairs(playerGui:GetDescendants()) do
        if node:IsA('TextLabel') and not node:IsDescendantOf(gui)
            and isVisibleGui(node) then
            local t=(node.Text or ''):lower()
            if #t<120 and hasAny(t,{'buttons bought','botones comprados'}) then
                local number=t:match('(%d+)%s*/%s*%d+') or t:match(':%s*(%d+)')
                if number then return tonumber(number) end
            end
        end
    end
    return nil
end

-- Motor de compras sin rutas ni caminata: un TP por objetivo.
runAutoUpgrades=function()
    local now=os.clock()
    if now-NOVA_CORE.lastBatchRun<.20 then return end
    NOVA_CORE.lastBatchRun=now
    local pending=NOVA_CORE.buyPending
    if pending then
        if now-pending.at<.8 then return end
        local after=observedBoughtCount()
        if pending.before~=nil and after~=nil and after>pending.before then
            NOVA_CORE.buyFailCounts[pending.obj]=nil
            showBatchStatus('Compras confirmadas: +'..(after-pending.before))
            purchasePath('Compra verificada: '..tostring(pending.label))
        elseif not pending.obj.Parent or
            (pending.part and not pending.part:IsDescendantOf(Workspace)) then
            showBatchStatus('La plataforma desapareció: posible compra.')
        else
            local misses=(NOVA_CORE.buyFailCounts[pending.obj] or 0)+1
            NOVA_CORE.buyFailCounts[pending.obj]=misses
            -- After repeated unconfirmed attempts, move on to another station
            -- instead of returning to the same unsuccessful pad forever.
            NOVA_CORE.buyCooldown[pending.obj]=now+(misses>=3 and 12 or 1.15)
            if misses>=3 then
                showBatchStatus('Sin compra confirmada tras '..misses..' intentos; buscando siguiente zona.')
            else
                showBatchStatus('TP realizado; compra aún no confirmada.')
            end
            purchasePath('Siguiente botón o zona con precio pagable.')
        end
        NOVA_CORE.buyPending=nil
        if (pending.before~=nil and after~=nil and after>pending.before)
            or not pending.obj.Parent then
            scanWorld()
        end
        return
    end
    local money,ordered=pricedBuildQueue()
    if money then
        budgetMessage=string.format('Saldo: %s | Pagables: %d\n%s',
            tostring(money.label),NOVA_CORE.buyQueueStats.affordable or 0,
            NOVA_CORE.zoneStatus or 'Sin zona')
    end
    if not money then
        showBatchStatus('Sin saldo confiable: compras pausadas.')
        return
    end
    if #ordered==0 then
        if not NOVA_CORE.startAnchor[NOVA_CORE.detectedWorld] then
            showBatchStatus(NOVA_CORE.buyPendingHint~='' and NOVA_CORE.buyPendingHint or 'Inicio no identificado.')
            purchasePath('Sin inicio fiable: no se harán teletransportes al azar.')
            return
        end
        local summary=NOVA_CORE.buyQueueStats
        if summary.priced==0 then
            showBatchStatus('Sin precios legibles en los botones iniciales.')
        elseif summary.affordable==0 then
            showBatchStatus('Saldo insuficiente. 0 compras pagables de '..summary.priced..' precios.')
        elseif state.autoStations and not (state.buy or state.buyMars) then
            showBatchStatus('No hay mejoras de puestos pagables reconocidas.')
        else
            showBatchStatus('No hay botón elegible disponible (reintentos en pausa).')
        end
        purchasePath('Revisa la detección de precio y la parcela.')
        return
    end
    local cheapest=ordered[1]
    local hit=cheapest.hit
    local obj,part=hit.obj,hit.part
    if not obj or not obj.Parent or not part or not part.Parent then return end
    if not state.buyTeleport then
        purchasePath('Activa Teletransportarse a mejoras.')
        return
    end
    local before=observedBoughtCount()
    local success=false
    local method='TP'
    if distance(part)<=allowedActivationDistance(obj)
        and (obj:IsA('ClickDetector') or obj:IsA('ProximityPrompt')) then
        success=attemptInteraction(hit,NOVA_CORE.BATCH_INTERACTION_DELAY)
        method='interacción cercana'
    else
        success=repositionNear(hit,'Plataforma de menor precio',true)
    end
    if not success then
        showBatchStatus('Objetivo ocupado o TP bloqueado; esperando.')
        return
    end
    NOVA_CORE.buyPending={obj=obj,part=part,at=os.clock(),
        before=before,label=cheapest.price.label}
    NOVA_CORE.batchAttempts=NOVA_CORE.batchAttempts+1
    showBatchStatus('1 objetivo: '..tostring(cheapest.price.label)..' ('..method..')')
    purchasePath('Comprando de menor a mayor: '..tostring(cheapest.price.label))
end
end -- cierre de bloque local del diagnóstico / compra rápida

-- Evaluación prudente del menú de inversores. No obtiene datos privados
-- ni invoca remotes desconocidos: sólo lee texto visible y botones de la UI.
local function investorValue(t)
    if type(t)~='string' then return nil end
    local number,unit=t:match('([%d][%d%.,]*)%s*([^%s]*)')
    if not number then return nil end
    unit=(unit or ''):lower():gsub('^[%p]+',''):gsub('[%p]+$','')
    if hasAny(unit,{'investor','inversor'}) then unit='' end
    if moneyUnits[unit]==nil then return nil end
    return amountFromText((NOVA_CORE.detectedWorld==2 and 'Φ' or '$')..number..' '..unit)
end
local function investorMultiplier(current,earned)
    if not current or not earned then return nil end
    if current.n<=0 or earned.n<0 then return nil end
    local log10=math.log(earned.n)/math.log(10)
        -math.log(current.n)/math.log(10)
        +(earned.rank-current.rank)*3
    if log10>9 then return math.huge end
    if log10< -6 then return 0 end
    return 10^log10
end
local function readInvestorPopup()
    local currentCandidates,earnedCandidates={},{}
    local rebirthButton,confirmButton=nil,nil
    local investorClues=0
    local labels=0
    for _,node in ipairs(playerGui:GetDescendants()) do
        if node:IsA('GuiObject') and not node:IsDescendantOf(gui) and isVisibleGui(node) then
            if node:IsA('TextLabel') or node:IsA('TextButton') then
                labels=labels+1
                local raw=node.Text or ''
                if #raw<190 then
                    local low=raw:lower()
                    if hasAny(low,{'rebirth','investor','inversor','renacimiento','renacer'}) then
                        investorClues=investorClues+1
                    end
                    local gain=hasAny(low,{'rebirth to get','rebirth for','you will get',
                        'investors to get','investors gained','gain investors',
                        'renacer para obtener','obtendrás','ganarás inversores',
                        'inversores a ganar','inversores al renacer'})
                    local current=hasAny(low,{'you have','currently have','current investors',
                        'your investors','already have','inversores actuales',
                        'inversores que tienes','inversores disponibles'})
                        or low:match('^%s*investors%s*:')
                        or low:match('^%s*inversores%s*:')
                    local value=nil
                    if current or gain then
                        -- Extraer solo la cifra posterior al título, nunca el "x10" de una ayuda.
                        local after=raw:match(':%s*(.+)')
                        if not after then
                            after=raw:gsub('^[^%d]+','')
                        end
                        value=investorValue(after)
                        if not value and node.Parent then
                            -- Un rótulo y su importe pueden estar en TextLabels hermanos.
                            local possibilities={}
                            for _,sibling in ipairs(node.Parent:GetChildren()) do
                                if sibling~=node and (sibling:IsA('TextLabel') or sibling:IsA('TextButton'))
                                    and isVisibleGui(sibling) then
                                    local other=sibling.Text or ''
                                    if #other<100 and other:match('^%s*[%d]') then
                                        local item=investorValue(other)
                                        if item then table.insert(possibilities,item) end
                                    end
                                end
                            end
                            if #possibilities==1 then value=possibilities[1] end
                        end
                    end
                    if value then
                        value.sourceGui=node:FindFirstAncestorOfClass('ScreenGui')
                        if gain then table.insert(earnedCandidates,value) end
                        if current then table.insert(currentCandidates,value) end
                    end
                    if node:IsA('TextButton') and not hasAny(low,{'robux','purchase','gamepass','shop'}) then
                        if low:match('^%s*rebirth%s*!?%s*$') or
                            low:match('^%s*renacer%s*!?%s*$') then
                            rebirthButton=node
                        elseif hasAny(low,{'confirm rebirth','yes, rebirth','rebirth now',
                            'confirmar renacimiento','confirmar renacer','sí, renacer'}) then
                            confirmButton=node
                        end
                    end
                end
            end
        end
    end
    local function single(values)
        if #values==0 then return nil end
        local first=values[1]
        for i=2,#values do
            if first.rank~=values[i].rank or first.sourceGui~=values[i].sourceGui or math.abs(first.n-values[i].n)>math.max(1,first.n)*1e-6 then
                return nil
            end
        end
        return first
    end
    local current=single(currentCandidates)
    local gain=single(earnedCandidates)
    if not current or not gain or not current.sourceGui or
        current.sourceGui~=gain.sourceGui then
        current=nil;gain=nil
    end
    if current then
        -- Aceptar sólo botones dentro de la misma interfaz de los inversores.
        if rebirthButton and rebirthButton:FindFirstAncestorOfClass('ScreenGui')~=current.sourceGui then
            rebirthButton=nil
        end
        if confirmButton and confirmButton:FindFirstAncestorOfClass('ScreenGui')~=current.sourceGui then
            confirmButton=nil
        end
    end
    local multiplier=investorMultiplier(current,gain)
    return {current=current,gain=gain,multiplier=multiplier,
        rebirthButton=rebirthButton,confirmButton=confirmButton,clues=investorClues,labels=labels}
end
local function updateInvestors(allowAction)
    local info=readInvestorPopup()
    investorSnapshot=info
    if NOVA_CORE.detectedWorld~=1 then
        investorStatus='Inversores: cambia al Mundo 1 y abre la ventana de Joe.'
    elseif not info.current or not info.gain or info.clues<2 then
        investorStatus='Inversores: faltan cantidades verificables. Abre el menú de Joe.'
    elseif not info.multiplier then
        investorStatus='Inversores: cantidad actual cero. Primer renacimiento: hazlo manualmente.'
    else
        local factor=info.multiplier==math.huge and '>1.000.000' or string.format('%.2f',info.multiplier)
        investorStatus='Actual: '..info.current.label..
            '\nRecibirías: '..info.gain.label..
            '\nFactor: x'..factor..' (objetivo x'..INVESTOR_REQUIRED_MULTIPLE..')'
        if info.multiplier<INVESTOR_REQUIRED_MULTIPLE then
            investorStatus=investorStatus..'\nAún no cumple la regla x10.'
        elseif not state.autoRebirth then
            investorStatus=investorStatus..'\nObjetivo alcanzado; Auto Rebirth apagado.'
        elseif not info.rebirthButton and not info.confirmButton then
            investorStatus=investorStatus..'\nFalta botón de renacimiento verificado.'
        end
    end
    for _,label in ipairs(investorLabels) do
        if label and label.Parent then label.Text=investorStatus end
    end
    if not allowAction or not state.autoRebirth or NOVA_CORE.detectedWorld~=1
        or not info.current or not info.gain or not info.multiplier
        or info.clues<2 or info.multiplier<INVESTOR_REQUIRED_MULTIPLE then return info end
    local now=os.clock()
    if now-rebirthLastAction<1.5 then return info end
    local button=nil
    if rebirthStage==0 and info.rebirthButton and now-rebirthLastAction>20 then
        button=info.rebirthButton
    elseif rebirthStage==1 and now<rebirthStageDeadline and info.confirmButton then
        button=info.confirmButton
    end
    if button then
        local success,msg=attemptInteraction({obj=button})
        if success then
            rebirthLastAction=now
            if rebirthStage==0 then
                rebirthStage=1;rebirthStageDeadline=now+12
            else
                rebirthStage=0;rebirthStageDeadline=0
            end
            investorStatus=investorStatus..'\nIntento enviado: '..button.Text
        else
            investorStatus=investorStatus..'\nNo se pudo interactuar: '..msg
        end
        for _,label in ipairs(investorLabels) do
            if label and label.Parent then label.Text=investorStatus end
        end
    end
    if rebirthStage==1 and now>=rebirthStageDeadline then
        rebirthStage=0
        investorStatus=investorStatus..'\nConfirmación pendiente: revisa el menú.'
    end
    return info
end
investorProbe=function()
    updateInvestors(false)
    return investorStatus
end

-- La agrupación es solo espacial: no presupone nombres ni eventos privados.
local function recordIceRock(pos,now)
    for i=#NOVA_CORE.iceRockVisits,1,-1 do
        local v=NOVA_CORE.iceRockVisits[i]
        if now-v.at>=NOVA_CORE.ICE_GROUP_COOLDOWN then table.remove(NOVA_CORE.iceRockVisits,i)
        elseif (pos-v.position).Magnitude<=NOVA_CORE.ICE_GROUP_RADIUS then
            v.at=now
            return
        end
    end
    table.insert(NOVA_CORE.iceRockVisits,{position=pos,at=now})
    if #NOVA_CORE.iceRockVisits>120 then table.remove(NOVA_CORE.iceRockVisits,1) end
end
local function iceRockRecentlyVisited(pos,now)
    for _,v in ipairs(NOVA_CORE.iceRockVisits) do
        if now-v.at<NOVA_CORE.ICE_GROUP_COOLDOWN and (pos-v.position).Magnitude<=NOVA_CORE.ICE_GROUP_RADIUS then
            return true
        end
    end
    return false
end
local lastIceNotice=0
-- Intentos en lote únicamente sobre controles realmente alcanzables.
local function collectIceBatch()
    local root=rootPart()
    if not root or not state.ice then return 0 end
    local now=os.clock()
    local radius=NOVA_CORE.iceSearchMeters*NOVA_CORE.STUDS_PER_METER
    local options={}
    for _,hit in ipairs(hits.ice) do
        local obj,part=hit.obj,hit.part
        if obj and obj.Parent and part and part:IsDescendantOf(Workspace) then
            local d=(root.Position-part.Position).Magnitude
            if d<=radius and d<=allowedActivationDistance(obj)
                and now-(NOVA_CORE.lastAttempt[obj] or -1e9)>=NOVA_CORE.ICE_TARGET_DELAY then
                table.insert(options,{hit=hit,d=d})
            end
        end
    end
    table.sort(options,function(a,b)return a.d<b.d end)
    local sent=0
    for i=1,math.min(#options,state.iceBatch and NOVA_CORE.ICE_BATCH_LIMIT or 1) do
        if not running or not state.ice then break end
        local hit=options[i].hit
        local ok=attemptInteraction(hit,NOVA_CORE.ICE_TARGET_DELAY)
        if ok then
            sent=sent+1
            stats.iceAttempts=stats.iceAttempts+1
            recordIceRock(hit.part.Position,now)
        end
    end
    if sent>0 then
        stats.iceBatches=stats.iceBatches+1
        if NOVA_CORE.statusNotice and now-lastIceNotice>.8 then
            lastIceNotice=now
            NOVA_CORE.statusNotice(string.format('Hielo: %d intentos cercanos en lote (no confirmados)',sent))
        end
    end
    return sent
end
local function nextIceRock()
    local root=rootPart()
    if not root then return nil end
    local now=os.clock()
    local radius=NOVA_CORE.iceSearchMeters*NOVA_CORE.STUDS_PER_METER
    local best,bestDist=nil,math.huge
    for _,hit in ipairs(hits.ice) do
        local obj,part=hit.obj,hit.part
        if obj and obj.Parent and part and part:IsDescendantOf(Workspace) then
            local d=(root.Position-part.Position).Magnitude
            if d<=radius and d>math.max(4,allowedActivationDistance(obj))
                and not iceRockRecentlyVisited(part.Position,now)
                and now-(NOVA_CORE.teleportLog[obj] or -1e9)>=1.5 and d<bestDist then
                best,bestDist=hit,d
            end
        end
    end
    return best
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
    local name=NOVA_CORE.detectedWorld==1 and 'MUNDO 1' or (NOVA_CORE.detectedWorld==2 and 'MARTE' or 'SIN DETECTAR')
    worldBadge.Text=NOVA_CORE.detectedWorld==2 and 'MARTE' or (NOVA_CORE.detectedWorld==1 and 'TIERRA' or 'SIN DETECTAR')
    worldBadge.TextColor3=NOVA_CORE.detectedWorld==0 and COLOR.warning or COLOR.accent
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
            NOVA_CORE.detectedWorld=0
            detectedReason=reason
        end
        displayDetection()
        return
    end
    unknownCount=0
    if pendingWorld==candidate then pendingCount=pendingCount+1
    else pendingWorld,pendingCount=candidate,1 end
    if pendingCount>=2 then
        local changed=NOVA_CORE.detectedWorld~=candidate
        NOVA_CORE.detectedWorld,detectedReason=candidate,reason
        if changed and autoWorld then showPage(candidate==1 and 'World1' or 'World2') end
    end
    displayDetection()
end
autoButton.MouseButton1Click:Connect(function()
    autoWorld=not autoWorld
    if autoWorld and NOVA_CORE.detectedWorld~=0 then
        showPage(NOVA_CORE.detectedWorld==1 and 'World1' or 'World2')
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
    if not NOVA_CORE.startAnchor[NOVA_CORE.detectedWorld] then
        local ok,reason=NOVA_CORE.autoLocateStart()
        if not ok then NOVA_CORE.buyPendingHint=reason end
    end
    local saved=NOVA_CORE.startAnchor[NOVA_CORE.detectedWorld]
    local labelText=saved and
        ('Inicio: '..(NOVA_CORE.startAnchorMethod[NOVA_CORE.detectedWorld] or 'manual')
         ..' | radio '..NOVA_CORE.startRadius..' studs')
        or ('Sin inicio: '..(NOVA_CORE.buyPendingHint~='' and NOVA_CORE.buyPendingHint or 'marca en Build'))
    for _,label in ipairs(startAnchorLabels) do
        if label and label.Parent then label.Text=labelText end
    end
    updateHighlights()
    local f,i,c,u=#hits.fruit,#hits.ice,#hits.cash,#hits.buy
    scanStatus.Text=string.format('Candidatos próximos (125 studs):\nfruta %d | hielo %d | dinero %d | mejoras %d\nBotones UI de mejoras: %d',f,i,c,u,#guiUpgrades)
    detection.Text=string.format('Interacciones examinadas: %d\nClick API: %s | saltos: %d',stats.scanned,type(fireclickdetector)=='function' and 'disponible' or 'no disponible',NOVA_CORE.teleportCount)
    w1Status.Text=string.format('Fruta %d  |  dinero %d\nMejoras: %d físicas + %d UI',f,c,u,#guiUpgrades)
    local iceRadius=NOVA_CORE.iceSearchMeters*NOVA_CORE.STUDS_PER_METER
    local iceInSearch=candidate(hits.ice,iceRadius,false)
    local iceInReach=nearby(hits.ice,iceRadius)
    w2Status.Text=string.format('Hielo: %d  |  Radio: %d m\nMejoras visibles: %d',
        i,NOVA_CORE.iceSearchMeters,u+#guiUpgrades)
    for page,vals in pairs(dashboardStatLabels) do
        vals[1].Text=tostring(i)
        vals[2].Text=tostring(u+#guiUpgrades)
        vals[3].Text=tostring(NOVA_CORE.teleportCount)
        vals[4].Text=tostring(stats.attempts)
        dashboardScanMeta[page].Text=string.format('Hielo: %d   •   Mejoras: %d\nObjetos: %d   •   Intentos: %d',i,u+#guiUpgrades,stats.scanned,stats.attempts)
    end
    footer.Text=string.format('Hielo: %d  |  Mejoras: %d',i,u+#guiUpgrades)
end
local debugBox=section(db,'CONTROL Y ESTADO')
local lastStatus=statusText(debugBox,'Sin intentos',true)
NOVA_CORE.statusNotice=function(message) lastStatus.Text=message end
local radarBox=section(db,'VISUAL')
toggle(radarBox,'Resaltar objetivos detectados','radar')
local lastRefresh=0
local function doRefresh()
    refresh()
    lastRefresh=os.clock()
end
requestScan=doRefresh
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
    restore.Visible=true
    showPage('Tools')
end
hint.MouseButton1Click:Connect(function()tapSequence=tapSequence+1;finishTap()end)
action(scanBox,'TOCAR OBJETO EN EL MAPA',function()
    tapSequence=tapSequence+1
    local seq=tapSequence
    if tapConnection then tapConnection:Disconnect();tapConnection=nil end
    window.Visible=false
    restore.Visible=true
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
action(scanBox,'Comprobar precios e inversores',function()
    nextBuildTarget()
    local investors=investorProbe and investorProbe() or 'Sin datos de inversores'
    inspection.Text=budgetMessage..'\n'..investors
end)
action(scanBox,'Ver 5 precios más baratos',function()
    local money,ordered=pricedBuildQueue()
    if not money then
        inspection.Text='Saldo no reconocido. Abre tu tycoon y vuelve a escanear.'
        return
    end
    if #ordered==0 then
        inspection.Text='Sin plataformas pagables con precio reconocido.'
        return
    end
    local rows={'Saldo: '..tostring(money.label),'Orden: menor precio -> mayor precio'}
    for i=1,math.min(5,#ordered) do
        local item=ordered[i]
        table.insert(rows,string.format('%d. %s | %s | %.0f studs',
            i,tostring(item.price.label),item.hit.part and item.hit.part.Name or '?',item.d))
    end
    inspection.Text=table.concat(rows,'\n')
end)
action(scanBox,'Resaltar próxima plataforma',function()
    local hit=nextBuildTarget()
    if not hit or not hit.part then
        inspection.Text='No hay una plataforma pagable y elegible en la zona actual.'
        return
    end
    local pad=hit.part
    local price,reason=upgradeCost(hit)
    local ownerStatus=plotOwnedByPlayer(pad)
    local ownerText=ownerStatus==true and 'Mi parcela (confirmado)'
        or (ownerStatus==false and 'Parcela ajena' or 'Propietario no identificado')
    local h=Instance.new('Highlight')
    h.Name='NOVA_NEXT_BUY_DEBUG'
    h.Adornee=pad
    h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    h.FillColor=COLOR.warning
    h.OutlineColor=COLOR.accent
    h.FillTransparency=.7
    h.Parent=pad
    task.delay(10,function() if h.Parent then h:Destroy() end end)
    inspection.Text=string.format(
        'Próximo botón: %s\nTipo: %s\nCosto: %s\nDistancia: %.0f studs\n%s\nRuta: %s',
        pad.Name,hit.obj.ClassName,price and price.label or tostring(reason),
        distance(pad),ownerText,NOVA_CORE.buyLastReason)
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
    if NOVA_CORE.detectedWorld~=2 then if NOVA_CORE.statusNotice then NOVA_CORE.statusNotice('Prueba disponible en Marte') end return end
    local hit=candidate(hits.ice,NOVA_CORE.iceSearchMeters*NOVA_CORE.STUDS_PER_METER,false)
    if not hit then if NOVA_CORE.statusNotice then NOVA_CORE.statusNotice('No hay roca compatible en el radio') end return end
    if not repositionNear(hit,'Prueba: roca con hielo',false) and NOVA_CORE.statusNotice then
        NOVA_CORE.statusNotice('No se pudo saltar: objetivo o límite de espera')
    end
end)
action(scanBox,'Probar mejora cercana',function()
    local hit=nearby(hits.buy)
    if hit and (hit.obj:IsA('ClickDetector') or hit.obj:IsA('ProximityPrompt')) then
        local _,msg=attemptInteraction(hit)
        if NOVA_CORE.statusNotice then NOVA_CORE.statusNotice('Mejora física: '..msg) end
    elseif #guiUpgrades>0 then
        local _,msg=attemptInteraction(guiUpgrades[1])
        if NOVA_CORE.statusNotice then NOVA_CORE.statusNotice('Mejora UI: '..msg) end
    elseif NOVA_CORE.statusNotice then
        NOVA_CORE.statusNotice('Sin botón compatible; abre Manage y vuelve a escanear')
    end
end)
action(debugBox,'Volver a posición guardada',function()
    local char=player.Character
    if not NOVA_CORE.savedPosition or not char then lastStatus.Text='No hay posición guardada';return end
    local ok=pcall(function() char:PivotTo(NOVA_CORE.savedPosition) end)
    if NOVA_CORE.statusNotice then NOVA_CORE.statusNotice(ok and 'Regreso solicitado' or 'Regreso fallido') end
    if ok then NOVA_CORE.savedPosition=nil end
end)
action(debugBox,'Detener funciones',function()
    for k in pairs(state) do if k~='needed' and k~='cheapFirst' then state[k]=false end end
    for _,draws in pairs(NOVA_CORE.switches) do
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
close.MouseButton1Click:Connect(function() window.Visible=false end)
min.MouseButton1Click:Connect(function()
    window.Visible=false
end)
-- Un toque en N abre/cierra. Dos rápidos recuperan 100% y muestran NOVA.
local lastNPress=-1e9
restore.MouseButton1Click:Connect(function()
    local now=os.clock()
    if now-lastNPress<.40 then
        if resetUiScale then resetUiScale() end
        window.Visible=true
        lastNPress=-1e9
    else
        window.Visible=not window.Visible
        lastNPress=now
    end
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
        local elapsed=math.floor(os.clock()-startTime)
        timeValue.Text=string.format('%02d:%02d',math.floor(elapsed/60),elapsed%60)
        local buildActive=(NOVA_CORE.detectedWorld==1 and (state.buy or state.autoStations))
            or (NOVA_CORE.detectedWorld==2 and (state.buyMars or state.autoStations))
        if buildActive and not NOVA_CORE.buyWasActive then
            local position=rootPart()
            if position then
                NOVA_CORE.buyAreaOrigin=position.Position
                NOVA_CORE.buyAreaWorld=NOVA_CORE.detectedWorld
            end
            NOVA_CORE.buyCooldown={} -- nueva sesión de compras
            NOVA_CORE.buyFailCounts={}
        end
        NOVA_CORE.buyWasActive=buildActive
        if os.clock()-lastRefresh>(buildActive and 1.05 or (NOVA_CORE.detectedWorld==2 and state.ice and 2.5 or 9)) then doRefresh() end
        if os.clock()-lastInvestorRefresh>=1.25 then
            lastInvestorRefresh=os.clock()
            if NOVA_CORE.detectedWorld==1 or state.autoRebirth then updateInvestors(true) end
        end
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
            local matchesWorld=(NOVA_CORE.detectedWorld==1 and rule.key~='ice' and rule.key~='buyMars')
                or (NOVA_CORE.detectedWorld==2 and (rule.key=='ice' or rule.key=='buyMars' or rule.key=='autoStations'))
            if state[rule.key] and matchesWorld then
                local isIce=rule.key=='ice'
                local isBuy=rule.key=='buy' or rule.key=='buyMars' or rule.key=='autoStations'
                local iceRadius=NOVA_CORE.iceSearchMeters*NOVA_CORE.STUDS_PER_METER
                local h=nearby(hits[rule.bucket],isIce and iceRadius or NOVA_CORE.MAX_RANGE)
                if isBuy then
                    -- One zone-aware purchase routine; no global competing selector.
                    runAutoUpgrades()
                elseif isIce then
                    local sent=collectIceBatch()
                    local elapsed=os.clock()-NOVA_CORE.lastIceMoveAt
                    if state.iceTeleport and not (state.buyTeleport and buildActive)
                        and elapsed>=NOVA_CORE.ICE_MIN_DWELL
                        and (sent==0 or elapsed>=NOVA_CORE.ICE_MAX_DWELL) then
                        local far=nextIceRock()
                        if far then repositionNear(far,'Siguiente roca',false) end
                    end
                elseif h then
                    local _,msg=attemptInteraction(h)
                    if NOVA_CORE.statusNotice then NOVA_CORE.statusNotice(rule.key..': '..msg) end
                end
            end
        end
        footer.Text=string.format('Hielo: %d  |  Mejoras: %d',
            #hits.ice,#hits.buy+#guiUpgrades)
        if remoteBuyCaption then remoteBuyCaption.Text='TP por zonas: 1 mejora por vez' end
        if os.clock()-lastBudgetRefresh>1.25 then
            lastBudgetRefresh=os.clock()
            if not buildActive then
                local wallet=walletMoney()
                budgetMessage=wallet and ('Saldo: '..wallet.label..' | AUTO PROGRESO apagado')
                    or 'Saldo no reconocido | AUTO PROGRESO apagado'
            end
            for _,v in ipairs(budgetLabels) do
                if v and v.Parent then v.Text=budgetMessage end
            end
        end
        for page,vals in pairs(dashboardStatLabels) do
            vals[1].Text=tostring(#hits.ice)
            vals[2].Text=tostring(#hits.buy+#guiUpgrades)
            vals[3].Text=tostring(NOVA_CORE.teleportCount)
            vals[4].Text=tostring(stats.attempts)
        end
        task.wait(buildActive and .30 or (NOVA_CORE.detectedWorld==2 and state.ice and .18 or .7))
    end
end)
