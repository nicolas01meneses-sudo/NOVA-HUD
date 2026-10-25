-- NOVA HUD 4.4 NEON — ice rock reposition, mobile slider and upgrade diagnostics
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
for _,oldName in ipairs({'NOVA_HUD_3_1','NOVA_HUD_3_2','NOVA_HUD_3_3','NOVA_HUD_3_4','NOVA_HUD_3_5','NOVA_HUD_3_6','NOVA_HUD_3_7','NOVA_HUD_3_8','NOVA_HUD_3_9','NOVA_HUD_4_0_NEON','NOVA_HUD_4_1_NEON','NOVA_HUD_4_2_NEON','NOVA_HUD_4_3_NEON','NOVA_HUD_4_4_NEON'}) do
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

local state={fruit=false,ice=false,cash=false,buy=false,buyMars=false,needed=true,radar=false,iceTeleport=false,buyTeleport=false,cheapFirst=true,iceBatch=true,autoRebirth=false,bulkBuy=true,remoteBuy=true}
local running=true
local MAX_RANGE=14 -- fallback interaction distance, measured in studs
local STUDS_PER_METER=1/0.28 -- approximate Roblox unit conversion
local iceSearchMeters=350 -- adjustable range in the HUD; server interaction limits still apply
local DELAY=1.5
-- Lotes de hielo: interacciones independientes, con intervalos moderados.
local ICE_TARGET_DELAY=.85       -- por fragmento, no por lote
local ICE_BATCH_LIMIT=6          -- hasta seis objetivos distintos por vuelta
local ICE_GROUP_RADIUS=12        -- studs, para identificar la misma roca
local ICE_GROUP_COOLDOWN=7       -- segundos antes de repetir roca
local ICE_MOVE_INTERVAL=.65
local ICE_MIN_DWELL=.75
local ICE_MAX_DWELL=1.35
local buildMoveDelay=1.0
local batchSize=5 -- 1..8 solicitudes por ciclo, sólo interfaces que el cliente reconoce
local BATCH_INTERACTION_DELAY=.22
local lastBatchRun=-1e9
local remoteBuyAttempts=0
local batchAttempts=0
local latestBatchStatus='No se han enviado compras rápidas'
local BUILD_RETRY_COOLDOWN=4.5
local BUY_SEARCH_STUDS=6000
local stats={attempts=0, errors=0, scanned=0, notices=0,iceAttempts=0,iceBatches=0,iceRocks=0}
local hits={fruit={},ice={},cash={},buy={}}
local guiUpgrades={} -- regular visible upgrade GUI buttons, not remote events
local lastMoveAt=0
local lastBuildMoveAt=0
local lastIceMoveAt=0
local buildHops=0
local teleportLog={}
local iceRockVisits={} -- zonas recientemente exploradas
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
    Name='NOVA_HUD_4_4_NEON',ResetOnSpawn=false,DisplayOrder=105,
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
local version=textLabel(top,'v4.4 - SELL LEMONS',12,true,COLOR.muted)
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
local bottomBrand=textLabel(bottom,'NOVA v4.4 NEON • SELL LEMONS',11,true,COLOR.accent)
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
    if not switches[key] then switches[key]={} end
    table.insert(switches[key],render);render()
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
        local t=(iceSearchMeters-20)/1480
        fill.Size=UDim2.fromScale(t,1)
        knob.Position=UDim2.fromScale(t,.5)
        value.Text=string.format('%d m',iceSearchMeters)
    end
    local function setFromX(x)
        local t=math.clamp((x-track.AbsolutePosition.X)/math.max(1,track.AbsoluteSize.X),0,1)
        iceSearchMeters=math.clamp(math.floor((20+t*1480)/10+.5)*10,20,1500)
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
    local caption=textLabel(panel,'PAUSA ENTRE COMPRAS',11,true,COLOR.muted)
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

