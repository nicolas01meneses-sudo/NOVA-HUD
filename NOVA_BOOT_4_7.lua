-- NOVA HUD 4.7 - cargador con diagnóstico de inicio (Luau)
-- Si la descarga, compilación o ejecución falla, muestra el motivo en pantalla.
local URL="https://raw.githubusercontent.com/nicolas01meneses-sudo/NOVA-HUD/main/NOVA_HUD_4_7_NEON.lua"
local function report(stage,err)
    local msg=tostring(err or "Error desconocido")
    warn("[NOVA 4.7 / "..stage.."] "..msg)
    pcall(function()
        local players=game:GetService("Players")
        local player=players.LocalPlayer
        if not player then return end
        local playerGui=player:WaitForChild("PlayerGui")
        local before=playerGui:FindFirstChild("NOVA_STARTUP_ERROR")
        if before then before:Destroy() end
        local ui=Instance.new("ScreenGui")
        ui.Name="NOVA_STARTUP_ERROR"
        ui.ResetOnSpawn=false
        ui.DisplayOrder=1100
        ui.Parent=playerGui
        local bg=Instance.new("Frame")
        bg.AnchorPoint=Vector2.new(.5,.5)
        bg.Position=UDim2.fromScale(.5,.5)
        bg.Size=UDim2.new(.86,0,0,154)
        bg.BackgroundColor3=Color3.fromRGB(9,15,30)
        bg.Parent=ui
        local corner=Instance.new("UICorner")
        corner.CornerRadius=UDim.new(0,12)
        corner.Parent=bg
        local border=Instance.new("UIStroke")
        border.Color=Color3.fromRGB(0,220,255)
        border.Thickness=2
        border.Parent=bg
        local title=Instance.new("TextLabel")
        title.BackgroundTransparency=1
        title.Position=UDim2.fromOffset(14,8)
        title.Size=UDim2.new(1,-70,0,28)
        title.Text="NOVA 4.7 - ERROR DE "..stage:upper()
        title.Font=Enum.Font.GothamBold
        title.TextColor3=Color3.fromRGB(0,220,255)
        title.TextSize=17
        title.TextXAlignment=Enum.TextXAlignment.Left
        title.Parent=bg
        local info=Instance.new("TextLabel")
        info.BackgroundTransparency=1
        info.Position=UDim2.fromOffset(14,43)
        info.Size=UDim2.new(1,-28,1,-53)
        info.Text=msg:sub(1,650)
        info.TextWrapped=true
        info.TextYAlignment=Enum.TextYAlignment.Top
        info.Font=Enum.Font.Code
        info.TextColor3=Color3.fromRGB(240,245,255)
        info.TextSize=12
        info.Parent=bg
        local close=Instance.new("TextButton")
        close.Position=UDim2.new(1,-43,0,9)
        close.Size=UDim2.fromOffset(33,28)
        close.BackgroundColor3=Color3.fromRGB(42,45,65)
        close.Text="X"
        close.Font=Enum.Font.GothamBold
        close.TextSize=16
        close.TextColor3=Color3.fromRGB(255,105,135)
        close.Parent=bg
        close.MouseButton1Click:Connect(function() ui:Destroy() end)
    end)
end
local downloaded,source=pcall(function() return game:HttpGet(URL) end)
if not downloaded then
    report("descarga",source)
    return
end
local valid,compiled,compileError=pcall(function()
    local executable,syntaxError=loadstring(source)
    return executable,syntaxError
end)
if not valid then
    report("compilacion",compiled)
    return
end
if type(compiled)~="function" then
    report("compilacion",compileError or "loadstring no devolvió una función")
    return
end
local executed,errorMessage=pcall(compiled)
if not executed then
    report("ejecucion",errorMessage)
end
