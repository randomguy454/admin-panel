--[[
    OWNER PANEL — gated admin-style UI (test build)
    ------------------------------------------------
    • Loads ONLY when LocalPlayer.Name == OWNER_NAME
    • Parented to CoreGui, with automatic PlayerGui fallback
    • RightControl toggles the panel
    • Fully cleans itself up (no dangling connections)

    RUN IT: Studio → Play Mode → Command Bar → paste → Enter
]]

--=====================================================================--
-- CONFIG
--=====================================================================--
local OWNER_NAME  = "YourUsernameHere"          -- <<< PUT YOUR USERNAME HERE
local TOGGLE_KEY  = Enum.KeyCode.RightControl
local WINDOW_SIZE = Vector2.new(660, 420)

local THEME = {
    Background = Color3.fromRGB(23, 25, 31),
    Sidebar    = Color3.fromRGB(17, 19, 24),
    Card       = Color3.fromRGB(33, 36, 44),
    Accent     = Color3.fromRGB(88, 101, 242),
    Danger     = Color3.fromRGB(235, 69, 69),
    Text       = Color3.fromRGB(235, 235, 245),
    SubText    = Color3.fromRGB(140, 143, 158),
    Stroke     = Color3.fromRGB(55, 58, 70),
}

--=====================================================================--
-- SERVICES + ACCESS GATE
--=====================================================================--
local Players    = game:GetService("Players")
local UserInput  = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Stats      = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    warn("[OwnerPanel] LocalPlayer is nil — run this in Play Mode, not edit mode.")
    return
end

if LocalPlayer.Name ~= OWNER_NAME then
    warn(`[OwnerPanel] Access denied. You are "{LocalPlayer.Name}", owner is "{OWNER_NAME}".`)
    return
end

--=====================================================================--
-- HELPERS
--=====================================================================--
local connections = {}

local function connect(signal, fn)
    table.insert(connections, signal:Connect(fn))
end

local function make(className, props)
    local inst = Instance.new(className)
    for key, value in props do
        inst[key] = value
    end
    return inst
end

local function round(parent, radius)
    make("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local function stroke(parent, color)
    make("UIStroke", { Color = color, Thickness = 1, Parent = parent })
end

--=====================================================================--
-- ROOT — CoreGui with graceful fallback
--=====================================================================--
local gui = make("ScreenGui", {
    Name = "OwnerPanel",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local coreGuiOk = pcall(function()
    gui.Parent = game:GetService("CoreGui")
end)
if not coreGuiOk then
    -- CoreGui is protected outside Studio; fall back so the panel still works.
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

--=====================================================================--
-- MAIN WINDOW
--=====================================================================--
local main = make("Frame", {
    Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
    Position = UDim2.fromScale(0.5, 0.5),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = THEME.Background,
    ClipsDescendants = true,
    Parent = gui,
})
round(main, 10)
stroke(main, THEME.Stroke)

local titleBar = make("Frame", {
    Size = UDim2.new(1, 0, 0, 40),
    BackgroundColor3 = THEME.Sidebar,
    Parent = main,
})
round(titleBar, 10)

make("TextLabel", {
    Size = UDim2.new(1, -120, 1, 0),
    Position = UDim2.fromOffset(14, 0),
    BackgroundTransparency = 1,
    Text = `OWNER PANEL  •  {LocalPlayer.Name}`,
    TextColor3 = THEME.Text,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = titleBar,
})

local function titleButton(text, color, xOffset)
    local btn = make("TextButton", {
        Size = UDim2.fromOffset(26, 26),
        Position = UDim2.new(1, xOffset, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = color,
        Text = text,
        TextColor3 = THEME.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        AutoButtonColor = false,
        Parent = titleBar,
    })
    round(btn, 6)
    return btn
end

local closeBtn = titleButton("X", THEME.Danger, -36)
local minBtn   = titleButton("–", THEME.Card,   -70)

--=====================================================================--
-- DRAGGING (title bar = drag handle)
--=====================================================================--
local dragging, dragStart, startPos = false, nil, nil

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
    end
end)

connect(UserInput.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

connect(UserInput.InputChanged, function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

--=====================================================================--
-- SIDEBAR + TAB SYSTEM
--=====================================================================--
local sidebar = make("Frame", {
    Size = UDim2.new(0, 150, 1, -52),
    Position = UDim2.fromOffset(0, 40),
    BackgroundColor3 = THEME.Sidebar,
    Parent = main,
})
make("UIListLayout", {
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    Parent = sidebar,
})
make("UIPadding", { PaddingTop = UDim.new(0, 12), Parent = sidebar })

local content = make("Frame", {
    Size = UDim2.new(1, -150, 1, -40),
    Position = UDim2.fromOffset(150, 40),
    BackgroundTransparency = 1,
    Parent = main,
})

local pages, tabButtons = {}, {}

local function selectTab(name)
    for tabName, page in pages do
        page.Visible = (tabName == name)
    end
    for tabName, btn in tabButtons do
        btn.BackgroundColor3 = (tabName == name) and THEME.Accent or THEME.Card
    end
end

local function createTab(name, order)
    local btn = make("TextButton", {
        Size = UDim2.new(1, -16, 0, 34),
        BackgroundColor3 = THEME.Card,
        LayoutOrder = order,
        Text = name,
        TextColor3 = THEME.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        Parent = sidebar,
    })
    round(btn, 8)
    tabButtons[name] = btn
    btn.MouseButton1Click:Connect(function() selectTab(name) end)
end

local function createPage(name)
    local page = make("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = content,
    })
    make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })
    make("UIPadding", {
        PaddingTop = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
        Parent = page,
    })
    pages[name] = page
    return page
end

local function pageHeader(page, text, order)
    make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        LayoutOrder = order,
        Text = text,
        TextColor3 = THEME.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = page,
    })