local w1Status,w2Status
local budgetLabels={} -- estado compacto en dos mundos
local buildActionButtons={} -- botones principales, sincronizados con switches
local buildBatchStatusLabels={}
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
local quickBuyEarth=roundedButton(cBuild,'AUTO MEJORAS: OFF',COLOR.nav,UDim2.new(1,0,0,44))
quickBuyEarth.TextColor3=COLOR.accent;outline(quickBuyEarth)
table.insert(buildActionButtons,{button=quickBuyEarth,world=1})
toggle(cBuild,'Comprar mejoras automáticamente','buy')
toggle(cBuild,'Compra rápida por lotes','bulkBuy')
toggle(cBuild,'Remote Buy si está desbloqueado','remoteBuy')
toggle(cBuild,'Omitir botones invisibles','needed')
toggle(cBuild,'Ir a plataformas (experimental)','buyTeleport')
toggle(cBuild,'Más baratas primero','cheapFirst')
addBuildSpeed(cBuild)
statusText(cBuild,'Prioridad: precio bajo. Lotes de hasta 5 por ciclo.',true)
table.insert(budgetLabels,statusText(cBuild,'Saldo: sin leer | 0 pagables',true))
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
local quickBuyMars=roundedButton(upgradeBox,'AUTO MEJORAS: OFF',COLOR.nav,UDim2.new(1,0,0,44))
quickBuyMars.TextColor3=COLOR.accent;outline(quickBuyMars)
table.insert(buildActionButtons,{button=quickBuyMars,world=2})
toggle(upgradeBox,'Comprar mejoras automáticamente','buyMars')
toggle(upgradeBox,'Compra rápida por lotes','bulkBuy')
toggle(upgradeBox,'Remote Buy si está desbloqueado','remoteBuy')
toggle(upgradeBox,'Ir a plataformas (experimental)','buyTeleport')
toggle(upgradeBox,'Más baratas primero','cheapFirst')
addBuildSpeed(upgradeBox)
statusText(upgradeBox,'Compras rápidas: solo precios reconocidos.',true)
table.insert(budgetLabels,statusText(upgradeBox,'Saldo: sin leer | 0 pagables',true))

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
statusText(buildIntro,'Elige tu mundo. El modo rápido intenta varias mejoras asequibles sin comprar artículos premium.',true)
local buildWorld1=roundedButton(buildIntro,'🍋  ABRIR AUTO BUILD TIERRA',COLOR.card,UDim2.new(1,0,0,46))
buildWorld1.TextColor3=COLOR.accent;outline(buildWorld1)
buildWorld1.MouseButton1Click:Connect(function() showPage('World1') end)
local buildWorld2=roundedButton(buildIntro,'◈  ABRIR AUTO BUILD MARTE',COLOR.card,UDim2.new(1,0,0,46))
buildWorld2.TextColor3=COLOR.accent;outline(buildWorld2)
buildWorld2.MouseButton1Click:Connect(function() showPage('World2') end)
local buildFastPanel=section(buildL,'COMPRA RÁPIDA')
local batchSizeLabel=statusText(buildFastPanel,'Lote: 5 intentos por ciclo',false)
local batchSizeView=roundedButton(buildFastPanel,'AJUSTAR LOTE (1 A 8)',COLOR.card,UDim2.new(1,0,0,42))
outline(batchSizeView)
local function changeBatchSize()
    batchSize=batchSize+1
    if batchSize>8 then batchSize=1 end
    batchSizeLabel.Text='Lote: '..batchSize..' intentos por ciclo'
end
batchSizeView.MouseButton1Click:Connect(changeBatchSize)
toggle(buildFastPanel,'Compra rápida por lotes','bulkBuy')
toggle(buildFastPanel,'Remote Buy si está desbloqueado','remoteBuy')
statusText(buildFastPanel,'Sin Remote Buy, las plataformas lejanas se recorren una tras otra.',true)
local buildTips=section(buildR,'ESTADO DE COMPRAS')
local buildGuide=statusText(buildTips,'Abre un mundo para activar Auto Mejoras. Los intentos no son compras confirmadas.',true)
local batchStatusView=statusText(buildTips,'Lotes: sin intentos todavía',true)
table.insert(buildBatchStatusLabels,batchStatusView)
remoteBuyCaption=statusText(buildTips,'Remote Buy: no comprobado',true)
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
    for _,draws in pairs(switches) do
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
local preview=section(visualR,'NOVA NEON v4.4')
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
statusText(configInfo,'NOVA v4.4 NEON\nInterfaz optimizada para móvil.\nLas estadísticas registran intentos, no recompensas confirmadas.',true)
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
 local c=detectedWorld==2 and 'Φ' or '$'
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
local function cheaper(a,b)
 return a.rank<b.rank or (a.rank==b.rank and a.n<b.n)
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
                    local closeEnough=host==playerGui or (hostPart and hostPart:IsA('BasePart') and distance(hostPart)<=BUY_SEARCH_STUDS)
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
    local value=amountFromText((detectedWorld==2 and 'Φ' or '$')..number..' '..unit)
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
    local obj=hit.obj
    local scopes={}
    local function add(scope)
        if scope and not table.find(scopes,scope) then table.insert(scopes,scope) end
    end
    add(obj)
    if obj:IsA('GuiButton') then add(obj.Parent) end
    if hit.part then
        add(hit.part)
        add(hit.part.Parent)
        local model=hit.part:FindFirstAncestorOfClass('Model')
        if model then add(model) end
    end
    local lastReason='sin precio'
    for _,scope in ipairs(scopes) do
        local value,why=uniqueScopePrice(scope,scope==hit.part and 65 or 100)
        if value then return value,why end
        if why=='varios precios distintos' then return nil,why end
        lastReason=why or lastReason
    end
    return nil,lastReason
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
                if part and distance(part)<=math.max(125,BUY_SEARCH_STUDS,iceSearchMeters*STUDS_PER_METER)
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
local budgetMessage='Saldo no identificado'
local lastBudgetMessage=0
local lastBudgetRefresh=0
local buildSummary={wallet=nil,next=nil,nextPrice=nil,priced=0,payable=0,unknown=0,unaffordable=0}
local function nextBuildTarget()
    local now=os.clock()
    local wallet=walletMoney()
    local summary={wallet=wallet,next=nil,nextPrice=nil,priced=0,payable=0,unknown=0,unaffordable=0}
    if not wallet then
        budgetMessage='Saldo sin leer | compras pausadas'
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
            if not part or not part:IsDescendantOf(Workspace) or d>BUY_SEARCH_STUDS then return end
            if state.needed and part.Transparency>.85 then return end
        end
        -- El precio cambia despues de las mejoras. Se revalida cada ~1 s.
        if not hit.priceReadAt or now-hit.priceReadAt>1 then
            hit.price,hit.priceReason=upgradeCost(hit)
            hit.priceReadAt=now
        end
        local price=hit.price
        if not price then summary.unknown=summary.unknown+1;return end
        summary.priced=summary.priced+1
        if cheaper(wallet,price) then summary.unaffordable=summary.unaffordable+1;return end
        summary.payable=summary.payable+1
        if not isGui and d>allowedActivationDistance(obj) and not state.buyTeleport then return end
        if not isGui and now-(teleportLog[obj] or -1e9)<BUILD_RETRY_COOLDOWN then return end
        if isGui and now-(lastAttempt[obj] or -1e9)<DELAY then return end
        if not best or
            (state.cheapFirst and (cheaper(price,bestPrice)
            or (not cheaper(bestPrice,price) and d<bestDistance)))
            or (not state.cheapFirst and d<bestDistance) then
            best,bestPrice,bestDistance=hit,price,d
        end
    end
    for _,hit in ipairs(hits.buy) do tryCandidate(hit) end
    for _,hit in ipairs(guiUpgrades) do tryCandidate(hit) end
    summary.next=best
    summary.nextPrice=bestPrice
    buildSummary=summary
    local nextText=bestPrice and bestPrice.label or 'ninguna'
    budgetMessage=string.format('Saldo: %s | Pagables: %d\nSiguiente: %s',
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
            if not hasAny(combined,BAD_PURCHASE) and
                (hasAny(path,{'remotebuy','remote_buy','remote buy'})
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
        button.Text=on and 'AUTO MEJORAS: ON' or 'AUTO MEJORAS: OFF'
        button.BackgroundColor3=on and Color3.fromRGB(0,70,92) or COLOR.nav
        button.TextColor3=on and COLOR.success or COLOR.accent
    end
    if not switches[key] then switches[key]={} end
    table.insert(switches[key],paint)
    paint()
    button.MouseButton1Click:Connect(function()
        state[key]=not state[key]
        if state[key] then
            state[entry.world==1 and 'buyMars' or 'buy']=false
        end
        for _,name in ipairs({'buy','buyMars'}) do
            for _,draw in ipairs(switches[name] or {}) do draw() end
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
    local delay=isPurchase and buildMoveDelay or ICE_MOVE_INTERVAL
    local previous=isPurchase and lastBuildMoveAt or lastIceMoveAt
    local revisit=isPurchase and BUILD_RETRY_COOLDOWN or 1.5
    if now-lastMoveAt<.25 or now-previous<delay or now-(teleportLog[hit.obj] or -1e9)<revisit then return false end
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
    if isPurchase then
        buildHops=buildHops+1
    else
        stats.iceRocks=stats.iceRocks+1
        table.insert(iceRockVisits,{position=part.Position,at=now})
    end
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
local function attemptInteraction(hit,perTargetDelay)
    if not hit then return false,'Sin objetivos cercanos' end
    local obj=hit.obj
    if os.clock()-(lastAttempt[obj] or -1e9)<(perTargetDelay or DELAY) then return false,'En espera' end
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
    if not wallet then return nil,{} end
    local now=os.clock()
    local result,seen={},{}
    local function add(hit)
        local obj=hit.obj
        if not obj or not obj.Parent or seen[obj] then return end
        local part=hit.part
        local guiButton=obj:IsA('GuiButton')
        if guiButton then
            if not isVisibleGui(obj) then return end
        elseif not part or not part:IsDescendantOf(Workspace)
            or distance(part)>BUY_SEARCH_STUDS
            or (state.needed and part.Transparency>.85) then return end
        if not hit.priceReadAt or now-hit.priceReadAt>1 then
            hit.price,hit.priceReason=upgradeCost(hit)
            hit.priceReadAt=now
        end
        local price=hit.price
        if not price or cheaper(wallet,price) then return end
        local d=part and distance(part) or 0
        if not guiButton and d>allowedActivationDistance(obj) and not state.buyTeleport then return end
        if not guiButton and now-(teleportLog[obj] or -1e9)<BUILD_RETRY_COOLDOWN then return end
        if guiButton and now-(lastAttempt[obj] or -1e9)<BATCH_INTERACTION_DELAY then return end
        seen[obj]=true
        table.insert(result,{hit=hit,price=price,d=d})
    end
    for _,hit in ipairs(hits.buy) do add(hit) end
    for _,hit in ipairs(guiUpgrades) do add(hit) end
    table.sort(result,function(a,b)
        if state.cheapFirst then
            if cheaper(a.price,b.price) then return true end
            if cheaper(b.price,a.price) then return false end
        end
        return a.d<b.d
    end)
    return wallet,result
end

local function showBatchStatus(message)
    latestBatchStatus=message
    for _,label in ipairs(buildBatchStatusLabels) do
        if label and label.Parent then label.Text=message end
    end
end
local lastRemoteLabelUpdate=-1e9
local function runAutoUpgrades()
    local now=os.clock()
    if now-lastBatchRun<.30 then return end
    lastBatchRun=now
    local maxToAttempt=state.bulkBuy and batchSize or 1
    if state.remoteBuy then
        local remote=refreshOfficialRemoteBuy()
        if remote then
            if remoteBuyCaption and now-lastRemoteLabelUpdate>.9 then
                lastRemoteLabelUpdate=now
                remoteBuyCaption.Text='Remote Buy: botón oficial disponible'
            end
            -- El juego decide qué comprar con su poder desbloqueado.
            local sent=0
            for i=1,maxToAttempt do
                if not running or not (state.buy or state.buyMars) then break end
                local ok,msg=attemptInteraction(remote,BATCH_INTERACTION_DELAY)
                if not ok then
                    if msg~='En espera' then
                        showBatchStatus('Remote Buy no disponible: '..msg)
                    end
                    break
                end
                sent=sent+1
                remoteBuyAttempts=remoteBuyAttempts+1
                -- Se evita enviar múltiples pulsaciones en el mismo fotograma.
                task.wait(.23)
                if not remote.obj or not remote.obj.Parent or not isVisibleGui(remote.obj) then break end
            end
            if sent>0 then
                batchAttempts=batchAttempts+sent
                showBatchStatus('Remote Buy: '..sent..' intentos enviados (no confirmados)')
                return
            end
        elseif remoteBuyCaption and now-lastRemoteLabelUpdate>1 then
            lastRemoteLabelUpdate=now
            remoteBuyCaption.Text='Remote Buy: no está visible/desbloqueado'
        end
    end

    -- Si el jugador no tiene Remote Buy, se intentan varios controles
    -- distintos y alcanzables; las plataformas lejanas exigen desplazamiento.
    local available,ordered=pricedBuildQueue()
    if not available then
        showBatchStatus('Compras pausadas: el saldo no se pudo leer')
        return
    end
    local remaining=available
    local sent,moved,unsupported=0,false,0
    for _,entry in ipairs(ordered) do
        if sent>=maxToAttempt or not running then break end
        local cost=entry.price
        if not cheaper(remaining,cost) then
            local hit=entry.hit
            local obj=hit.obj
            local part=hit.part
            local near=part and distance(part)<=allowedActivationDistance(obj)
            if obj:IsA('GuiButton') or
                ((obj:IsA('ClickDetector') or obj:IsA('ProximityPrompt')) and near) then
                local ok,msg=attemptInteraction(hit,BATCH_INTERACTION_DELAY)
                if ok then
                    sent=sent+1
                    local newBalance=subtractBudget(remaining,cost)
                    if newBalance then remaining=newBalance end
                    task.wait(.11)
                elseif msg~='En espera' then
                    unsupported=unsupported+1
                end
            elseif part and state.buyTeleport then
                if repositionNear(hit,'Plataforma pagable',true) then
                    moved=true
                    break -- un desplazamiento por ciclo; no teletransportes simultáneos
                end
            else
                unsupported=unsupported+1
            end
        end
    end
    if sent>0 then batchAttempts=batchAttempts+sent end
    if sent>0 or moved then
        showBatchStatus('Lote: '..sent..' intentos | cambio de plataforma: '..(moved and 'sí' or 'no'))
    elseif unsupported>0 then
        showBatchStatus('Mejoras visibles, pero sin interacción alcanzable ('..unsupported..')')
    else
        showBatchStatus('Sin mejoras pagables al alcance; revisa el escáner')
    end
end

-- Evaluación prudente del menú de inversores. No obtiene datos privados
-- ni invoca remotes desconocidos: sólo lee texto visible y botones de la UI.
local function investorValue(t)
    if type(t)~='string' then return nil end
    local number,unit=t:match('([%d][%d%.,]*)%s*([^%s]*)')
    if not number then return nil end
    unit=(unit or ''):lower():gsub('^[%p]+',''):gsub('[%p]+$','')
    if hasAny(unit,{'investor','inversor'}) then unit='' end
    if moneyUnits[unit]==nil then return nil end
    return amountFromText((detectedWorld==2 and 'Φ' or '$')..number..' '..unit)
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
    if detectedWorld~=1 then
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
    if not allowAction or not state.autoRebirth or detectedWorld~=1
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
    for i=#iceRockVisits,1,-1 do
        local v=iceRockVisits[i]
        if now-v.at>=ICE_GROUP_COOLDOWN then table.remove(iceRockVisits,i)
        elseif (pos-v.position).Magnitude<=ICE_GROUP_RADIUS then
            v.at=now
            return
        end
    end
    table.insert(iceRockVisits,{position=pos,at=now})
    if #iceRockVisits>120 then table.remove(iceRockVisits,1) end
end
local function iceRockRecentlyVisited(pos,now)
    for _,v in ipairs(iceRockVisits) do
        if now-v.at<ICE_GROUP_COOLDOWN and (pos-v.position).Magnitude<=ICE_GROUP_RADIUS then
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
    local radius=iceSearchMeters*STUDS_PER_METER
    local options={}
    for _,hit in ipairs(hits.ice) do
        local obj,part=hit.obj,hit.part
        if obj and obj.Parent and part and part:IsDescendantOf(Workspace) then
            local d=(root.Position-part.Position).Magnitude
            if d<=radius and d<=allowedActivationDistance(obj)
                and now-(lastAttempt[obj] or -1e9)>=ICE_TARGET_DELAY then
                table.insert(options,{hit=hit,d=d})
            end
        end
    end
    table.sort(options,function(a,b)return a.d<b.d end)
    local sent=0
    for i=1,math.min(#options,state.iceBatch and ICE_BATCH_LIMIT or 1) do
        if not running or not state.ice then break end
        local hit=options[i].hit
        local ok=attemptInteraction(hit,ICE_TARGET_DELAY)
        if ok then
            sent=sent+1
            stats.iceAttempts=stats.iceAttempts+1
            recordIceRock(hit.part.Position,now)
        end
    end
    if sent>0 then
        stats.iceBatches=stats.iceBatches+1
        if statusNotice and now-lastIceNotice>.8 then
            lastIceNotice=now
            statusNotice(string.format('Hielo: %d intentos cercanos en lote (no confirmados)',sent))
        end
    end
    return sent
end
local function nextIceRock()
    local root=rootPart()
    if not root then return nil end
    local now=os.clock()
    local radius=iceSearchMeters*STUDS_PER_METER
    local best,bestDist=nil,math.huge
    for _,hit in ipairs(hits.ice) do
        local obj,part=hit.obj,hit.part
        if obj and obj.Parent and part and part:IsDescendantOf(Workspace) then
            local d=(root.Position-part.Position).Magnitude
            if d<=radius and d>math.max(4,allowedActivationDistance(obj))
                and not iceRockRecentlyVisited(part.Position,now)
                and now-(teleportLog[obj] or -1e9)>=1.5 and d<bestDist then
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
    local name=detectedWorld==1 and 'MUNDO 1' or (detectedWorld==2 and 'MARTE' or 'SIN DETECTAR')
    worldBadge.Text=detectedWorld==2 and 'MARTE' or (detectedWorld==1 and 'TIERRA' or 'SIN DETECTAR')
    worldBadge.TextColor3=detectedWorld==0 and COLOR.warning or COLOR.accent
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
    for page,vals in pairs(dashboardStatLabels) do
        vals[1].Text=tostring(i)
        vals[2].Text=tostring(u+#guiUpgrades)
        vals[3].Text=tostring(teleportCount)
        vals[4].Text=tostring(stats.attempts)
        dashboardScanMeta[page].Text=string.format('Hielo: %d   •   Mejoras: %d\nObjetos: %d   •   Intentos: %d',i,u+#guiUpgrades,stats.scanned,stats.attempts)
    end
    footer.Text=string.format('Hielo: %d  |  Mejoras: %d',i,u+#guiUpgrades)
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
    for k in pairs(state) do if k~='needed' and k~='cheapFirst' then state[k]=false end end
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
        local buildActive=(detectedWorld==1 and state.buy) or (detectedWorld==2 and state.buyMars)
        if os.clock()-lastRefresh>(buildActive and 1.7 or (detectedWorld==2 and state.ice and 2.5 or 9)) then doRefresh() end
        if os.clock()-lastInvestorRefresh>=1.25 then
            lastInvestorRefresh=os.clock()
            if detectedWorld==1 or state.autoRebirth then updateInvestors(true) end
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
            local matchesWorld=(detectedWorld==1 and rule.key~='ice' and rule.key~='buyMars')
                or (detectedWorld==2 and (rule.key=='ice' or rule.key=='buyMars'))
            if state[rule.key] and matchesWorld then
                local isIce=rule.key=='ice'
                local isBuy=rule.key=='buy' or rule.key=='buyMars'
                local iceRadius=iceSearchMeters*STUDS_PER_METER
                local h=nearby(hits[rule.bucket],isIce and iceRadius or MAX_RANGE)
                if isBuy then
                    -- El botón AUTO MEJORAS ejecuta lotes reales de intentos
                    -- y prioriza el poder Remote Buy cuando el jugador lo posee.
                    nextBuildTarget() -- mantiene saldo/diagnóstico actualizados
                    runAutoUpgrades()
                elseif isIce then
                    local sent=collectIceBatch()
                    local elapsed=os.clock()-lastIceMoveAt
                    if state.iceTeleport and not (state.buyTeleport and buildActive)
                        and elapsed>=ICE_MIN_DWELL
                        and (sent==0 or elapsed>=ICE_MAX_DWELL) then
                        local far=nextIceRock()
                        if far then repositionNear(far,'Siguiente roca',false) end
                    end
                elseif h then
                    local _,msg=attemptInteraction(h)
                    if statusNotice then statusNotice(rule.key..': '..msg) end
                end
            end
        end
        footer.Text=string.format('Hielo: %d  |  Mejoras: %d',
            #hits.ice,#hits.buy+#guiUpgrades)
        if os.clock()-lastBudgetRefresh>1.25 then
            lastBudgetRefresh=os.clock()
            if not buildActive then nextBuildTarget() end
            for _,v in ipairs(budgetLabels) do
                if v and v.Parent then v.Text=budgetMessage end
            end
        end
        for page,vals in pairs(dashboardStatLabels) do
            vals[1].Text=tostring(#hits.ice)
            vals[2].Text=tostring(#hits.buy+#guiUpgrades)
            vals[3].Text=tostring(teleportCount)
            vals[4].Text=tostring(stats.attempts)
        end
        task.wait(buildActive and .30 or (detectedWorld==2 and state.ice and .18 or .7))
    end
end)