end

--=====================================================================--
-- PAGE 1: PLAYERS
--=====================================================================--
createTab("Players", 1)
createTab("Performance", 2)
createTab("Settings", 3)

local playersPage = createPage("Players")
pageHeader(playersPage, "Players in server", 1)

local playerList = make("ScrollingFrame", {
    Size = UDim2.new(1, 0, 1, -46),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    LayoutOrder = 2,
    Parent = playersPage,
})
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = playerList })

local function teleportTo(target)
    local myChar = LocalPlayer.Character
    local targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if myChar and targetRoot then
        myChar:PivotTo(targetRoot.CFrame * CFrame.new(0, 0, -4)) -- 4 studs in front, facing them
    end
end

local function makePlayerRow(player, order)
    local row = make("Frame", {
        Size = UDim2.new(1, -6, 0, 42),
        BackgroundColor3 = THEME.Card,
        LayoutOrder = order,
        Parent = playerList,
    })
    round(row, 8)

    make("TextLabel", {
        Size = UDim2.new(1, -110, 1, 0),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Text = (player == LocalPlayer)
            and `{player.DisplayName} (you)`
            or  `{player.DisplayName} (@{player.Name})`,
        TextColor3 = THEME.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    })

    if player ~= LocalPlayer then
        local tpBtn = make("TextButton", {
            Size = UDim2.fromOffset(56, 26),
            Position = UDim2.new(1, -66, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = THEME.Accent,
            Text = "TP",
            TextColor3 = THEME.Text,
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            Parent = row,
        })
        round(tpBtn, 6)
        tpBtn.MouseButton1Click:Connect(function() teleportTo(player) end)
    end
end

local function refreshPlayers()
    for _, child in playerList:GetChildren() do
        if not child:IsA("UIListLayout") then child:Destroy() end
    end
    for i, player in Players:GetPlayers() do
        makePlayerRow(player, i)
    end
end

connect(Players.PlayerAdded, refreshPlayers)
connect(Players.PlayerRemoving, refreshPlayers)

--=====================================================================--
-- PAGE 2: PERFORMANCE
--=====================================================================--
local perfPage = createPage("Performance")
pageHeader(perfPage, "Client stats", 1)

local function statCard(labelText, order)
    local card = make("Frame", {
        Size = UDim2.new(1, 0, 0, 62),
        BackgroundColor3 = THEME.Card,
        LayoutOrder = order,
        Parent = perfPage,
    })
    round(card, 8)
    make("TextLabel", {
        Size = UDim2.new(1, -20, 0, 16),
        Position = UDim2.fromOffset(10, 8),
        BackgroundTransparency = 1,
        Text = labelText:upper(),
        TextColor3 = THEME.SubText,
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card,
    })
    return make("TextLabel", {
        Size = UDim2.new(1, -20, 0, 24),
        Position = UDim2.fromOffset(10, 28),
        BackgroundTransparency = 1,
        Text = "—",
        TextColor3 = THEME.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 20,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card,
    })
end

local fpsValue         = statCard("Framerate", 2)
local playerCountValue = statCard("Players", 3)
local memoryValue      = statCard("Memory used", 4)

local frames, elapsed = 0, 0
connect(RunService.RenderStepped, function(dt)
    frames += 1
    elapsed += dt
    if elapsed >= 0.5 then
        fpsValue.Text = (`%d fps`):format(frames / elapsed)
        playerCountValue.Text = (`%d / %d`):format(#Players:GetPlayers(), Players.MaxPlayers)
        local okMem, mem = pcall(function() return Stats:GetTotalMemoryUsedMb() end)
        memoryValue.Text = okMem and (`%.0f MB`):format(mem) or "unavailable"
        frames, elapsed = 0, 0
    end
end)

--=====================================================================--
-- PAGE 3: SETTINGS (self-targeted test utilities)
--=====================================================================--
local settingsPage = createPage("Settings")
pageHeader(settingsPage, "Movement (self)", 1)

local currentWalkSpeed, currentJumpPower = 16, 50

local function applyMovement()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.UseJumpPower = true
        hum.WalkSpeed = currentWalkSpeed
        hum.JumpPower = currentJumpPower
    end
end

local function createSlider(labelText, min, max, default, callback)
    local holder = make("Frame", {
        Size = UDim2.new(1, 0, 0, 58),
        BackgroundTransparency = 1,
        Parent = settingsPage,
    })

    make("TextLabel", {
        Size = UDim2.new(1, -70, 0, 20),
        BackgroundTransparency = 1,
        Text = labelText,
        TextColor3 = THEME.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = holder,
    })

    local valueLabel = make("TextLabel", {
        Size = UDim2.new(0, 70, 0, 20),
        Position = UDim2.new(1, -70, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(default),
        TextColor3 = THEME.SubText,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = holder,
    })

    local track = make("Frame", {
        Size = UDim2.new(1, 0, 0, 6),
        Position = UDim2.fromOffset(0, 34),
        BackgroundColor3 = THEME.Card,
        Parent = holder,
    })
    round(track, 3)

    local fill = make("Frame", {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = THEME.Accent,
        Parent = track,
    })
    round(fill, 3)

    local knob = make("Frame", {
        Size = UDim2.fromOffset(14, 14),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        BackgroundColor3 = THEME.Text,
        Parent = track,
    })
    round(knob, 7)

    local function setValue(value, fire)
        local alpha = math.clamp((value - min) / (max - min), 0, 1)
        fill.Size = UDim2.fromScale(alpha, 1)
        knob.Position = UDim2.fromScale(alpha, 0.5)
        valueLabel.Text = tostring(math.floor(value * 10 + 0.5) / 10)
        if fire then callback(value) end
    end

    local sliding = false
    local function alphaFromX(x)
        return math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            setValue(min + (max - min) * alphaFromX(input.Position.X), true)
        end
    end)

    connect(UserInput.InputChanged, function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            setValue(min + (max - min) * alphaFromX(input.Position.X), true)
        end
    end)

    connect(UserInput.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end)

    setValue(default, false)
end

createSlider("WalkSpeed", 0, 200, 16, function(v)
    currentWalkSpeed = v
    applyMovement()
end)

createSlider("JumpPower", 0, 300, 50, function(v)
    currentJumpPower = v
    applyMovement()
end)

-- Reapply movement settings after respawn
connect(LocalPlayer.CharacterAdded, function()
    task.wait(0.2) -- let the Humanoid initialize
    applyMovement()
end)

make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 40),
    BackgroundTransparency = 1,
    LayoutOrder = 4,
    Text = "Self-targeted test utilities. Values reapply on respawn.\nToggle panel: RightControl  •  Drag by the title bar.",
    TextColor3 = THEME.SubText,
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    Parent = settingsPage,
})

--=====================================================================--
-- WINDOW CONTROLS + CLEANUP
--=====================================================================--
local function unload()
    for _, conn in connections do
        conn:Disconnect()
    end
    table.clear(connections)
    gui:Destroy()
end

local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    sidebar.Visible = not minimized
    content.Visible = not minimized
    main.Size = minimized
        and UDim2.fromOffset(WINDOW_SIZE.X, 40)
        or  UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y)
end)

closeBtn.MouseButton1Click:Connect(unload)

connect(UserInput.InputBegan, function(input, processed)
    if processed then return end
    if input.KeyCode == TOGGLE_KEY then
        main.Visible = not main.Visible
    end
end)

--=====================================================================--
-- INIT
--=====================================================================--
refreshPlayers()
selectTab("Players")
print(`[OwnerPanel] Loaded for owner "{OWNER_NAME}". Press {TOGGLE_KEY.Name} to toggle.`)
